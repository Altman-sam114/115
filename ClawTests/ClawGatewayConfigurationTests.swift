import Foundation
import Security
import XCTest
@testable import Claw

@MainActor
final class ClawGatewayConfigurationTests: XCTestCase {
    func testConnectionContractAcceptsOnlySecureRemoteOrExactLoopbackOrigins() throws {
        for endpoint in ["wss://gateway.example.test/socket", "ws://127.0.0.1:18789", "ws://localhost:18789", "ws://[::1]:18789"] {
            let pair = try ClawGatewayConfiguration(endpoint: endpoint, token: "connection-test-token")
            XCTAssertTrue(pair.endpoint == endpoint)
        }
        for endpoint in Self.invalidEndpoints {
            XCTAssertThrowsError(try ClawGatewayConfiguration(endpoint: endpoint, token: "connection-test-token"))
        }
        for token in ["", " ", "token with space", "token\r\nInjected:yes", "token\n", "token\0", "令牌", String(repeating: "a", count: 4_097)] {
            XCTAssertThrowsError(try ClawGatewayConfiguration(endpoint: "wss://gateway.example.test", token: token))
        }
    }

    func testSecretRecordIsBoundedVersionedExactAndRejectsDuplicateKeys() throws {
        let pair = try Self.pair()
        let roundTrip = try ClawGatewayConfiguration.decodeSecretRecord(pair.encodedSecretRecord())
        XCTAssertTrue(roundTrip == pair, "Secret pair must round-trip without mixing endpoint and credential")
        let boundary = try ClawGatewayConfiguration(endpoint: "wss://gateway.example.test/" + String(repeating: "a", count: 1_900),
                                                    token: String(repeating: "\"", count: 4_096))
        let boundaryResult = try ClawGatewayConfiguration.decodeSecretRecord(boundary.encodedSecretRecord())
        XCTAssertTrue(boundaryResult == boundary)
        let invalid = [
            "{}", "[]", "{\"version\":2}",
            "{\"version\":\"claw.gateway.connection.v2\",\"endpoint\":\"wss://host\",\"token\":\"t\"}",
            "{\"version\":\"claw.gateway.connection.v1\",\"endpoint\":\"wss://host\",\"token\":\"t\",\"task\":{}}",
            "{\"version\":\"claw.gateway.connection.v1\",\"endpoint\":\"wss://host\",\"token\":\"t\",\"to\\u006ben\":\"other\"}",
            "{\"version\":\"claw.gateway.connection.v1\",\"endpoint\":\"wss://host\",\"token\":false}",
            String(repeating: " ", count: 16_385)
        ]
        for record in invalid {
            XCTAssertThrowsError(try ClawGatewayConfiguration.decodeSecretRecord(Data(record.utf8)))
        }
    }

    func testDefaultStoreNeverReadsProductionCredentialsOrUsesHardcodedLAN() {
        let store = ClawStore(autoScanLocalArtifacts: false)
        XCTAssertEqual(store.gatewayConfigurationState, .notSaved)
        XCTAssertTrue(store.gatewayURL.isEmpty && store.gatewayToken.isEmpty)
        XCTAssertTrue(store.clawGatewayProfile.endpoint.isEmpty)
        XCTAssertFalse(store.gatewayConfigurationIsReady)
        XCTAssertFalse(store.gatewayHasUnappliedChanges)
        assertNoExecution(store)
    }

    func testRestoringConnectionNeverRestoresTasksAuthorizationOrNetworking() throws {
        let pair = try Self.pair()
        let memory = ConfigurationMemoryStore(pair: pair)
        let checkpoint = ClawInMemoryMissionRunCheckpointStore()
        let store = ClawStore(autoScanLocalArtifacts: false, checkpointStore: checkpoint, gatewayConfigurationStore: memory)
        XCTAssertEqual(memory.loadCount, 1)
        XCTAssertEqual(memory.saveCount, 0)
        XCTAssertEqual(memory.clearCount, 0)
        XCTAssertEqual(checkpoint.saveCount, 0)
        XCTAssertEqual(store.gatewayConfigurationState, .restored)
        XCTAssertTrue(store.gatewayConfigurationIsReady)
        XCTAssertTrue(store.gatewayToken == pair.token && store.gatewayURL == pair.endpoint)
        XCTAssertTrue(store.clawGatewayProfile == configuredProfile(pair))
        assertNoExecution(store)
    }

