import Foundation
import XCTest
@testable import Claw

@MainActor
final class ClawModelPlanningTests: XCTestCase {
    func testPlanningResponseRequiresExactShapeIdentityEffectsAndUsage() throws {
        let nonce = "planning_nonce_123"
        let data = try PlanningFixture.data(nonce: nonce)
        let decoded = try ClawModelPlanningResponse.decode(data, nonce: nonce)
        XCTAssertEqual(decoded.usage, ClawModelPlanningUsage(inputTokens: 11, outputTokens: 22))
        XCTAssertEqual(decoded.proposal.actions.count, 1)
        let mutations: [([String: Any]) -> [String: Any]] = [
            { var v = $0; v["requestNonce"] = "foreign_nonce_456"; return v },
            { var v = $0; v["extra"] = "private_marker"; return v },
            { var v = $0; v["effects"] = ["computerActions": true, "taskDispatched": false]; return v },
            { var v = $0; v["effects"] = ["computerActions": 0, "taskDispatched": 0]; return v },
            { var v = $0; v["usage"] = ["inputTokens": true, "outputTokens": 22]; return v },
            { var v = $0; v["usage"] = ["inputTokens": -1, "outputTokens": 22]; return v },
            { var v = $0; v["usage"] = ["inputTokens": 1.5, "outputTokens": 22]; return v },
        ]
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for mutate in mutations {
            let invalid = try JSONSerialization.data(withJSONObject: mutate(root))
            XCTAssertThrowsError(try ClawModelPlanningResponse.decode(invalid, nonce: nonce))
        }
    }

    func testPlanningJSONRejectsDuplicateEscapedKeysDepthAndOversizedResponse() throws {
        for raw in ["{\"a\":1,\"a\":2}", "{\"a\":{\"b\":1,\"\\u0062\":2}}", "{\"a\":" + String(repeating: "[", count: 21) + "0" + String(repeating: "]", count: 21) + "}"] {
            XCTAssertThrowsError(try ClawPlanningJSON.object(Data(raw.utf8), maxBytes: 65_536))
        }
        XCTAssertThrowsError(try ClawPlanningJSON.object(Data(repeating: 32, count: 65_537), maxBytes: 65_536))
        let valid = try ClawPlanningJSON.object(Data("{\"a\":\"comma, brace } quote \\\"\",\"b\":{\"a\":1}}".utf8), maxBytes: 1000)
        XCTAssertEqual(valid.count, 2)
    }

    func testTypedModelKindsDoNotDependOnTitleOrTargetAndCannotChooseApproval() throws {
        let actions = try ClawModelPlannedAction.inputKeys.keys.sorted { $0.rawValue < $1.rawValue }.map { kind in
            try ClawModelPlanProposal.parse(PlanningFixture.proposal(kind: kind)).actions[0]
        }
        let proposal = ClawModelPlanProposal(summary: "Typed model proposal", actions: actions)
        var plan = proposal.plan(command: "请帮我完成这个目标")
        for index in actions.indices { plan.steps[index].title = "Unrelated title"; plan.steps[index].target = "Unrelated target" }
        let task = ClawMobileBridge.makeTask(from: plan, profile: ClawStore.defaultClawGatewayProfile, selectedSkill: nil, documents: [])
        XCTAssertEqual(Array(task.actions.dropLast().map(\.kind)), actions.map(\.kind))
        XCTAssertEqual(task.actions.last?.kind, .runAgentLoop)
        XCTAssertEqual(task.status, .waitingForApproval)
        XCTAssertTrue(task.actions.allSatisfy { $0.approval == .gatewayApproval && $0.handlesSensitiveData })
        XCTAssertTrue(task.actions.allSatisfy { $0.sourceSurface == .clawGateway })
        XCTAssertNil(ClawTaskArguments.issue(in: task))
        var profile = ClawStore.defaultClawGatewayProfile
        profile.allowedActionKinds = [.observeScreen]
        let blocked = ClawMobileBridge.makeTask(from: plan, profile: profile, selectedSkill: nil, documents: [])
        XCTAssertEqual(blocked.status, .blocked)
        XCTAssertTrue(blocked.actions.filter { $0.kind != .observeScreen }.allSatisfy { $0.approval == .blocked })
    }

