import Foundation
import XCTest
@testable import Claw

@MainActor
final class ClawArtifactPreviewTests: XCTestCase {
    func testPreviewSupportsOnlyFourTextKinds() {
        let supported: Set<ClawGatewayArtifactKind> = [.fileDiff, .commandOutput, .browserTrace, .messageDraft]
        for kind in ClawGatewayArtifactKind.allCases {
            XCTAssertEqual(ClawArtifactPreviewSelection.supports(kind), supported.contains(kind))
        }
    }

    func testResponseRequiresExactIdentityShapeMediaTypeCountsAndFalseEffects() throws {
        let request = ClawArtifactPreviewRequest(taskID: UUID(), artifactID: UUID())
        let data = try PreviewTestFixture.data(request)
        XCTAssertEqual(try ClawArtifactPreviewContent.decode(data, request: request, kind: .commandOutput).text, PreviewTestFixture.text)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for (key, value) in [("taskID", UUID().uuidString as Any), ("artifactID", UUID().uuidString),
                             ("requestNonce", "different_nonce"), ("artifactKind", "auditLog"), ("mediaType", "text/html"),
                             ("byteCount", true), ("byteCount", -1), ("byteCount", 1.5), ("extra", "private_marker"),
                             ("effects", ["computerActions": true, "taskDispatched": false]),
                             ("effects", ["computerActions": 0, "taskDispatched": 0])] {
            var changed = root
            changed[key] = value
            XCTAssertThrowsError(try ClawArtifactPreviewContent.decode(JSONSerialization.data(withJSONObject: changed), request: request, kind: .commandOutput))
        }
        let duplicate = String(String(decoding: data, as: UTF8.self).dropLast()) + ",\"c\\u006fntent\":\"foreign\"}"
        XCTAssertThrowsError(try ClawArtifactPreviewContent.decode(Data(duplicate.utf8), request: request, kind: .commandOutput))
        for nonce in ["short", String(repeating: "x", count: 129), "invalid nonce", "abcdefgh\n", "中文nonce"] {
            XCTAssertThrowsError(try ClawArtifactPreviewRequest(taskID: UUID(), artifactID: UUID(), nonce: nonce).encodedData())
        }
    }

    func testPreviewByteLimitsUseUTF8AndNeverTruncateOrAcceptNUL() throws {
        let request = ClawArtifactPreviewRequest(taskID: UUID(), artifactID: UUID())
        let valid = String(repeating: "x", count: 32_768)
        XCTAssertEqual(try ClawArtifactPreviewContent.decode(PreviewTestFixture.data(request, text: valid), request: request, kind: .commandOutput).byteCount, 32_768)
        for text in [valid + "x", String(repeating: "中", count: 10_923), "bad\0text"] {
            XCTAssertThrowsError(try ClawArtifactPreviewContent.decode(PreviewTestFixture.data(request, text: text), request: request, kind: .commandOutput))
        }
        XCTAssertThrowsError(try ClawArtifactPreviewContent.decode(Data(repeating: 32, count: 262_145), request: request, kind: .commandOutput))
    }

    func testWireUsesHeaderOnlyCredentialsFixedRouteAndSecureOrigin() throws {
        let store = ClawStore(autoScanLocalArtifacts: false)
        store.setGateway(url: "wss://gateway.example.test/socket", token: "preview-test-token")
        let request = ClawArtifactPreviewRequest(taskID: UUID(), artifactID: UUID())
        let wire = try ClawArtifactPreviewWireRequest.make(request, profile: store.clawGatewayProfile, token: store.gatewayToken)
        XCTAssertEqual(wire.url.absoluteString, "https://gateway.example.test/claw/artifacts/preview")
        XCTAssertEqual(wire.headers["Authorization"], "Bearer preview-test-token")
        let body = try ClawPlanningJSON.object(wire.body, maxBytes: 1024)
        XCTAssertEqual(Set(body.keys), ["controlPlane", "kind", "requestNonce", "taskID", "artifactID"])
        XCTAssertFalse(String(decoding: wire.body, as: UTF8.self).contains("preview-test-token"))
        for origin in ["ws://remote.example.test", "wss://user:secret@gateway.example.test", "wss://gateway.example.test?key=secret"] {
            var profile = store.clawGatewayProfile
            profile.endpoint = origin
            XCTAssertThrowsError(try ClawArtifactPreviewWireRequest.make(request, profile: profile, token: store.gatewayToken))
        }
    }