    func testExplicitSavePublishesOnePairAndRelaunchOnlyRestoresConnection() throws {
        let pair = try Self.pair()
        let memory = ConfigurationMemoryStore()
        let store = ClawStore(autoScanLocalArtifacts: false, gatewayConfigurationStore: memory)
        store.gatewayURL = pair.endpoint
        store.gatewayToken = pair.token
        XCTAssertTrue(store.gatewayHasUnappliedChanges)
        XCTAssertFalse(store.gatewayConfigurationIsReady)
        XCTAssertEqual(memory.saveCount, 0)
        XCTAssertTrue(store.saveGatewayConfiguration())
        XCTAssertEqual(memory.saveCount, 1)
        XCTAssertTrue(memory.pair == pair)
        XCTAssertEqual(store.gatewayConfigurationState, .saved)
        XCTAssertTrue(store.gatewayConfigurationIsReady)
        assertNoExecution(store)
        store.generatePhoneAgentPlan()
        store.queueClawMobileTaskFromCurrentPlan()
        store.approveLatestClawMobileTask()
        XCTAssertFalse(store.clawMobileTasks.isEmpty)
        let next = ClawStore(autoScanLocalArtifacts: false, gatewayConfigurationStore: memory)
        XCTAssertEqual(memory.saveCount, 1)
        XCTAssertEqual(next.gatewayConfigurationState, .restored)
        XCTAssertTrue(next.gatewayConfigurationIsReady)
        assertNoExecution(next)
    }

    func testSaveFailureKeepsAppliedPairAndNeverTreatsDraftAsSaved() throws {
        for result in [ClawGatewayConfigurationWriteResult.failed, .unavailable] {
            let original = try Self.pair()
            let memory = ConfigurationMemoryStore(pair: original)
            let store = ClawStore(autoScanLocalArtifacts: false, gatewayConfigurationStore: memory)
            memory.saveResult = result
            store.gatewayURL = "wss://replacement.example.test/socket"
            store.gatewayToken = "replacement-private-token"
            XCTAssertFalse(store.saveGatewayConfiguration())
            XCTAssertTrue(memory.pair == original)
            XCTAssertTrue(store.clawGatewayProfile == configuredProfile(original))
            XCTAssertTrue(store.gatewayHasUnappliedChanges)
            XCTAssertFalse(store.gatewayConfigurationIsReady)
            XCTAssertEqual(store.gatewayConfigurationState, result == .failed ? .saveFailed : .unavailable)
            XCTAssertFalse(store.gatewayConfigurationState.message.contains("replacement-private-token"))
            store.discardGatewayConfigurationDraft()
            XCTAssertFalse(store.gatewayHasUnappliedChanges)
            XCTAssertTrue(store.gatewayConfigurationIsReady)
            XCTAssertTrue(store.gatewayToken == original.token)
            XCTAssertEqual(memory.loadCount, 1)
            XCTAssertEqual(memory.saveCount, 1)
            assertNoExecution(store)
        }
    }

    func testInvalidInputDoesNotWriteAndInvalidUnavailableLoadsHaveNoFallback() throws {
        let memory = ConfigurationMemoryStore()
        let checkpoint = ClawInMemoryMissionRunCheckpointStore()
        let store = ClawStore(autoScanLocalArtifacts: false, checkpointStore: checkpoint, gatewayConfigurationStore: memory)
        for endpoint in Self.invalidEndpoints {
            store.gatewayURL = endpoint
            store.gatewayToken = "test-token"
            XCTAssertFalse(store.saveGatewayConfiguration())
            XCTAssertEqual(store.gatewayConfigurationState, .invalidInput(.invalidEndpoint))
        }
        XCTAssertEqual(memory.saveCount, 0)
        for result in [ClawGatewayConfigurationLoadResult.invalid, .unavailable] {
            memory.loadResult = result
            store.reloadSavedGatewayConfiguration()
            XCTAssertTrue(store.clawGatewayProfile.endpoint.isEmpty)
            XCTAssertFalse(store.gatewayConfigurationIsReady)
            XCTAssertEqual(store.gatewayConfigurationState, result == .invalid ? .invalidRecord : .unavailable)
            XCTAssertEqual(memory.saveCount, 0)
            XCTAssertEqual(memory.clearCount, 0)
            XCTAssertEqual(checkpoint.saveCount, 0)
            assertNoExecution(store)
        }
        let pair = try Self.pair()
        memory.loadResult = .loaded(pair)
        store.reloadSavedGatewayConfiguration()
        XCTAssertTrue(store.gatewayConfigurationIsReady)
        XCTAssertFalse(store.gatewayHasUnappliedChanges)
        XCTAssertEqual(store.gatewayConfigurationState, .restored)
        XCTAssertEqual(checkpoint.saveCount, 0)
        assertNoExecution(store)
    }

