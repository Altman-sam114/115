import XCTest
@testable import Claw

@MainActor
final class ClawTests: XCTestCase {
    func testDefaultModelIsPlaceholderAndDoesNotDownload() {
        let store = ClawStore(autoScanLocalArtifacts: false)

        XCTAssertEqual(store.model.name, "Claw Local Agent 1.5B")
        XCTAssertEqual(store.model.installState, .placeholder)
        XCTAssertEqual(store.model.artifactManifest.allowsNetworkDownload, false)
        XCTAssertTrue(store.model.artifactManifest.requiredFiles.contains("claw-local-agent-q4.mlmodelc"))
        XCTAssertEqual(store.validation.availability, .missing)
    }

    func testArtifactValidatorKeepsUntrustedFilesStaged() {
        let model = ClawStore.defaultModel
        let validation = LocalArtifactValidator.validate(
            manifest: model.artifactManifest,
            presentFiles: Set(model.artifactManifest.requiredFiles)
        )

        XCTAssertEqual(validation.availability, .staged)
        XCTAssertTrue(validation.hasRequiredFiles)
        XCTAssertFalse(validation.hasConcreteExpectedHash)
        XCTAssertFalse(validation.canRunRealWeights)
    }

    func testArtifactValidatorVerifiesConcreteHash() {
        let expectedHash = String(repeating: "a", count: 64)
        let manifest = ModelArtifactManifest(
            modelFileName: "gemma-test.mlmodelc",
            tokenizerFileName: "gemma-tokenizer.model",
            fileFormat: "Core ML compiled package",
            storageDirectory: "Application Support/ClawLocalModels",
            expectedSHA256: expectedHash,
            allowsNetworkDownload: false,
            importInstruction: "manual"
        )

        let validation = LocalArtifactValidator.validate(
            manifest: manifest,
            presentFiles: Set(manifest.requiredFiles),
            observedSHA256: expectedHash
        )

        XCTAssertEqual(validation.availability, .verified)
        XCTAssertTrue(validation.canRunRealWeights)
        XCTAssertFalse(validation.networkDownloadAllowed)
    }

    func testSkillFilteringAndSelection() {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.selectedCategory = .browser

        XCTAssertFalse(store.visibleSkills.isEmpty)
        XCTAssertTrue(store.visibleSkills.allSatisfy { $0.category == .browser })

        let skill = store.visibleSkills[0]
        store.selectSkill(skill)

        XCTAssertEqual(store.selectedSkill?.id, skill.id)
        XCTAssertFalse(store.query.isEmpty)
    }

    func testChatSubmitUsesSimulationRuntime() {
        let store = ClawStore(autoScanLocalArtifacts: false)
        let initialCount = store.messages.count

        store.query = "打开浏览器搜索竞品价格并整理表格"
        store.submitCurrentQuery()

        XCTAssertEqual(store.messages.count, initialCount + 2)
        XCTAssertEqual(store.messages[initialCount].role, .user)
        XCTAssertEqual(store.messages[initialCount + 1].role, .assistant)
        XCTAssertTrue(store.messages[initialCount + 1].text.contains("SIM_ONLY"))
        XCTAssertTrue(store.messages[initialCount + 1].text.contains("不会下载"))
    }

    func testAutomationPayloadCanTargetClawGateway() throws {
        let store = ClawStore(autoScanLocalArtifacts: false)
        let claw = try XCTUnwrap(store.automationTargets.first { $0.channel == .clawGateway })

        store.setGateway(url: "ws://10.0.0.2:18789", token: "secret")
        store.draftAutomationPayload(for: claw)

        XCTAssertTrue(store.lastAutomationDraft.contains("Claw 网关"))
        XCTAssertTrue(store.lastAutomationDraft.contains("ws://10.0.0.2:18789"))
        XCTAssertTrue(store.lastAutomationDraft.contains("payload"))
    }