    func testModelProposalRejectsUnknownFieldsUnsafePathsURLsAndInputLengths() throws {
        let cases: [(ClawMobileActionKind, String, Any)] = [
            (.manageFiles, "path", "../escape.txt"), (.manageFiles, "path", "/private/file.txt"),
            (.manageFiles, "text", String(repeating: "中", count: 1366)),
            (.controlBrowser, "target", "https://user:secret@example.test"), (.controlBrowser, "target", "file:///private/file"),
            (.controlBrowser, "mode", "execute"), (.runShellCommand, "cwdPolicy", "unrestricted"),
        ]
        for (kind, key, value) in cases {
            var proposal = PlanningFixture.proposal(kind: kind)
            var actions = try XCTUnwrap(proposal["actions"] as? [[String: Any]])
            var inputs = try XCTUnwrap(actions[0]["inputs"] as? [String: String]).mapValues { $0 as Any }
            inputs[key] = value; actions[0]["inputs"] = inputs; proposal["actions"] = actions
            XCTAssertThrowsError(try ClawModelPlanProposal.parse(proposal))
        }
        for key in ["approval", "toolArguments", "riskScore", "receipt"] {
            var proposal = PlanningFixture.proposal()
            var actions = try XCTUnwrap(proposal["actions"] as? [[String: Any]])
            actions[0][key] = "private_marker"; proposal["actions"] = actions
            XCTAssertThrowsError(try ClawModelPlanProposal.parse(proposal))
        }
        for kind in ["runAgentLoop", "blockedUnsupported", "unknownAction"] {
            var proposal = PlanningFixture.proposal()
            var actions = try XCTUnwrap(proposal["actions"] as? [[String: Any]])
            actions[0]["kind"] = kind; proposal["actions"] = actions
            XCTAssertThrowsError(try ClawModelPlanProposal.parse(proposal))
        }
    }

    func testPlanningWireUsesHeaderOnlyTokenFixedPathAndSecureRemoteOrigin() throws {
        let request = try ClawModelPlanningRequest(command: "Only this task text")
        var profile = ClawStore.defaultClawGatewayProfile
        profile.endpoint = "wss://gateway.example.test/custom/path"
        profile.tokenFingerprint = ClawMobileBridge.tokenFingerprint(for: "planning-secret")
        let wire = try ClawModelPlanningWireRequest.make(request, profile: profile, token: "planning-secret")
        XCTAssertEqual(wire.url.absoluteString, "https://gateway.example.test/claw/planning")
        XCTAssertEqual(wire.headers["Authorization"], "Bearer planning-secret")
        let body = try ClawPlanningJSON.object(wire.body, maxBytes: 32768)
        XCTAssertEqual(Set(body.keys), ["controlPlane", "kind", "requestNonce", "command"])
        XCTAssertFalse(String(decoding: wire.body, as: UTF8.self).contains("planning-secret"))
        for endpoint in ["ws://gateway.example.test", "wss://user:secret@gateway.example.test", "wss://gateway.example.test?token=private", "https://gateway.example.test"] {
            profile.endpoint = endpoint
            XCTAssertThrowsError(try ClawModelPlanningWireRequest.make(request, profile: profile, token: "planning-secret"))
        }
        profile.endpoint = "ws://127.0.0.1:18789"
        XCTAssertNoThrow(try ClawModelPlanningWireRequest.make(request, profile: profile, token: "planning-secret"))
        XCTAssertThrowsError(try ClawModelPlanningWireRequest.make(request, profile: profile, token: "changed-secret"))
    }