    func testClearOnlyDropsActivePairAfterConfirmedStorageSuccess() throws {
        let original = try Self.pair()
        let memory = ConfigurationMemoryStore(pair: original)
        let store = ClawStore(autoScanLocalArtifacts: false, gatewayConfigurationStore: memory)
        memory.clearResult = .failed
        XCTAssertFalse(store.clearSavedGatewayConfiguration())
        XCTAssertEqual(store.gatewayConfigurationState, .clearFailed)
        XCTAssertTrue(memory.pair == original && store.gatewayConfigurationIsReady)
        memory.clearResult = .cleared
        XCTAssertTrue(store.clearSavedGatewayConfiguration())
        XCTAssertEqual(memory.clearCount, 2)
        XCTAssertNil(memory.pair)
        XCTAssertEqual(store.gatewayConfigurationState, .cleared)
        XCTAssertTrue(store.gatewayURL.isEmpty && store.gatewayToken.isEmpty && store.clawGatewayProfile.endpoint.isEmpty)
        XCTAssertEqual(store.clawGatewayProfile.tokenFingerprint, "unset")
        XCTAssertFalse(store.gatewayConfigurationIsReady)
        XCTAssertFalse(store.gatewayHasUnappliedChanges)
        let next = ClawStore(autoScanLocalArtifacts: false, gatewayConfigurationStore: memory)
        XCTAssertTrue(next.gatewayURL.isEmpty && next.gatewayToken.isEmpty)
        assertNoExecution(store)
        assertNoExecution(next)
    }

    func testDirtyAddressOrCredentialBlocksEveryTransportBeforeCreatingSession() async throws {
        let changes: [(ClawStore) -> Void] = [
            { $0.gatewayURL = "wss://replacement.example.test" },
            { $0.gatewayToken = "replacement-private-token" },
            { $0.gatewayURL = "wss://replacement.example.test"; $0.gatewayToken = "replacement-private-token" },
            { $0.gatewayToken = "invalid\r\nInjected:yes" }
        ]
        for change in changes {
            let pair = try Self.pair()
            let memory = ConfigurationMemoryStore(pair: pair)
            let checkpoint = ClawInMemoryMissionRunCheckpointStore()
            let store = ClawStore(autoScanLocalArtifacts: false, checkpointStore: checkpoint, gatewayConfigurationStore: memory)
            store.phoneAgentCommand = "打开浏览器搜索资料"
            store.generatePhoneAgentPlan()
            store.queueClawMobileTaskFromCurrentPlan()
            store.gatewayDispatchMode = .liveGateway
            store.approveLatestClawMobileTask()
            XCTAssertEqual(store.clawMobileTasks.first?.status, .readyToSend)
            let tasks = store.clawMobileTasks
            let saves = checkpoint.saveCount
            change(store)
            XCTAssertTrue(store.gatewayHasUnappliedChanges)
            XCTAssertFalse(store.gatewayConfigurationIsReady)
            let transports = ConfigurationRejectingTransports()
            let probe = await store.probeLiveGatewayTransport(transport: transports)
            let readiness = await store.requestGatewayReadiness(transport: transports)
            await store.requestModelPlan(transport: transports)
            store.approveLatestClawMobileTask()
            store.sendLatestClawMobileTask()
            await store.sendLatestClawMobileTaskOverLiveGateway(transport: transports)
            XCTAssertFalse(probe || readiness)
            XCTAssertEqual(store.modelPlanningPhase, .failed(.configuration))
            XCTAssertEqual(transports.calls, 0)
            XCTAssertTrue(store.clawMobileTasks == tasks)
            XCTAssertTrue(store.clawGatewaySessions.isEmpty && store.gatewayEvents.isEmpty)
            XCTAssertNil(store.lastGatewayLiveRequest)
            XCTAssertEqual(memory.saveCount, 0)
            XCTAssertEqual(checkpoint.saveCount, saves)
            store.discardGatewayConfigurationDraft()
            XCTAssertTrue(store.gatewayConfigurationIsReady)
            // Returning to the same pair does not resurrect a prior task approval.
            await store.sendLatestClawMobileTaskOverLiveGateway(transport: transports)
            XCTAssertEqual(transports.calls, 0)
            XCTAssertTrue(store.clawGatewaySessions.isEmpty && store.gatewayEvents.isEmpty)
            store.approveLatestClawMobileTask()
            await store.sendLatestClawMobileTaskOverLiveGateway(transport: transports)
            XCTAssertEqual(transports.calls, 1)
            XCTAssertEqual(store.clawGatewaySessions.count, 1)
            XCTAssertEqual(store.clawGatewaySessions.first?.artifactCount, 0)
        }
    }