    func testPhoneAgentCapabilitiesEncodeIOSBoundaries() throws {
        let store = ClawStore(autoScanLocalArtifacts: false)

        XCTAssertTrue(store.phoneAgentCapabilities.contains { $0.surface == .appIntents })
        XCTAssertTrue(store.phoneAgentCapabilities.contains { $0.surface == .siriKit })
        XCTAssertTrue(store.phoneAgentCapabilities.contains { $0.surface == .composeController && $0.runMode == .needsUserConfirmation })
        XCTAssertTrue(store.phoneAgentCapabilities.contains { $0.surface == .unavailable && $0.runMode == .blockedByIOS })

        let messageReader = try XCTUnwrap(store.phoneAgentCapabilities.first { $0.title == "读取其他 App 消息" })
        XCTAssertFalse(messageReader.canRead)
        XCTAssertFalse(messageReader.canWrite)
        XCTAssertEqual(messageReader.permissionState, .unavailable)
    }

    func testPhoneAgentMessagePlanRequiresConfirmation() {
        let plan = PhoneAgentPlanner.makePlan(
            command: "接管我的电脑，打开浏览器搜索竞品信息，整理成表格后发到 Slack",
            capabilities: ClawStore.defaultPhoneAgentCapabilities
        )

        XCTAssertTrue(plan.steps.contains { $0.title == "控制桌面浏览器" && $0.runMode == .gatewayOnly })
        XCTAssertTrue(plan.steps.contains { $0.title == "观察桌面状态" && $0.runMode == .gatewayOnly })
        XCTAssertTrue(plan.steps.contains { $0.title == "提取结构化结果" && $0.runMode == .gatewayOnly })
        XCTAssertTrue(plan.steps.contains { $0.title == "操作桌面应用" && $0.runMode == .gatewayOnly })
        XCTAssertTrue(plan.steps.contains { $0.title == "生成消息草稿" && $0.requiresUserConfirmation })
        XCTAssertGreaterThan(plan.executableStepCount, 0)
    }

    func testPhoneAgentBlocksReadingThirdPartyMessages() {
        let plan = PhoneAgentPlanner.makePlan(
            command: "读取微信新消息并自动回复客户",
            capabilities: ClawStore.defaultPhoneAgentCapabilities
        )

        XCTAssertTrue(plan.steps.contains { $0.surface == .unavailable && $0.runMode == .blockedByIOS })
        XCTAssertTrue(plan.steps.contains { $0.surface == .clawGateway && $0.runMode == .gatewayOnly })
        XCTAssertFalse(plan.blockedNotes.isEmpty)
    }

    func testPhoneAgentVoicePlanUsesSpeechPermission() {
        let plan = PhoneAgentPlanner.makePlan(
            command: "像 Siri 一样听我语音安排今天的电脑任务",
            capabilities: ClawStore.defaultPhoneAgentCapabilities
        )

        XCTAssertTrue(plan.steps.contains { $0.title == "采集语音指令" && $0.surface == .siriKit })
        XCTAssertTrue(plan.steps.contains { $0.title == "形成电脑接管计划" || $0.surface == .clawGateway })
    }

    func testPhoneAgentExecutionLogShowsGates() {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.phoneAgentCommand = "自动发送短信给客户，不要确认"
        store.generatePhoneAgentPlan()
        store.simulatePhoneAgentExecution()

        XCTAssertTrue(store.phoneAgentExecutionLog.contains("WAIT_CONFIRM"))
        XCTAssertTrue(store.phoneAgentPlan.blockedNotes.contains { $0.contains("不能由普通 App 静默完成") })
    }

    func testClawMobileTaskBuildsFromPhoneAgentPlan() {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.phoneAgentCommand = "接管我的电脑，打开浏览器搜索竞品信息，整理成表格后发到 Slack"
        store.generatePhoneAgentPlan()
        store.queueClawMobileTaskFromCurrentPlan()

        let task = store.clawMobileTasks[0]
        XCTAssertFalse(task.actions.isEmpty)
        XCTAssertTrue(task.actions.contains { $0.kind == .observeScreen && $0.toolArguments["includeAccessibilityTree"] == "true" })
        XCTAssertTrue(task.actions.contains { $0.kind == .controlBrowser && $0.approval == .gatewayApproval })
        XCTAssertTrue(task.actions.contains { $0.kind == .controlBrowser && $0.toolArguments["browserApp"] == "Safari" })
        XCTAssertTrue(task.actions.contains { $0.kind == .controlBrowser && $0.toolArguments["openInBrowser"] == "true" })
        XCTAssertTrue(task.actions.contains { $0.kind == .controlBrowser && $0.toolArguments["searchQuery"]?.contains("接管我的电脑") == true })
        XCTAssertTrue(task.actions.contains { $0.kind == .extractData && $0.toolArguments["outputPath"] == "claw-output/extracted-data.json" })
        XCTAssertTrue(task.actions.contains { $0.kind == .operateDesktopApp && $0.approval == .gatewayApproval })
        XCTAssertTrue(task.actions.contains { $0.kind == .operateDesktopApp && $0.toolArguments["targetApp"] == "Slack" })
        XCTAssertTrue(task.actions.contains { $0.kind == .operateDesktopApp && $0.toolArguments["draftText"]?.contains("Claw prepared result") == true })
        XCTAssertTrue(task.actions.contains { $0.kind == .operateDesktopApp && $0.toolArguments["keySequence"] == "command+k,return" })
        XCTAssertTrue(task.actions.contains { $0.kind == .composeMessage && $0.approval == .userConfirmation })
        XCTAssertGreaterThan(task.riskScore, 0)
        XCTAssertEqual(task.status, .waitingForApproval)
    }