    func testUnavailableSimulatedAndForgedSelectionsNeverCallTransport() async throws {
        let store = ClawStore(autoScanLocalArtifacts: false)
        let selection = PreviewTestFixture.selection()
        let transport = PreviewTestTransport()
        await store.requestArtifactPreview(selection, transport: transport)
        let calls = await transport.count
        XCTAssertEqual(calls, 0)
        XCTAssertTrue(store.availableArtifactPreviews.isEmpty)
        store.phoneAgentCommand = "打开浏览器搜索资料"
        store.generatePhoneAgentPlan()
        store.queueClawMobileTaskFromCurrentPlan()
        store.approveLatestClawMobileTask()
        store.sendLatestClawMobileTask()
        XCTAssertTrue(store.availableArtifactPreviews.isEmpty)
        await store.requestArtifactPreview(selection, transport: transport)
        let after = await transport.count
        XCTAssertEqual(after, 0)
    }

    func testSuccessfulLivePreviewDoesNotMutateExecutionOrCheckpoint() async throws {
        let checkpoint = ClawInMemoryMissionRunCheckpointStore()
        let store = try await liveStore(checkpoint: checkpoint)
        let selection = try XCTUnwrap(store.availableArtifactPreviews.first)
        let before = try snapshot(store)
        let saves = checkpoint.saveCount
        await store.requestArtifactPreview(selection, transport: PreviewTestTransport())
        guard case .ready(let current, let content) = store.artifactPreviewState(for: selection) else { return XCTFail("Expected current live preview") }
        XCTAssertEqual(current, selection)
        XCTAssertEqual(content.text, PreviewTestFixture.text)
        XCTAssertEqual(try snapshot(store), before)
        XCTAssertEqual(checkpoint.saveCount, saves)
        store.clearArtifactPreview(matching: selection)
        XCTAssertEqual(store.artifactPreviewState, .idle)
        XCTAssertEqual(try snapshot(store), before)
    }

    func testDuplicateReadIsSingleRequestAndClosingDropsLateResponse() async throws {
        let store = try await liveStore()
        let selection = try XCTUnwrap(store.availableArtifactPreviews.first)
        let transport = PreviewTestTransport(held: true)
        let first = Task { await store.requestArtifactPreview(selection, transport: transport) }
        let started = await waitForCall(transport)
        XCTAssertTrue(started)
        await store.requestArtifactPreview(selection, transport: transport)
        let count = await transport.count
        XCTAssertEqual(count, 1)
        store.clearArtifactPreview(matching: selection)
        await transport.release()
        await first.value
        XCTAssertEqual(store.artifactPreviewState, .idle)
    }

    func testProfileEditsAndReturningToSameValueClearContentAndAuthorization() async throws {
        let store = try await liveStore()
        let selection = try XCTUnwrap(store.availableArtifactPreviews.first)
        await store.requestArtifactPreview(selection, transport: PreviewTestTransport())
        let old = store.gatewayToken
        store.gatewayToken = "changed-token"
        XCTAssertEqual(store.artifactPreviewState, .idle)
        XCTAssertTrue(store.availableArtifactPreviews.isEmpty)
        store.gatewayToken = old
        XCTAssertTrue(store.availableArtifactPreviews.isEmpty)
        let transport = PreviewTestTransport()
        await store.requestArtifactPreview(selection, transport: transport)
        let calls = await transport.count
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(store.artifactPreviewState(for: selection), .failed(selection, .stale))
    }

    func testNewMissionAndModeChangeCannotKeepOrReceiveOldPreview() async throws {
        for replaceMission in [true, false] {
            let store = try await liveStore()
            let selection = try XCTUnwrap(store.availableArtifactPreviews.first)
            let transport = PreviewTestTransport(held: true)
            let pending = Task { await store.requestArtifactPreview(selection, transport: transport) }
            let started = await waitForCall(transport)
            XCTAssertTrue(started)
            if replaceMission {
                store.phoneAgentCommand = "打开浏览器搜索新资料"
                store.generatePhoneAgentPlan()
                store.queueClawMobileTaskFromCurrentPlan()
            } else {
                store.gatewayDispatchMode = .simulatedEventStream
            }
            await transport.release()
            await pending.value
            XCTAssertEqual(store.artifactPreviewState, .idle)
            XCTAssertTrue(store.availableArtifactPreviews.isEmpty)
        }
    }