    func testUnsafeAppliedFixtureCannotCarryBearerInLiveRequest() throws {
        let store = ClawStore(autoScanLocalArtifacts: false)
        store.generatePhoneAgentPlan()
        store.queueClawMobileTaskFromCurrentPlan()
        let task = try XCTUnwrap(store.clawMobileTasks.first)
        for endpoint in Self.invalidEndpoints {
            var profile = configuredProfile(try Self.pair())
            profile.endpoint = endpoint
            let request = ClawGatewayLiveClient.makeRequest(task: task, profile: profile, envelopeJSON: "{}", rawToken: "connection-test-token")
            XCTAssertFalse(request.canAttemptLive)
            XCTAssertNil(request.headers["Authorization"])
        }
        let profile = configuredProfile(try Self.pair())
        let request = ClawGatewayLiveClient.makeRequest(task: task, profile: profile, envelopeJSON: "{}", rawToken: "different-token")
        XCTAssertFalse(request.canAttemptLive)
        XCTAssertNil(request.headers["Authorization"])
    }

    func testReloadFailuresKeepPreviousAppliedPairAndReloadSuccessInvalidatesApproval() async throws {
        let pair = try Self.pair()
        let memory = ConfigurationMemoryStore(pair: pair)
        let store = ClawStore(autoScanLocalArtifacts: false, gatewayConfigurationStore: memory)
        store.phoneAgentCommand = "打开浏览器搜索资料"
        store.generatePhoneAgentPlan()
        store.queueClawMobileTaskFromCurrentPlan()
        store.gatewayDispatchMode = .liveGateway
        store.approveLatestClawMobileTask()
        for result in [ClawGatewayConfigurationLoadResult.invalid, .unavailable] {
            memory.loadResult = result
            store.reloadSavedGatewayConfiguration()
            XCTAssertTrue(store.gatewayConfigurationIsReady && store.gatewayToken == pair.token)
        }
        memory.loadResult = .loaded(pair)
        store.reloadSavedGatewayConfiguration()
        let transport = ConfigurationRejectingTransports()
        await store.sendLatestClawMobileTaskOverLiveGateway(transport: transport)
        XCTAssertEqual(transport.calls, 0)
        XCTAssertTrue(store.gatewayEvents.isEmpty && store.clawGatewaySessions.isEmpty)
    }

    func testProductionWebSocketTransportsIndependentlyRejectUnsafeOriginsAndHeaders() async throws {
        let transport = URLSessionClawGatewayTransport()
        for (endpoint, header) in Self.invalidEndpoints.map({ ($0, "Bearer test-token") }) + [
            ("wss://gateway.example.test", "Bearer invalid\r\nInjected:yes"),
            ("wss://gateway.example.test", "Basic test-token")
        ] {
            let taskID = UUID(), sessionID = UUID()
            let request = ClawGatewayLiveRequest(endpoint: endpoint, tokenFingerprint: "sha256:fixture", headers: ["Authorization": header],
                bodyBytes: 0, taskID: taskID, command: "fixture", actionCount: 0, canAttemptLive: true, preflightMessage: "fixture")
            do {
                _ = try await transport.probeTransport(request: request, timeoutNanoseconds: 1_000_000)
                XCTFail("Unsafe probe must fail before creating a socket")
            } catch {
                XCTAssertTrue((error as? ClawGatewayTransportProbeError) == .invalidConfiguration)
            }
            let readiness = ClawGatewayReadinessTransportRequest(endpoint: endpoint, safeEndpointDisplay: "omitted",
                headers: ["Authorization": header], body: try ClawGatewayReadinessRequest(requestNonce: "configuration_nonce_123"), bindingDigest: "fixture")
            do {
                _ = try await transport.requestReadiness(request: readiness, timeoutNanoseconds: 1_000_000)
                XCTFail("Unsafe readiness must fail before creating a socket")
            } catch {
                XCTAssertTrue((error as? ClawGatewayReadinessTransportError) == .invalidConfiguration)
            }
            do {
                for try await _ in transport.streamEvents(request: request, envelopeJSON: "{}", sessionID: sessionID, taskID: taskID) {
                    XCTFail("Unsafe dispatch must produce no events")
                }
                XCTFail("Unsafe dispatch must fail before creating a socket")
            } catch {
                guard let transportError = error as? ClawGatewayTransportError, case .invalidEndpoint = transportError else {
                    XCTFail("Expected fixed local endpoint rejection"); continue
                }
                XCTAssertEqual(error.localizedDescription, "Invalid Claw Gateway endpoint")
            }
        }
    }