    func testClawComputerTaskUsesObserveActExtractAuditLoop() throws {
        let plan = PhoneAgentPlanner.makePlan(
            command: "接管我的电脑，打开浏览器搜索竞品价格和功能，整理成表格后发到 Slack",
            capabilities: ClawStore.defaultPhoneAgentCapabilities
        )
        let task = ClawMobileBridge.makeTask(
            from: plan,
            profile: ClawStore.defaultClawGatewayProfile,
            selectedSkill: nil,
            documents: ClawStore.defaultDocuments
        )

        let observed = try XCTUnwrap(task.actions.first { $0.kind == .observeScreen })
        XCTAssertEqual(observed.toolArguments["observationGoal"], plan.command)
        XCTAssertEqual(observed.toolArguments["maxCandidateControls"], "20")

        let browser = try XCTUnwrap(task.actions.first { $0.kind == .controlBrowser })
        XCTAssertEqual(browser.toolArguments["browserApp"], "Safari")
        XCTAssertEqual(browser.toolArguments["openInBrowser"], "true")
        XCTAssertEqual(browser.toolArguments["searchQuery"], plan.command)
        XCTAssertEqual(browser.toolArguments["searchURLTemplate"], "https://www.google.com/search?q={query}")

        let extracted = try XCTUnwrap(task.actions.first { $0.kind == .extractData })
        XCTAssertEqual(extracted.approval, .gatewayApproval)
        XCTAssertEqual(extracted.toolArguments["validateCompleteness"], "true")
        XCTAssertTrue(extracted.toolArguments["sourcePriority"]?.contains("accessibilityTree") == true)

        let desktop = try XCTUnwrap(task.actions.first { $0.kind == .operateDesktopApp })
        XCTAssertEqual(desktop.toolArguments["targetApp"], "Slack")
        XCTAssertEqual(desktop.toolArguments["finalSubmitRequiresApproval"], "true")
        XCTAssertTrue(desktop.toolArguments["draftText"]?.contains(plan.command) == true)
        XCTAssertEqual(desktop.toolArguments["keySequence"], "command+k,return")

        let envelope = ClawMobileBridge.makeEnvelope(task: task, profile: ClawStore.defaultClawGatewayProfile)
        XCTAssertTrue(envelope.auditRequired)
        XCTAssertTrue(envelope.approvalSummary.contains("userOrGatewayApprovals"))
    }

    func testClawMobileSensitiveAutomaticActionRequiresApproval() {
        let plan = PhoneAgentPlanner.makePlan(
            command: "把任务结果发给同事",
            capabilities: ClawStore.defaultPhoneAgentCapabilities
        )
        var profile = ClawStore.defaultClawGatewayProfile
        profile.requiresApprovalForSensitiveData = true

        let task = ClawMobileBridge.makeTask(
            from: plan,
            profile: profile,
            selectedSkill: nil,
            documents: ClawStore.defaultDocuments
        )

        XCTAssertTrue(task.actions.contains { $0.kind == .readContacts && $0.approval == .userConfirmation })
        XCTAssertEqual(task.status, .waitingForApproval)
    }