    func testFailureIsFixedNoFallbackAndCallerCancellationClearsContent() async throws {
        let store = try await liveStore()
        let selection = try XCTUnwrap(store.availableArtifactPreviews.first)
        let before = try snapshot(store)
        await store.requestArtifactPreview(selection, transport: PreviewTestTransport(fails: true))
        XCTAssertEqual(store.artifactPreviewState, .failed(selection, .transport))
        XCTAssertEqual(try snapshot(store), before)
        let transport = PreviewTestTransport(held: true)
        let pending = Task { await store.requestArtifactPreview(selection, transport: transport) }
        let started = await waitForCall(transport)
        XCTAssertTrue(started)
        pending.cancel()
        await transport.release()
        await pending.value
        XCTAssertEqual(store.artifactPreviewState, .failed(selection, .cancelled))
        XCTAssertEqual(try snapshot(store), before)
    }

    func testReadLiveEvidencePlanningOnlyUpdatesPlanAndRetainsParameterApprovalGate() async throws {
        let checkpoint = ClawInMemoryMissionRunCheckpointStore()
        let store = try await liveStore(checkpoint: checkpoint)
        let selection = try XCTUnwrap(store.availableArtifactPreviews.first)
        await store.requestArtifactPreview(selection, transport: PreviewTestTransport())
        let before = try snapshot(store)
        let saves = checkpoint.saveCount
        let planner = PreviewEvidencePlanningTransport()
        await store.requestModelPlan(evidenceSelection: selection, transport: planner)
        XCTAssertEqual(store.modelPlanningPhase, .ready)
        XCTAssertFalse(store.isPlanning(using: selection))
        XCTAssertEqual(store.phoneAgentPlan.source, .configuredModel)
        XCTAssertEqual(try snapshot(store), before)
        XCTAssertEqual(checkpoint.saveCount, saves)
        let requests = await planner.requests
        XCTAssertEqual(requests.count, 1)
        let body = try ClawPlanningJSON.object(try XCTUnwrap(requests.first), maxBytes: 32768)
        let reference = try XCTUnwrap(body["evidence"] as? [String: String])
        XCTAssertEqual(reference["taskID"].flatMap(UUID.init(uuidString:)), selection.taskID)
        XCTAssertEqual(reference["artifactID"].flatMap(UUID.init(uuidString:)), selection.artifact.id)
        XCTAssertEqual(reference["contentSHA256"]?.count, 64)
        XCTAssertFalse(String(decoding: try XCTUnwrap(requests.first), as: UTF8.self).contains(PreviewTestFixture.text))
        store.clearArtifactPreview(matching: selection)
        XCTAssertEqual(store.modelPlanningPhase, .ready, "closing a completed preview must not discard an accepted plan")
        let sessionCount = store.clawGatewaySessions.count
        let eventCount = store.gatewayEvents.count
        store.queueClawMobileTaskFromCurrentPlan()
        let task = try XCTUnwrap(store.clawMobileTasks.first)
        XCTAssertEqual(task.actions.map(\.kind), [.manageFiles, .runAgentLoop])
        XCTAssertEqual(task.status, .waitingForApproval)
        XCTAssertEqual(store.pendingModelParameterReviewCount(for: task), 1)
        store.approveLatestClawMobileTask()
        XCTAssertEqual(store.clawMobileTasks.first?.status, .waitingForApproval)
        let dispatch = PreviewEvidenceDispatchRecorder()
        await store.sendLatestClawMobileTaskOverLiveGateway(transport: dispatch)
        XCTAssertEqual(dispatch.count, 0, "model evidence cannot bypass explicit parameter review")
        XCTAssertEqual(store.clawGatewaySessions.count, sessionCount)
        XCTAssertEqual(store.gatewayEvents.count, eventCount)
    }