    func testRealKeychainIsolatedNamespaceRoundTripReplacementProtectionAndDeletion() throws {
        let service = "app.claw.gateway.connection.test." + UUID().uuidString
        XCTAssertNotEqual(service, ClawGatewayKeychainStore.productionService)
        let keychain = ClawGatewayKeychainStore(service: service)
        defer { _ = keychain.clear() }
        XCTAssertEqual(keychain.load(), .none)
        let pair = try Self.pair()
        XCTAssertEqual(keychain.save(pair), .saved)
        guard case .loaded(let loaded) = keychain.load() else { return XCTFail("Isolated Keychain record must load") }
        XCTAssertTrue(loaded == pair)
        let replacement = try ClawGatewayConfiguration(endpoint: "wss://replacement.example.test/socket", token: "replacement-test-token")
        XCTAssertEqual(keychain.save(replacement), .saved)
        let reopened = ClawGatewayKeychainStore(service: service)
        guard case .loaded(let updated) = reopened.load() else { return XCTFail("Replacement must load atomically") }
        XCTAssertTrue(updated == replacement)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: "connection", kSecReturnAttributes as String: true,
                                    kSecAttrSynchronizable as String: false, kSecMatchLimit as String: kSecMatchLimitAll]
        var value: CFTypeRef?
        XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, &value), errSecSuccess)
        let rows = try XCTUnwrap(value as? [[String: Any]])
        XCTAssertEqual(rows.count, 1)
        XCTAssertTrue(rows[0][kSecAttrAccessible as String] as? String == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        XCTAssertTrue((rows[0][kSecAttrSynchronizable as String] as? Bool) == false)
        XCTAssertEqual(reopened.clear(), .cleared)
        XCTAssertEqual(keychain.load(), .none)
        XCTAssertEqual(keychain.clear(), .cleared)
    }

    func testRealKeychainCorruptRecordIsNotAppliedOrSilentlyDeleted() throws {
        let service = "app.claw.gateway.connection.test." + UUID().uuidString
        let keychain = ClawGatewayKeychainStore(service: service)
        defer { _ = keychain.clear() }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: "connection", kSecAttrSynchronizable as String: false]
        let data = Data("{\"version\":\"future\",\"token\":\"private-marker\"}".utf8)
        XCTAssertEqual(SecItemAdd(query.merging([kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]) { _, new in new } as CFDictionary, nil), errSecSuccess)
        XCTAssertEqual(keychain.load(), .invalid)
        var item: CFTypeRef?
        let read = query.merging([kSecReturnData as String: true]) { _, new in new }
        XCTAssertEqual(SecItemCopyMatching(read as CFDictionary, &item), errSecSuccess)
        XCTAssertTrue((item as? Data) == data)
        XCTAssertEqual(keychain.clear(), .cleared)
        XCTAssertEqual(keychain.load(), .none)
    }

    private static func pair() throws -> ClawGatewayConfiguration {
        try ClawGatewayConfiguration(endpoint: "wss://gateway.example.test/socket", token: "connection-test-token")
    }

    private func configuredProfile(_ pair: ClawGatewayConfiguration) -> ClawGatewayProfile {
        var profile = ClawStore.defaultClawGatewayProfile
        profile.endpoint = pair.endpoint
        profile.tokenFingerprint = ClawMobileBridge.tokenFingerprint(for: pair.token)
        return profile
    }

    private func assertNoExecution(_ store: ClawStore, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(store.clawMobileTasks.isEmpty && store.clawGatewaySessions.isEmpty && store.gatewayEvents.isEmpty, file: file, line: line)
        XCTAssertNil(store.lastGatewayLiveRequest, file: file, line: line)
        XCTAssertEqual(store.gatewayConnectionState, .idle, file: file, line: line)
        XCTAssertEqual(store.gatewayDispatchMode, .simulatedEventStream, file: file, line: line)
        XCTAssertEqual(store.modelPlanningPhase, .idle, file: file, line: line)
        XCTAssertEqual(store.autonomousLoop.phase, .idle, file: file, line: line)
        XCTAssertEqual(store.continuationReceiptCountForTesting, 0, file: file, line: line)
        XCTAssertEqual(store.continuationApprovalRecordCountForTesting, 0, file: file, line: line)
        XCTAssertEqual(store.frozenContinuationEnvelopeCountForTesting, 0, file: file, line: line)
    }

    private static let invalidEndpoints = [
        "", "https://gateway.example.test", "ws://gateway.example.test", "ws://192.168.1.12:18789",
        "ws://127.0.0.1.example.test", "ws://localhost.example.test", "ws://127.1:18789",
        "wss://user:password@gateway.example.test", "wss://gateway.example.test?token=private-marker",
        "wss://gateway.example.test#fragment", "wss://", "wss://gateway.example.test:0",
        "wss://gateway.example.test:65536", "wss://gateway.example.test/has space", "wss://gateway.example.test\\path",
        "wss://gateway.example.test/\r\n", "ws://%31%32%37.0.0.1", "wss://gateway.example.test/%ZZ",
        "wss://gateway.example.test/" + String(repeating: "a", count: 2_048)
    ]
}