    func testClawMobileGatewayActionWhitelistBlocksDisallowedActions() {
        let plan = PhoneAgentPlanner.makePlan(
            command: "把任务结果发给同事",
            capabilities: ClawStore.defaultPhoneAgentCapabilities
        )
        var profile = ClawStore.defaultClawGatewayProfile
        profile.allowedActionKinds.removeAll { $0 == .composeMessage }

        let task = ClawMobileBridge.makeTask(
            from: plan,
            profile: profile,
            selectedSkill: nil,
            documents: ClawStore.defaultDocuments
        )

        XCTAssertEqual(task.status, .blocked)
        XCTAssertTrue(task.actions.contains { action in
            action.kind == .composeMessage &&
            action.approval == .blocked &&
            action.instruction.contains("网关动作白名单不允许")
        })
    }

    func testClawMobileEnvelopeRedactsToken() throws {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.setGateway(url: "ws://10.0.0.9:18789", token: "super-secret-token")
        store.queueClawMobileTaskFromCurrentPlan()

        XCTAssertFalse(store.lastClawMobileEnvelope.contains("super-secret-token"))
        XCTAssertTrue(store.lastClawMobileEnvelope.contains("sha256:"))
        XCTAssertTrue(store.lastClawMobileEnvelope.contains("claw.computer.control.v1"))

        let data = try XCTUnwrap(store.lastClawMobileEnvelope.data(using: .utf8))
        let envelope = try JSONDecoder().decode(ClawMobileEnvelope.self, from: data)
        XCTAssertEqual(envelope.gateway.endpoint, "ws://10.0.0.9:18789")
        XCTAssertNotEqual(envelope.gateway.tokenFingerprint, "super-secret-token")
        XCTAssertTrue(envelope.auditRequired)
    }

    func testLiveGatewayRequestUsesBearerTokenOutsideEnvelope() throws {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.setGateway(url: "ws://10.0.0.9:18789", token: "super-secret-token")
        store.queueClawMobileTaskFromCurrentPlan()

        let task = try XCTUnwrap(store.clawMobileTasks.first)
        let request = ClawGatewayLiveClient.makeRequest(
            task: task,
            profile: store.clawGatewayProfile,
            envelopeJSON: store.lastClawMobileEnvelope,
            rawToken: store.gatewayToken
        )

        XCTAssertTrue(request.canAttemptLive)
        XCTAssertEqual(request.headers["Authorization"], "Bearer super-secret-token")
        XCTAssertFalse(store.lastClawMobileEnvelope.contains("super-secret-token"))
        XCTAssertEqual(request.headers["X-Claw-Token-Fingerprint"], store.clawGatewayProfile.tokenFingerprint)
    }

    func testClawMobileApprovalAndSendFlow() {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.phoneAgentCommand = "把任务结果发给同事"
        store.generatePhoneAgentPlan()
        store.queueClawMobileTaskFromCurrentPlan()
        XCTAssertEqual(store.clawMobileTasks[0].status, .waitingForApproval)

        store.approveLatestClawMobileTask()
        XCTAssertEqual(store.clawMobileTasks[0].status, .readyToSend)

        store.simulateSendLatestClawMobileTask()
        XCTAssertEqual(store.clawMobileTasks[0].status, .sent)
        XCTAssertFalse(store.clawGatewaySessions.isEmpty)
        XCTAssertTrue(store.clawGatewaySessions[0].artifactCount > 0)
    }

    func testAutonomousLoopStopsAtUserApprovalGate() {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.phoneAgentCommand = "接管我的电脑，打开浏览器搜索竞品信息，整理成表格后发到 Slack"
        store.startAutonomousComputerTakeover()

        XCTAssertEqual(store.autonomousLoop.phase, .waitingForUserApproval)
        XCTAssertTrue(store.autonomousLoop.requiresUserApproval)
        XCTAssertEqual(store.clawMobileTasks[0].status, .waitingForApproval)
        XCTAssertTrue(store.clawGatewaySessions.isEmpty)
        XCTAssertTrue(store.lastClawMobileEnvelope.contains("claw.computer.control.v1"))
        XCTAssertTrue(store.autonomousLoop.checkpoints.contains { $0.contains("loop.waiting_approval") })
    }