    func testUnreadForgedStaleDirtyAndSimulatedEvidenceNeverContactsModel() async throws {
        for mutation in ["unread", "foreign-task", "foreign-session", "foreign-artifact", "foreign-binding", "dirty", "simulated", "new-task"] {
            let store = try await liveStore()
            let current = try XCTUnwrap(store.availableArtifactPreviews.first)
            if mutation != "unread" { await store.requestArtifactPreview(current, transport: PreviewTestTransport()) }
            var selected = current
            switch mutation {
            case "foreign-task":
                selected = .init(taskID: UUID(), sessionID: current.sessionID, artifact: current.artifact, binding: current.binding)
            case "foreign-session":
                selected = .init(taskID: current.taskID, sessionID: UUID(), artifact: current.artifact, binding: current.binding)
            case "foreign-artifact":
                let artifact = ClawGatewayArtifact(kind: current.artifact.kind, title: current.artifact.title,
                    reference: current.artifact.reference, isRedacted: current.artifact.isRedacted, metadata: current.artifact.metadata)
                selected = .init(taskID: current.taskID, sessionID: current.sessionID, artifact: artifact, binding: current.binding)
            case "foreign-binding":
                selected = .init(taskID: current.taskID, sessionID: current.sessionID, artifact: current.artifact, binding: "foreign-profile")
            case "dirty": store.gatewayToken = "unapplied-new-token"
            case "simulated": store.gatewayDispatchMode = .simulatedEventStream
            case "new-task":
                store.phoneAgentCommand = "搜索另一份资料"
                store.generatePhoneAgentPlan()
                store.queueClawMobileTaskFromCurrentPlan()
            default: break
            }
            let before = try snapshot(store)
            let planner = PreviewEvidencePlanningTransport()
            await store.requestModelPlan(evidenceSelection: selected, transport: planner)
            let requests = await planner.requests
            XCTAssertTrue(requests.isEmpty, mutation)
            XCTAssertNotEqual(store.modelPlanningPhase, .ready, mutation)
            XCTAssertEqual(try snapshot(store), before, mutation)
        }
        let store = ClawStore(autoScanLocalArtifacts: false)
        store.setGateway(url: "ws://127.0.0.1:18789", token: "preview-test-token")
        let planner = PreviewEvidencePlanningTransport()
        await store.requestModelPlan(evidenceSelection: PreviewTestFixture.selection(), transport: planner)
        let requests = await planner.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testDuplicateArtifactIdentityCannotBeChosenForEvidencePlanning() async throws {
        let store = ClawStore(autoScanLocalArtifacts: false)
        store.setGateway(url: "ws://127.0.0.1:18789", token: "preview-test-token")
        store.gatewayDispatchMode = .liveGateway
        store.phoneAgentCommand = "打开浏览器搜索资料"
        store.generatePhoneAgentPlan()
        store.queueClawMobileTaskFromCurrentPlan()
        store.approveLatestClawMobileTask()
        let artifact = PreviewTestFixture.selection().artifact
        await store.sendLatestClawMobileTaskOverLiveGateway(transport: PreviewDuplicateLiveFixture(artifact: artifact))
        let session = try XCTUnwrap(store.clawGatewaySessions.first)
        XCTAssertEqual(session.allArtifacts.filter { $0.id == artifact.id }.count, 2)
        XCTAssertTrue(store.availableArtifactPreviews.isEmpty)
        let selected = ClawArtifactPreviewSelection(taskID: session.taskID, sessionID: session.id, artifact: artifact, binding: "untrusted")
        let before = try snapshot(store)
        let planner = PreviewEvidencePlanningTransport()
        await store.requestModelPlan(evidenceSelection: selected, transport: planner)
        let requests = await planner.requests
        XCTAssertTrue(requests.isEmpty)
        XCTAssertEqual(try snapshot(store), before)
    }

    func testPreviewLargerThanEvidenceBudgetStaysReadableButNeverReachesModel() async throws {
        let store = try await liveStore()
        let selection = try XCTUnwrap(store.availableArtifactPreviews.first)
        let text = String(repeating: "中", count: 2731)
        await store.requestArtifactPreview(selection, transport: PreviewTestTransport(text: text))
        guard case .ready(_, let content) = store.artifactPreviewState(for: selection) else {
            return XCTFail("The complete 8193-byte result should remain readable")
        }
        XCTAssertEqual(content.text, text)
        XCTAssertEqual(content.byteCount, 8193)
        let before = try snapshot(store)
        let planner = PreviewEvidencePlanningTransport()
        await store.requestModelPlan(evidenceSelection: selection, transport: planner)
        let requests = await planner.requests
        XCTAssertTrue(requests.isEmpty)
        XCTAssertEqual(store.modelPlanningPhase, .failed(.evidenceUnavailable))
        XCTAssertEqual(try snapshot(store), before)
        XCTAssertEqual(store.artifactPreviewState(for: selection), .ready(selection, content), "over-budget evidence must not be truncated or erase the readable result")
    }

    func testClosingEvidencePlanningDropsLateResponseWithoutOverwritingReplacement() async throws {
        let store = try await liveStore()
        let selection = try XCTUnwrap(store.availableArtifactPreviews.first)
        await store.requestArtifactPreview(selection, transport: PreviewTestTransport())
        let held = PreviewEvidencePlanningTransport(held: true)
        let operation = Task { await store.requestModelPlan(evidenceSelection: selection, transport: held) }
        let started = await waitForModelCall(held)
        XCTAssertTrue(started)
        XCTAssertTrue(store.isPlanning(using: selection))
        await store.requestModelPlan(evidenceSelection: selection, transport: held)
        let firstRequests = await held.requests
        XCTAssertEqual(firstRequests.count, 1, "duplicate model requests cannot multiply the disclosure")
        store.clearArtifactPreview(matching: selection)
        XCTAssertEqual(store.modelPlanningPhase, .cancelled)
        XCTAssertFalse(store.isPlanning(using: selection))
        let replacementID = await store.requestModelPlan(transport: PreviewEvidencePlanningTransport())
        let replacementPlan = store.phoneAgentPlan
        XCTAssertEqual(replacementID, replacementPlan.id)
        let replacementState = try snapshot(store)
        XCTAssertEqual(store.modelPlanningPhase, .ready)
        await held.release()
        let discardedID = await operation.value
        XCTAssertNil(discardedID, "the cancelled operation must not claim a replacement request's plan")
        XCTAssertFalse(store.isPlanning(using: selection))
        XCTAssertEqual(store.modelPlanningPhase, .ready)
        XCTAssertEqual(store.phoneAgentPlan, replacementPlan)
        XCTAssertEqual(try snapshot(store), replacementState)
    }

    func testEvidencePlanningScopeChangesCannotAcceptOldResult() async throws {
        for mutation in ["command", "profile", "mode", "new-task", "reread"] {
            let store = try await liveStore()
            let selection = try XCTUnwrap(store.availableArtifactPreviews.first)
            await store.requestArtifactPreview(selection, transport: PreviewTestTransport())
            let held = PreviewEvidencePlanningTransport(held: true)
            let operation = Task { await store.requestModelPlan(evidenceSelection: selection, transport: held) }
            let started = await waitForModelCall(held)
            XCTAssertTrue(started)
            XCTAssertTrue(store.isPlanning(using: selection), mutation)
            switch mutation {
            case "command":
                let original = store.phoneAgentCommand
                store.phoneAgentCommand = "different command"
                store.phoneAgentCommand = original
            case "profile":
                let original = store.gatewayToken
                store.gatewayToken = "different-token"
                store.gatewayToken = original
            case "mode": store.gatewayDispatchMode = .simulatedEventStream
            case "new-task":
                store.generatePhoneAgentPlan()
                store.queueClawMobileTaskFromCurrentPlan()
            case "reread": await store.requestArtifactPreview(selection, transport: PreviewTestTransport())
            default: XCTFail("Unknown fixture mutation")
            }
            XCTAssertFalse(store.isPlanning(using: selection), mutation)
            let currentPlan = store.phoneAgentPlan
            let current = try snapshot(store)
            await held.release()
            let discardedID = await operation.value
            XCTAssertNil(discardedID, mutation)
            XCTAssertEqual(store.phoneAgentPlan, currentPlan, mutation)
            XCTAssertEqual(try snapshot(store), current, mutation)
            XCTAssertNotEqual(store.modelPlanningPhase, .ready, mutation)
        }
    }

    func testPlainPlanningCannotBeClaimedOrCancelledByOpenEvidencePreview() async throws {
        let store = try await liveStore()
        let selection = try XCTUnwrap(store.availableArtifactPreviews.first)
        await store.requestArtifactPreview(selection, transport: PreviewTestTransport())
        XCTAssertTrue(store.canPlan(using: selection))
        let held = PreviewEvidencePlanningTransport(held: true)
        let operation = Task { await store.requestModelPlan(transport: held) }
        let started = await waitForModelCall(held)
        XCTAssertTrue(started)
        XCTAssertEqual(store.modelPlanningPhase, .requesting)
        XCTAssertTrue(store.canPlan(using: selection), "a readable result is not proof it belongs to the active request")
        XCTAssertFalse(store.isPlanning(using: selection))
        store.clearArtifactPreview(matching: selection)
        XCTAssertEqual(store.modelPlanningPhase, .requesting, "closing this preview cannot cancel an unrelated plain planning request")
        XCTAssertFalse(store.isPlanning(using: selection))
        await held.release()
        let planID = await operation.value
        XCTAssertEqual(planID, store.phoneAgentPlan.id)
        XCTAssertEqual(store.modelPlanningPhase, .ready)
        XCTAssertFalse(store.isPlanning(using: selection))
    }

    private func waitForModelCall(_ transport: PreviewEvidencePlanningTransport) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while ContinuousClock.now < deadline {
            if !(await transport.requests).isEmpty { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }

    private func liveStore(checkpoint: ClawInMemoryMissionRunCheckpointStore = .init()) async throws -> ClawStore {
        let store = ClawStore(autoScanLocalArtifacts: false, checkpointStore: checkpoint)
        store.setGateway(url: "ws://127.0.0.1:18789", token: "preview-test-token")
        store.gatewayDispatchMode = .liveGateway
        store.phoneAgentCommand = "打开浏览器搜索资料"
        store.generatePhoneAgentPlan()
        store.queueClawMobileTaskFromCurrentPlan()
        store.approveLatestClawMobileTask()
        await store.sendLatestClawMobileTaskOverLiveGateway(transport: PreviewLiveFixture())
        XCTAssertEqual(store.availableArtifactPreviews.count, 1)
        return store
    }

    private func snapshot(_ store: ClawStore) throws -> [Data] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try [encoder.encode(store.clawMobileTasks), encoder.encode(store.clawGatewaySessions), encoder.encode(store.gatewayEvents),
                    encoder.encode(store.autonomousLoop), encoder.encode(store.lastClawMobileEnvelope), encoder.encode(store.lastGatewayLiveRequest),
                    encoder.encode(store.gatewayConnectionState), encoder.encode(store.continuationDraft)]
    }

    private func waitForCall(_ transport: PreviewTestTransport) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while ContinuousClock.now < deadline {
            if await transport.count > 0 { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }

}

private enum PreviewTestFixture {
    static let text = "Untrusted result <script>do not execute</script> [link](file:///private/secret) 中文\n"
    static func selection() -> ClawArtifactPreviewSelection {
        .init(taskID: UUID(), sessionID: UUID(), artifact: .init(kind: .commandOutput, title: "Result", reference: "file:///not-opened", isRedacted: false), binding: "fixture")
    }
    static func data(_ request: ClawArtifactPreviewRequest, text: String = PreviewTestFixture.text) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["controlPlane": ClawArtifactPreviewRequest.controlPlane, "kind": "previewResponse",
            "requestNonce": request.nonce, "taskID": request.taskID.uuidString, "artifactID": request.artifactID.uuidString,
            "artifactKind": "commandOutput", "mediaType": "text/plain; charset=utf-8", "content": text, "byteCount": text.utf8.count,
            "effects": ["computerActions": false, "taskDispatched": false]])
    }
}