private final class ConfigurationMemoryStore: @unchecked Sendable, ClawGatewayConfigurationStore {
    var pair: ClawGatewayConfiguration?
    var loadResult: ClawGatewayConfigurationLoadResult?
    var saveResult: ClawGatewayConfigurationWriteResult = .saved
    var clearResult: ClawGatewayConfigurationClearResult = .cleared
    private(set) var loadCount = 0
    private(set) var saveCount = 0
    private(set) var clearCount = 0
    init(pair: ClawGatewayConfiguration? = nil) { self.pair = pair }
    func load() -> ClawGatewayConfigurationLoadResult {
        loadCount += 1
        return loadResult ?? pair.map { .loaded($0) } ?? .none
    }
    func save(_ configuration: ClawGatewayConfiguration) -> ClawGatewayConfigurationWriteResult {
        saveCount += 1
        if saveResult == .saved { pair = configuration }
        return saveResult
    }
    func clear() -> ClawGatewayConfigurationClearResult {
        clearCount += 1
        if clearResult == .cleared { pair = nil }
        return clearResult
    }
}

private final class ConfigurationRejectingTransports: @unchecked Sendable, ClawGatewayTransport, ClawGatewayProbeTransport,
    ClawGatewayReadinessTransport, ClawModelPlanningTransport {
    private let lock = NSLock()
    private var count = 0
    var calls: Int { lock.withLock { count } }
    private func record() { lock.withLock { count += 1 } }
    func response(for request: ClawModelPlanningWireRequest) async throws -> Data {
        record(); throw ClawModelPlanningError.transport
    }
    func probeTransport(request: ClawGatewayLiveRequest, timeoutNanoseconds: UInt64) async throws -> ClawGatewayTransportProbeResult {
        record(); throw ClawGatewayTransportProbeError.connectionFailed
    }
    func requestReadiness(request: ClawGatewayReadinessTransportRequest, timeoutNanoseconds: UInt64) async throws -> ClawGatewayReadinessTransportResult {
        record(); throw ClawGatewayReadinessTransportError.connectionFailed
    }
    func streamEvents(request: ClawGatewayLiveRequest, envelopeJSON: String, sessionID: UUID, taskID: UUID) -> AsyncThrowingStream<ClawGatewayWireEvent, Error> {
        record()
        return AsyncThrowingStream { $0.finish(throwing: URLError(.cannotConnectToHost)) }
    }
}