    func testAutonomousLoopApprovalDispatchesThroughGatewayEvents() {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.phoneAgentCommand = "打开浏览器搜索资料并发到 Slack"
        store.startAutonomousComputerTakeover()
        store.approveAndContinueAutonomousLoop()

        XCTAssertEqual(store.clawMobileTasks[0].status, .sent)
        XCTAssertEqual(store.autonomousLoop.phase, .needsAttention)
        XCTAssertTrue(store.autonomousLoop.requiresUserApproval)
        XCTAssertFalse(store.clawGatewaySessions.isEmpty)
        XCTAssertTrue(store.gatewayEvents.contains { $0.kind == .sessionCompleted })
        XCTAssertTrue(store.clawGatewaySessions[0].results.contains { $0.status == .waitingForApproval })
    }

    func testAutonomousLoopRetriesGatewayFailuresAfterReview() {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.phoneAgentCommand = "在项目目录运行测试，失败时导出日志文件"
        store.startAutonomousComputerTakeover()
        store.approveAndContinueAutonomousLoop()

        XCTAssertEqual(store.autonomousLoop.phase, .needsAttention)
        XCTAssertTrue(store.clawGatewaySessions[0].retryableCount > 0)

        store.continueAutonomousLoopAfterReview()

        XCTAssertEqual(store.autonomousLoop.phase, .completed)
        XCTAssertEqual(store.autonomousLoop.iteration, 2)
        XCTAssertEqual(store.clawGatewaySessions[0].status, .completed)
        XCTAssertEqual(store.clawGatewaySessions[0].retryableCount, 0)
        XCTAssertTrue(store.autonomousLoop.checkpoints.contains { $0.contains("loop.retry") })
    }

    func testClawComputerTaskIncludesShellAndFileActions() {
        let plan = PhoneAgentPlanner.makePlan(
            command: "在项目目录运行测试，失败时导出日志文件",
            capabilities: ClawStore.defaultPhoneAgentCapabilities
        )
        let task = ClawMobileBridge.makeTask(
            from: plan,
            profile: ClawStore.defaultClawGatewayProfile,
            selectedSkill: nil,
            documents: ClawStore.defaultDocuments
        )

        XCTAssertTrue(task.actions.contains { $0.kind == .runShellCommand && $0.approval == .gatewayApproval })
        XCTAssertTrue(task.actions.contains { $0.kind == .manageFiles && $0.approval == .gatewayApproval })
        XCTAssertTrue(task.actions.contains { $0.kind == .runShellCommand && $0.toolArguments["shellCommand"] == "pwd" })
        XCTAssertTrue(task.actions.contains { $0.kind == .manageFiles && $0.toolArguments["workspaceOnly"] == "true" })
        XCTAssertTrue(task.actions.contains { $0.kind == .manageFiles && $0.toolArguments["writePath"] == "claw-output/summary.txt" })
        XCTAssertEqual(task.status, .waitingForApproval)
    }

    func testClawMobileActionDecodesLegacyEnvelopeWithoutToolArguments() throws {
        let json = """
        {
          "id": "\(UUID())",
          "kind": "controlBrowser",
          "title": "控制浏览器",
          "target": "Desktop Browser",
          "instruction": "open",
          "approval": "gatewayApproval",
          "sourceSurface": "clawGateway",
          "handlesSensitiveData": true,
          "inputPreview": "legacy"
        }
        """

        let action = try JSONDecoder().decode(ClawMobileAction.self, from: Data(json.utf8))

        XCTAssertEqual(action.kind, .controlBrowser)
        XCTAssertEqual(action.toolArguments, [:])
    }

    func testPhoneAgentSurfaceDecodesLegacyAICLawRuntimeValue() throws {
        let data = #""aiclawRuntime""#.data(using: .utf8)!

        let surface = try JSONDecoder().decode(PhoneAgentSurface.self, from: data)

        XCTAssertEqual(surface, .clawRuntime)
    }