    func testPlanningSuccessOnlyUpdatesPlanAndUsageNotExecutionOrCheckpoint() async throws {
        let checkpointRecorder = PlanningCheckpointRecorder()
        let store = makeStore(checkpointStore: checkpointRecorder)
        store.generatePhoneAgentPlan(); store.queueClawMobileTaskFromCurrentPlan()
        let tasks = store.clawMobileTasks
        let sessions = store.clawGatewaySessions
        let events = store.gatewayEvents
        let envelope = store.lastClawMobileEnvelope
        let mission = store.autonomousLoop
        let checkpoint = store.missionRunCheckpointForTesting
        let savedCount = checkpointRecorder.count
        let recorder = PlanningRecorder()
        await store.requestModelPlan(transport: recorder)
        XCTAssertEqual(store.modelPlanningPhase, .ready)
        XCTAssertEqual(store.phoneAgentPlan.source, .configuredModel)
        XCTAssertEqual(store.modelPlanningUsage, ClawModelPlanningUsage(inputTokens: 11, outputTokens: 22))
        XCTAssertEqual(store.clawMobileTasks, tasks)
        XCTAssertEqual(store.clawGatewaySessions, sessions)
        XCTAssertEqual(store.gatewayEvents, events)
        XCTAssertEqual(store.lastClawMobileEnvelope, envelope)
        XCTAssertEqual(store.autonomousLoop, mission)
        XCTAssertEqual(store.missionRunCheckpointForTesting, checkpoint)
        XCTAssertEqual(checkpointRecorder.count, savedCount)
        XCTAssertNil(store.lastGatewayLiveRequest)
        let calls = await recorder.count
        XCTAssertEqual(calls, 1)
    }

    func testModelMissingInputCannotPassExistingLiveDispatchGate() async throws {
        let store = makeStore()
        await store.requestModelPlan(transport: PlanningRecorder(missingText: true))
        store.queueClawMobileTaskFromCurrentPlan()
        XCTAssertEqual(store.phoneAgentPlan.source, .configuredModel)
        XCTAssertEqual(store.clawMobileTasks.first?.status, .waitingForApproval)
        XCTAssertEqual(store.clawMobileTasks.first.flatMap { ClawTaskArguments.issue(in: $0) }, .missingInput)
        store.gatewayDispatchMode = .liveGateway
        store.approveLatestClawMobileTask()
        let recorder = PlanningDispatchRecorder()
        await store.sendLatestClawMobileTaskOverLiveGateway(transport: recorder)
        XCTAssertEqual(recorder.count, 0)
        XCTAssertTrue(store.clawGatewaySessions.isEmpty)
        XCTAssertTrue(store.gatewayEvents.isEmpty)
    }

    func testMissionPreservesReviewedModelPlanAndExactArgumentsInsteadOfKeywordReplanning() async throws {
        let store = makeStore()
        await store.requestModelPlan(transport: PlanningRecorder())
        let plan = store.phoneAgentPlan
        store.gatewayDispatchMode = .liveGateway
        store.startAutonomousComputerTakeover()
        XCTAssertEqual(store.phoneAgentPlan, plan)
        XCTAssertEqual(store.autonomousLoop.phase, .waitingForUserApproval)
        let task = try XCTUnwrap(store.clawMobileTasks.first)
        XCTAssertEqual(task.actions.map(\.kind), [.manageFiles, .runAgentLoop])
        XCTAssertEqual(task.actions[0].toolArguments["writeText"], "Explicit model text")
        XCTAssertTrue(store.clawGatewaySessions.isEmpty)
        store.approveLatestClawMobileTask(); store.sendTask(id: task.id)
        let wire = try JSONDecoder.clawGateway.decode(ClawMobileEnvelope.self, from: Data(store.lastClawMobileEnvelope.utf8))
        XCTAssertEqual(wire.task.status, .sent)
        XCTAssertEqual(wire.task.actions, task.actions)
    }

    func testPlanningFailureDoesNotReplacePlanOrAutoFallback() async {
        let store = makeStore()
        let plan = store.phoneAgentPlan
        await store.requestModelPlan(transport: PlanningRecorder(fails: true))
        XCTAssertEqual(store.modelPlanningPhase, .failed(.transport))
        XCTAssertEqual(store.phoneAgentPlan, plan)
        XCTAssertTrue(store.clawMobileTasks.isEmpty && store.clawGatewaySessions.isEmpty && store.gatewayEvents.isEmpty)
    }