private struct PreviewLiveFixture: ClawGatewayTransport {
    func streamEvents(request: ClawGatewayLiveRequest, envelopeJSON: String, sessionID: UUID, taskID: UUID) -> AsyncThrowingStream<ClawGatewayWireEvent, Error> {
        AsyncThrowingStream { stream in
            for (index, kind) in [ClawGatewayEventKind.gatewayConnected, .artifactStored, .sessionCompleted].enumerated() {
                stream.yield(ClawGatewayWireEvent(event: .init(sessionID: sessionID, taskID: taskID, sequence: index + 10, kind: kind,
                    summary: "Cloud live preview fixture", artifacts: kind == .artifactStored ? [PreviewTestFixture.selection().artifact] : [])))
            }
            stream.finish()
        }
    }
}

private actor PreviewTestTransport: ClawArtifactPreviewTransport {
    private(set) var count = 0
    let held: Bool
    let fails: Bool
    let text: String
    var continuation: CheckedContinuation<Data, Error>?
    var payload: Data?
    init(held: Bool = false, fails: Bool = false, text: String = PreviewTestFixture.text) {
        self.held = held; self.fails = fails; self.text = text
    }
    func response(for wire: ClawArtifactPreviewWireRequest) async throws -> Data {
        count += 1
        if fails { throw URLError(.cannotConnectToHost, userInfo: [NSLocalizedDescriptionKey: "private_marker"]) }
        let body = try ClawPlanningJSON.object(wire.body, maxBytes: 1024)
        guard let task = (body["taskID"] as? String).flatMap(UUID.init(uuidString:)),
              let artifact = (body["artifactID"] as? String).flatMap(UUID.init(uuidString:)),
              let nonce = body["requestNonce"] as? String else { throw ClawArtifactPreviewError.invalidResponse }
        let data = try PreviewTestFixture.data(.init(taskID: task, artifactID: artifact, nonce: nonce), text: text)
        if !held { return data }
        payload = data
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            Task { try? await Task.sleep(for: .seconds(4)); self.expire() }
        }
    }
    func release() {
        guard let current = continuation, let payload else { return }
        continuation = nil
        current.resume(returning: payload)
    }
    private func expire() {
        let current = continuation
        continuation = nil
        current?.resume(throwing: ClawArtifactPreviewError.timeout)
    }
}