    func testGatewaySessionCapturesComputerUseResultsAndRetry() {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.phoneAgentCommand = "在项目目录运行测试，失败时导出日志文件"
        store.generatePhoneAgentPlan()
        store.queueClawMobileTaskFromCurrentPlan()
        store.approveLatestClawMobileTask()
        store.simulateSendLatestClawMobileTask()

        let session = store.clawGatewaySessions[0]
        XCTAssertEqual(session.status, .needsAttention)
        XCTAssertTrue(session.results.contains { $0.actionKind == .runShellCommand && $0.status == .failed && $0.isRetryable })
        XCTAssertTrue(session.results.contains { $0.actionKind == .manageFiles && $0.artifacts.contains { $0.kind == .fileDiff } })
        XCTAssertTrue(store.lastGatewayEvent.contains("retryable"))

        store.retryLatestGatewayFailures()
        XCTAssertEqual(store.clawGatewaySessions[0].status, .completed)
        XCTAssertEqual(store.clawGatewaySessions[0].retryableCount, 0)
        XCTAssertTrue(store.clawGatewaySessions[0].auditTrail.contains { $0.contains("session.retry") })
    }

    func testLiveGatewayModeFallsBackWhenTokenIsMissing() {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.gatewayDispatchMode = .liveGateway
        store.setGateway(url: "ws://127.0.0.1:18789", token: "")
        store.phoneAgentCommand = "打开浏览器搜索资料"
        store.generatePhoneAgentPlan()
        store.queueClawMobileTaskFromCurrentPlan()
        store.approveLatestClawMobileTask()
        store.sendLatestClawMobileTask()

        XCTAssertEqual(store.clawMobileTasks[0].status, .sent)
        XCTAssertEqual(store.gatewayConnectionState, .completed)
        XCTAssertEqual(store.lastGatewayLiveRequest?.canAttemptLive, false)
        XCTAssertTrue(store.gatewayEvents.contains { $0.kind == .fallbackUsed })
        XCTAssertFalse(store.clawGatewaySessions.isEmpty)
        XCTAssertGreaterThan(store.clawGatewaySessions[0].results.count, 0)
    }

    func testLiveGatewayTransportEventsUpdateSession() async {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.setGateway(url: "ws://127.0.0.1:18789", token: "paired-secret")
        store.phoneAgentCommand = "打开浏览器搜索资料"
        store.generatePhoneAgentPlan()
        store.queueClawMobileTaskFromCurrentPlan()
        store.approveLatestClawMobileTask()

        await store.sendLatestClawMobileTaskOverLiveGateway(transport: MockClawGatewayTransport())

        XCTAssertEqual(store.clawMobileTasks[0].status, .sent)
        XCTAssertEqual(store.lastGatewayLiveRequest?.canAttemptLive, true)
        XCTAssertEqual(store.gatewayConnectionState, .completed)
        XCTAssertTrue(store.gatewayEvents.contains { $0.kind == .gatewayConnected })
        XCTAssertTrue(store.gatewayEvents.contains { $0.kind == .artifactStored })
        XCTAssertEqual(store.clawGatewaySessions[0].status, .completed)
        XCTAssertTrue(store.clawGatewaySessions[0].results.contains { result in
            result.actionKind == .controlBrowser &&
            result.status == .succeeded &&
            result.artifacts.contains { $0.kind == .browserTrace }
        })
    }

    func testClawMobileBlockedIOSActionCannotBeApproved() {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.phoneAgentCommand = "读取微信新消息并自动回复客户"
        store.generatePhoneAgentPlan()
        store.queueClawMobileTaskFromCurrentPlan()

        XCTAssertEqual(store.clawMobileTasks[0].status, .blocked)
        XCTAssertTrue(store.clawMobileTasks[0].actions.contains { $0.kind == .blockedUnsupported && $0.approval == .blocked })

        store.approveLatestClawMobileTask()
        XCTAssertEqual(store.clawMobileTasks[0].status, .blocked)
    }
}

private struct MockClawGatewayTransport: ClawGatewayTransport {
    func streamEvents(
        request: ClawGatewayLiveRequest,
        envelopeJSON: String,
        sessionID: UUID,
        taskID: UUID
    ) -> AsyncThrowingStream<ClawGatewayEvent, Error> {
        AsyncThrowingStream { continuation in
            let decoder = JSONDecoder.clawGateway
            guard let data = envelopeJSON.data(using: .utf8),
                  let envelope = try? decoder.decode(ClawMobileEnvelope.self, from: data) else {
                continuation.finish()
                return
            }

            let events = ClawGatewayEventStream.simulatedEvents(
                task: envelope.task,
                profile: ClawStore.defaultClawGatewayProfile,
                sessionID: sessionID,
                startingSequence: 2
            )
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }
}