    func testInvalidConfigurationAndInputHaveZeroModelTransportCalls() async {
        for endpoint in ["", "ws://gateway.example.test", "wss://user:secret@example.test"] {
            let store = makeStore()
            store.setGateway(url: endpoint, token: "planning-secret")
            let recorder = PlanningRecorder()
            await store.requestModelPlan(transport: recorder)
            let count = await recorder.count
            XCTAssertEqual(count, 0)
            XCTAssertEqual(store.modelPlanningPhase, .failed(.configuration))
        }
        let store = makeStore()
        store.phoneAgentCommand = String(repeating: "x", count: 4097)
        let recorder = PlanningRecorder()
        await store.requestModelPlan(transport: recorder)
        let count = await recorder.count
        XCTAssertEqual(count, 0)
        XCTAssertEqual(store.modelPlanningPhase, .failed(.invalidInput))
    }

    func testPlanningDuplicateCancelAndOldResultCannotOverwriteNewOperation() async throws {
        let store = makeStore()
        let held = PlanningRecorder(held: true, ignoresCancellation: true)
        let first = Task { await store.requestModelPlan(transport: held) }
        let started = await waitFor(held)
        XCTAssertTrue(started)
        await store.requestModelPlan(transport: held)
        let count = await held.count
        XCTAssertEqual(count, 1)
        store.cancelModelPlanning()
        XCTAssertEqual(store.modelPlanningPhase, .cancelled)
        let replacement = PlanningRecorder()
        await store.requestModelPlan(transport: replacement)
        let current = store.phoneAgentPlan
        await held.release()
        await first.value
        XCTAssertEqual(store.phoneAgentPlan, current)
        XCTAssertEqual(store.modelPlanningPhase, .ready)
        XCTAssertTrue(store.clawMobileTasks.isEmpty)
    }

    func testPlanningScopeRevisionMatrixDropsStaleResults() async {
        let mutations: [(ClawStore) -> Void] = [
            { let old = $0.phoneAgentCommand; $0.phoneAgentCommand = "other"; $0.phoneAgentCommand = old },
            { $0.gatewayToken = "other"; $0.gatewayToken = "planning-secret" },
            { $0.generatePhoneAgentPlan() },
            { $0.queueClawMobileTaskFromCurrentPlan() },
            { $0.startAutonomousComputerTakeover() },
        ]
        for mutate in mutations {
            let store = makeStore()
            let held = PlanningRecorder(held: true, ignoresCancellation: true)
            let operation = Task { await store.requestModelPlan(transport: held) }
            let started = await waitFor(held)
            XCTAssertTrue(started)
            mutate(store)
            let currentPlan = store.phoneAgentPlan
            let currentTasks = store.clawMobileTasks
            await held.release(); await operation.value
            XCTAssertEqual(store.phoneAgentPlan, currentPlan)
            XCTAssertEqual(store.clawMobileTasks, currentTasks)
            XCTAssertNotEqual(store.modelPlanningPhase, .ready)
        }
    }

    func testAcceptedModelPlanBecomesUnqueueableAfterCommandOrProfileRevision() async {
        for changeProfile in [false, true] {
            let store = makeStore()
            await store.requestModelPlan(transport: PlanningRecorder())
            if changeProfile { store.setGateway(url: "ws://127.0.0.1:18789", token: "new-secret") }
            else { let old = store.phoneAgentCommand; store.phoneAgentCommand = "other"; store.phoneAgentCommand = old }
            store.queueClawMobileTaskFromCurrentPlan()
            store.startAutonomousComputerTakeover()
            XCTAssertTrue(store.clawMobileTasks.isEmpty)
            XCTAssertEqual(store.modelPlanningPhase, .stale)
        }
    }

    private func makeStore(checkpointStore: any ClawMissionRunCheckpointStore = ClawNoopMissionRunCheckpointStore()) -> ClawStore {
        let store = ClawStore(autoScanLocalArtifacts: false, checkpointStore: checkpointStore)
        store.setGateway(url: "ws://127.0.0.1:18789", token: "planning-secret")
        store.phoneAgentCommand = "请帮我完成这个目标"
        return store
    }