private actor PreviewEvidencePlanningTransport: ClawModelPlanningTransport {
    private(set) var requests: [Data] = []
    let held: Bool
    private var continuation: CheckedContinuation<Data, Error>?
    private var payload: Data?

    init(held: Bool = false) { self.held = held }

    func response(for request: ClawModelPlanningWireRequest) async throws -> Data {
        requests.append(request.body)
        let body = try ClawPlanningJSON.object(request.body, maxBytes: 32768)
        guard let nonce = body["requestNonce"] as? String else { throw ClawModelPlanningError.invalidInput }
        let data = try JSONSerialization.data(withJSONObject: [
            "controlPlane": ClawModelPlanningRequest.controlPlane, "kind": "planningResponse", "requestNonce": nonce,
            "proposal": ["summary": "Review a note based on the selected result", "actions": [
                ["kind": "manageFiles", "goal": "Prepare a reviewed summary", "inputs": ["path": "notes/evidence.txt", "text": "Explicit reviewed result summary"]]
            ]],
            "usage": ["inputTokens": 11, "outputTokens": 22],
            "effects": ["computerActions": false, "taskDispatched": false],
        ])
        if !held { return data }
        payload = data
        // Deliberately ignore cancellation so the Store must reject an already in-flight response.
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            Task { try? await Task.sleep(for: .seconds(4)); self.expire() }
        }
    }

    func release() {
        guard let current = continuation, let payload else { return }
        continuation = nil
        current.resume(returning: payload)
    }

    private func expire() {
        let current = continuation
        continuation = nil
        current?.resume(throwing: ClawModelPlanningError.timeout)
    }
}

private final class PreviewEvidenceDispatchRecorder: ClawGatewayTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    var count: Int { lock.withLock { calls } }
    func streamEvents(request: ClawGatewayLiveRequest, envelopeJSON: String, sessionID: UUID, taskID: UUID) -> AsyncThrowingStream<ClawGatewayWireEvent, Error> {
        lock.withLock { calls += 1 }
        return AsyncThrowingStream { $0.finish() }
    }
}

private struct PreviewDuplicateLiveFixture: ClawGatewayTransport {
    let artifact: ClawGatewayArtifact
    func streamEvents(request: ClawGatewayLiveRequest, envelopeJSON: String, sessionID: UUID, taskID: UUID) -> AsyncThrowingStream<ClawGatewayWireEvent, Error> {
        var duplicate = artifact
        duplicate.reference = "file:///second-reference-for-same-id"
        let pair = [artifact, duplicate]
        return AsyncThrowingStream { stream in
            for (index, kind) in [ClawGatewayEventKind.gatewayConnected, .artifactStored, .sessionCompleted].enumerated() {
                stream.yield(ClawGatewayWireEvent(event: .init(sessionID: sessionID, taskID: taskID, sequence: index + 10, kind: kind,
                    summary: "Duplicate identity rejection fixture", artifacts: kind == .artifactStored ? pair : [])))
            }
            stream.finish()
        }
    }
}