    private func waitFor(_ recorder: PlanningRecorder) async -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if await recorder.count > 0 { return true }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        return false
    }
}

private enum PlanningFixture {
    static func proposal(kind: ClawMobileActionKind = .manageFiles, missingText: Bool = false) -> [String: Any] {
        let inputs: [String: String]
        switch kind {
        case .observeScreen: inputs = [:]
        case .controlBrowser: inputs = ["mode": "url", "app": "Safari", "target": "https://example.test/docs"]
        case .manageFiles: inputs = ["path": "notes/model.txt", "text": missingText ? "" : "Explicit model text"]
        case .runShellCommand: inputs = ["command": "pwd"]
        case .operateDesktopApp: inputs = ["app": "TextEdit", "text": "Explicit desktop text", "keys": ""]
        case .extractData: inputs = ["path": "reports/model.json"]
        case .composeMessage, .composeEmail: inputs = ["recipient": "reviewed-recipient", "text": "Explicit draft text"]
        default: inputs = [:]
        }
        return ["summary": "A validated model plan", "actions": [["kind": kind.rawValue, "goal": "Review the requested task", "inputs": inputs]]]
    }
    static func data(nonce: String, missingText: Bool = false) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["controlPlane": ClawModelPlanningRequest.controlPlane, "kind": "planningResponse",
            "requestNonce": nonce, "proposal": proposal(missingText: missingText), "usage": ["inputTokens": 11, "outputTokens": 22],
            "effects": ["computerActions": false, "taskDispatched": false]])
    }
}

private actor PlanningRecorder: ClawModelPlanningTransport {
    private(set) var count = 0
    let held: Bool
    let ignoresCancellation: Bool
    let missingText: Bool
    let fails: Bool
    var continuation: CheckedContinuation<Data, Error>?
    var payload: Data?
    init(held: Bool = false, ignoresCancellation: Bool = false, missingText: Bool = false, fails: Bool = false) {
        self.held = held; self.ignoresCancellation = ignoresCancellation; self.missingText = missingText; self.fails = fails
    }
    func response(for request: ClawModelPlanningWireRequest) async throws -> Data {
        count += 1
        if fails { throw URLError(.cannotConnectToHost) }
        let body = try ClawPlanningJSON.object(request.body, maxBytes: 32768)
        guard let nonce = body["requestNonce"] as? String else { throw ClawModelPlanningError.invalidInput }
        let data = try PlanningFixture.data(nonce: nonce, missingText: missingText)
        if !held { return data }
        payload = data
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                Task { try? await Task.sleep(nanoseconds: 5_000_000_000); self.expire() }
            }
        } onCancel: { Task { await self.cancelIfNeeded() } }
    }
    func release() {
        guard let continuation, let payload else { return }
        self.continuation = nil
        continuation.resume(returning: payload)
    }
    private func expire() {
        let current = continuation; continuation = nil
        current?.resume(throwing: ClawModelPlanningError.timeout)
    }
    private func cancelIfNeeded() {
        if !ignoresCancellation {
            let current = continuation; continuation = nil
            current?.resume(throwing: CancellationError())
        }
    }
}

private final class PlanningDispatchRecorder: ClawGatewayTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    var count: Int { lock.withLock { calls } }
    func streamEvents(request: ClawGatewayLiveRequest, envelopeJSON: String, sessionID: UUID, taskID: UUID) -> AsyncThrowingStream<ClawGatewayWireEvent, Error> {
        lock.withLock { calls += 1 }
        return AsyncThrowingStream { $0.finish() }
    }
}

private final class PlanningCheckpointRecorder: ClawMissionRunCheckpointStore, @unchecked Sendable {
    private let lock = NSLock()
    private var saves = 0
    var count: Int { lock.withLock { saves } }
    func load() -> ClawMissionRunCheckpointLoadResult { .none }
    func save(_ checkpoint: ClawMissionRunCheckpoint) -> ClawMissionRunCheckpointWriteResult {
        lock.withLock { saves += 1 }
        return .saved
    }
    func clear() -> ClawMissionRunCheckpointWriteResult { .cleared }
}
