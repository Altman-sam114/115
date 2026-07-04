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

    func testMissionRunSummaryStartsIdle() {
        let store = ClawStore(autoScanLocalArtifacts: false)

        let summary = store.missionRunSummary

        XCTAssertEqual(summary.phaseTitle, ClawAutonomousLoopPhase.idle.title)
        XCTAssertEqual(summary.primaryActionKind, .start)
        XCTAssertTrue(summary.isPrimaryActionEnabled)
        XCTAssertEqual(summary.progressCurrent, 0)
        XCTAssertEqual(summary.progressTotal, 3)
        XCTAssertEqual(summary.artifactCount, 0)
        XCTAssertTrue(summary.statusLine.contains("桌面 Gateway"))
    }

    func testMissionRunSummaryShowsWaitingApprovalState() {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.phoneAgentCommand = "接管我的电脑，打开浏览器搜索竞品信息，整理成表格后发到 Slack"
        store.startAutonomousComputerTakeover()
        let summary = store.missionRunSummary

        XCTAssertEqual(summary.phaseTitle, ClawAutonomousLoopPhase.waitingForUserApproval.title)
        XCTAssertEqual(summary.primaryActionKind, .approveAndContinue)
        XCTAssertTrue(summary.requiresUserApproval)
        XCTAssertGreaterThan(summary.riskScore, 0)
        XCTAssertGreaterThan(summary.approvalCount, 0)
        XCTAssertEqual(summary.artifactCount, 0)
        XCTAssertTrue(summary.stageTrack.contains { $0.title == "审批" && $0.isActive })
    }

    func testMissionRunSummaryShowsNeedsAttentionArtifacts() {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.phoneAgentCommand = "打开浏览器搜索资料并发到 Slack"
        store.startAutonomousComputerTakeover()
        store.approveAndContinueAutonomousLoop()
        let summary = store.missionRunSummary

        XCTAssertEqual(summary.phaseTitle, ClawAutonomousLoopPhase.needsAttention.title)
        XCTAssertEqual(summary.primaryActionKind, .continueAfterReview)
        XCTAssertTrue(summary.requiresUserApproval)
        XCTAssertGreaterThan(summary.succeededCount, 0)
        XCTAssertGreaterThan(summary.artifactCount, 0)
        XCTAssertTrue(summary.artifactKinds.contains(.browserTrace))
        XCTAssertTrue(summary.artifactKinds.contains(.screenshot))
        XCTAssertTrue(summary.artifactKinds.contains(.auditLog))
        XCTAssertTrue(summary.statusLine.contains("待确认"))
    }

    func testMissionRunSummaryDerivesGatewayCapabilityReview() throws {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.phoneAgentCommand = "打开浏览器搜索资料并发到 Slack"
        store.startAutonomousComputerTakeover()
        store.approveAndContinueAutonomousLoop()
        let review = try XCTUnwrap(store.missionRunSummary.gatewayCapabilityReview)

        XCTAssertEqual(review.snapshotCount, 1)
        XCTAssertTrue(review.hasMetadata)
        XCTAssertEqual(review.latestTitle, "gateway-capability-snapshot.json")
        XCTAssertEqual(review.workspaceState, "workspace-only")
        XCTAssertEqual(review.shellState, "dry-run")
        XCTAssertEqual(review.browserControlState, "dry-run")
        XCTAssertEqual(review.browserNetworkState, "disabled")
        XCTAssertEqual(review.desktopControlState, "dry-run")
        XCTAssertEqual(review.platform, "simulated")
        XCTAssertTrue(review.safetyFlags.contains("raw-token-omitted"))
        XCTAssertTrue(review.allowedActionKinds.contains("controlBrowser"))
        XCTAssertTrue(review.compactStatus.contains("Gateway simulated"))
        XCTAssertTrue(review.isRedacted)
    }

    func testMissionRunSummaryDerivesAgentTraceReview() throws {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.phoneAgentCommand = "打开浏览器搜索资料并发到 Slack"
        store.startAutonomousComputerTakeover()
        store.approveAndContinueAutonomousLoop()
        let review = try XCTUnwrap(store.missionRunSummary.agentTraceReview)

        XCTAssertTrue(review.hasMetadata)
        XCTAssertEqual(review.readinessScore, 72)
        XCTAssertEqual(review.readinessCanContinue, true)
        XCTAssertTrue(review.missingSignals.contains("messageDraft"))
        XCTAssertEqual(review.selectedNextActionKind, "composeMessage")
        XCTAssertEqual(review.selectedNextActionRequiresApproval, true)
        XCTAssertTrue(review.riskTags.contains("final-submit-gate"))
        XCTAssertEqual(review.stopReason, "final-submit")
        XCTAssertTrue(review.isRedacted)
        XCTAssertTrue(review.compactStatus.contains("72/100"))
        XCTAssertTrue(review.compactStatus.contains("composeMessage"))
        XCTAssertTrue(review.compactStatus.contains("final-submit"))
    }

    func testMissionRunSummaryShowsCompletedRetryState() {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.phoneAgentCommand = "在项目目录运行测试，失败时导出日志文件"
        store.startAutonomousComputerTakeover()
        store.approveAndContinueAutonomousLoop()
        XCTAssertEqual(store.missionRunSummary.phaseTitle, ClawAutonomousLoopPhase.needsAttention.title)
        XCTAssertGreaterThan(store.missionRunSummary.retryableCount, 0)

        store.continueAutonomousLoopAfterReview()
        let summary = store.missionRunSummary

        XCTAssertEqual(summary.phaseTitle, ClawAutonomousLoopPhase.completed.title)
        XCTAssertEqual(summary.primaryActionKind, .start)
        XCTAssertTrue(summary.isPrimaryActionEnabled)
        XCTAssertEqual(summary.progressCurrent, 2)
        XCTAssertEqual(summary.retryableCount, 0)
        XCTAssertGreaterThan(summary.succeededCount, 0)
        XCTAssertTrue(summary.artifactKinds.contains(.commandOutput))
        XCTAssertTrue(summary.stageTrack.contains { $0.title == "交付" && $0.isActive })
    }

    func testMissionRunSummaryShowsBlockedState() {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.phoneAgentCommand = "读取微信新消息并自动回复客户"
        store.startAutonomousComputerTakeover()
        let summary = store.missionRunSummary

        XCTAssertEqual(summary.phaseTitle, ClawAutonomousLoopPhase.blocked.title)
        XCTAssertEqual(summary.primaryActionKind, .inspectBlocked)
        XCTAssertFalse(summary.isPrimaryActionEnabled)
        XCTAssertGreaterThan(summary.blockedCount, 0)
        XCTAssertTrue(summary.statusLine.contains("安全策略"))
        XCTAssertTrue(summary.stageTrack.contains { $0.isBlocked })
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

    func testClawGatewayArtifactDecodesLegacyJSONWithoutMetadata() throws {
        let json = """
        {
          "id": "\(UUID())",
          "kind": "agentTrace",
          "title": "legacy-agent-loop.json",
          "reference": "file:///tmp/legacy-agent-loop.json",
          "isRedacted": true
        }
        """

        let artifact = try JSONDecoder().decode(ClawGatewayArtifact.self, from: Data(json.utf8))

        XCTAssertEqual(artifact.kind, .agentTrace)
        XCTAssertNil(artifact.metadata)
    }

    func testClawGatewaySessionDecodesLegacyJSONWithoutSessionArtifacts() throws {
        let json = """
        {
          "id": "\(UUID())",
          "taskID": "\(UUID())",
          "command": "legacy",
          "channel": "test",
          "workspace": "~/ClawWorkspace",
          "status": "completed",
          "results": [],
          "auditTrail": [],
          "createdAt": 0,
          "updatedAt": 0
        }
        """

        let session = try JSONDecoder().decode(ClawGatewaySession.self, from: Data(json.utf8))

        XCTAssertTrue(session.sessionArtifacts.isEmpty)
        XCTAssertEqual(session.artifactCount, 0)
        XCTAssertTrue(session.allArtifacts.isEmpty)
    }

    func testAgentTraceReviewFallsBackWhenMetadataIsMissing() throws {
        let actionID = UUID()
        let artifact = ClawGatewayArtifact(
            kind: .agentTrace,
            title: "legacy-agent-loop.json",
            reference: "file:///tmp/legacy-agent-loop.json",
            isRedacted: true
        )
        let session = ClawGatewaySession(
            taskID: UUID(),
            command: "legacy",
            channel: "test",
            workspace: "/tmp",
            status: .completed,
            results: [
                ClawGatewayActionResult(
                    actionID: actionID,
                    actionKind: .runAgentLoop,
                    actionTitle: "Run agent loop",
                    status: .succeeded,
                    summary: "legacy trace",
                    artifacts: [artifact]
                )
            ],
            auditTrail: []
        )

        let review = try XCTUnwrap(ClawAgentTraceReviewSummary.latest(from: session))

        XCTAssertEqual(review.traceCount, 1)
        XCTAssertFalse(review.hasMetadata)
        XCTAssertNil(review.readinessScore)
        XCTAssertEqual(review.latestTitle, "legacy-agent-loop.json")
        XCTAssertTrue(review.isRedacted)
        XCTAssertTrue(review.compactStatus.contains("metadata"))
    }

    func testGatewayCapabilityReviewParsesMetadataAndFallsBack() throws {
        let artifact = ClawGatewayArtifact(
            kind: .auditLog,
            title: "gateway-capability-snapshot.json",
            reference: "file:///tmp/gateway-capability-snapshot.json",
            isRedacted: true,
            metadata: [
                "snapshotKind": "gatewayCapability",
                "tokenConfigured": "true",
                "tokenRequired": "true",
                "tokenFingerprint": "sha256:abcdef123456",
                "allowedActionKinds": "controlBrowser,manageFiles,runAgentLoop",
                "workspaceState": "workspace-only",
                "shellState": "dry-run",
                "browserControlState": "real",
                "browserNetworkState": "disabled",
                "screenCaptureState": "dry-run",
                "windowMetadataState": "dry-run",
                "desktopControlState": "unavailable",
                "safetyFlags": "allowlists-enforced,workspace-only,raw-token-omitted,final-submit-gated",
                "platform": "darwin"
            ]
        )
        let review = try XCTUnwrap(ClawGatewayCapabilityReviewSummary.latest(from: [artifact]))

        XCTAssertEqual(review.snapshotCount, 1)
        XCTAssertTrue(review.hasMetadata)
        XCTAssertEqual(review.tokenConfigured, true)
        XCTAssertEqual(review.tokenRequired, true)
        XCTAssertEqual(review.tokenFingerprint, "sha256:abcdef123456")
        XCTAssertEqual(review.allowedActionKinds, ["controlBrowser", "manageFiles", "runAgentLoop"])
        XCTAssertEqual(review.workspaceState, "workspace-only")
        XCTAssertEqual(review.browserControlState, "real")
        XCTAssertEqual(review.desktopControlState, "unavailable")
        XCTAssertTrue(review.safetyFlags.contains("final-submit-gated"))
        XCTAssertTrue(review.compactStatus.contains("sha256:abcdef123456"))

        let legacyArtifact = ClawGatewayArtifact(
            kind: .auditLog,
            title: "gateway-capability-snapshot.json",
            reference: "file:///tmp/legacy-gateway-capability-snapshot.json",
            isRedacted: true
        )
        let legacyReview = try XCTUnwrap(ClawGatewayCapabilityReviewSummary.latest(from: [legacyArtifact]))
        XCTAssertFalse(legacyReview.hasMetadata)
        XCTAssertTrue(legacyReview.compactStatus.contains("metadata"))
    }

    func testGatewayEventReducerStoresSessionLevelArtifactsWithoutFakeResult() {
        let taskID = UUID()
        let sessionID = UUID()
        let session = ClawGatewaySession(
            id: sessionID,
            taskID: taskID,
            command: "capability",
            channel: "test",
            workspace: "~/ClawWorkspace",
            status: .running,
            results: [],
            auditTrail: []
        )
        let capabilityArtifact = ClawGatewayArtifact(
            kind: .auditLog,
            title: "gateway-capability-snapshot.json",
            reference: "file:///tmp/gateway-capability-snapshot.json",
            isRedacted: true,
            metadata: ["snapshotKind": "gatewayCapability"]
        )
        let sessionArtifactEvent = ClawGatewayEvent(
            sessionID: sessionID,
            taskID: taskID,
            sequence: 2,
            kind: .artifactStored,
            summary: "Stored Gateway capability snapshot audit artifact",
            artifacts: [capabilityArtifact]
        )

        let reduced = ClawGatewayEventStream.apply(event: sessionArtifactEvent, to: session)

        XCTAssertEqual(reduced.sessionArtifacts.count, 1)
        XCTAssertEqual(reduced.artifactCount, 1)
        XCTAssertTrue(reduced.results.isEmpty)
        XCTAssertTrue(reduced.auditTrail.contains { $0.contains("session-level") })

        let actionID = UUID()
        let actionArtifact = ClawGatewayArtifact(
            kind: .browserTrace,
            title: "browser-trace.json",
            reference: "browserTrace://browser-trace.json",
            isRedacted: false
        )
        let actionArtifactEvent = ClawGatewayEvent(
            sessionID: sessionID,
            taskID: taskID,
            sequence: 3,
            kind: .artifactStored,
            actionID: actionID,
            actionKind: .controlBrowser,
            actionTitle: "控制浏览器",
            resultStatus: .running,
            summary: "Stored action artifact",
            artifacts: [actionArtifact]
        )

        let actionReduced = ClawGatewayEventStream.apply(event: actionArtifactEvent, to: reduced)

        XCTAssertEqual(actionReduced.sessionArtifacts.count, 1)
        XCTAssertEqual(actionReduced.results.count, 1)
        XCTAssertEqual(actionReduced.results[0].artifacts.first?.kind, .browserTrace)
        XCTAssertEqual(actionReduced.artifactCount, 2)
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
        XCTAssertTrue(store.gatewayLiveHealthSummary.hasFallback)
        XCTAssertFalse(store.gatewayLiveHealthSummary.canAttemptLive)
        XCTAssertFalse(store.gatewayLiveHealthSummary.detailLine.contains("Authorization"))
    }

    func testLiveGatewayHealthSummarySanitizesEndpoint() throws {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.setGateway(url: "ws://user:secret@127.0.0.1:18789/live?token=raw#frag", token: "paired-secret")
        store.phoneAgentCommand = "打开浏览器搜索资料"
        store.generatePhoneAgentPlan()
        store.queueClawMobileTaskFromCurrentPlan()
        let task = try XCTUnwrap(store.clawMobileTasks.first)
        let request = ClawGatewayLiveClient.makeRequest(
            task: task,
            profile: store.clawGatewayProfile,
            envelopeJSON: store.lastClawMobileEnvelope,
            rawToken: store.gatewayToken
        )
        let summary = ClawGatewayLiveHealthSummary.make(
            request: request,
            connectionState: .awaitingGateway,
            events: [],
            latestSession: nil
        )

        XCTAssertEqual(summary.endpoint, "ws://127.0.0.1:18789/live")
        XCTAssertFalse(summary.endpoint.contains("user"))
        XCTAssertFalse(summary.endpoint.contains("secret"))
        XCTAssertFalse(summary.endpoint.contains("token=raw"))
        XCTAssertEqual(summary.tokenFingerprint, store.clawGatewayProfile.tokenFingerprint)
    }

    func testLiveGatewayProgressKeepsStreamingState() {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.gatewayDispatchMode = .liveGateway
        store.setGateway(url: "ws://127.0.0.1:18789", token: "paired-secret")
        store.phoneAgentCommand = "打开浏览器搜索资料"
        store.generatePhoneAgentPlan()
        store.queueClawMobileTaskFromCurrentPlan()
        store.approveLatestClawMobileTask()
        store.sendLatestClawMobileTask()

        let sessionID = store.clawGatewaySessions[0].id
        let taskID = store.clawGatewaySessions[0].taskID
        store.ingestGatewayEvents([
            ClawGatewayEvent(
                sessionID: sessionID,
                taskID: taskID,
                sequence: 2,
                kind: .gatewayConnected,
                summary: "Gateway accepted task from Claw Controller"
            )
        ])

        XCTAssertEqual(store.gatewayConnectionState, .streaming)
        XCTAssertTrue(store.gatewayLiveHealthSummary.hasGatewayAck)
        XCTAssertEqual(store.gatewayLiveHealthSummary.latestEventKind, .gatewayConnected)
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
        XCTAssertTrue(store.gatewayLiveHealthSummary.isCompleted)
        XCTAssertGreaterThan(store.gatewayLiveHealthSummary.eventCount, 0)
        XCTAssertEqual(store.gatewayLiveHealthSummary.latestEventKind, .sessionCompleted)
        XCTAssertTrue(store.gatewayEvents.contains { $0.kind == .gatewayConnected })
        XCTAssertTrue(store.gatewayEvents.contains { $0.kind == .artifactStored })
        XCTAssertEqual(store.clawGatewaySessions[0].status, .completed)
        XCTAssertTrue(store.clawGatewaySessions[0].results.contains { result in
            result.actionKind == .controlBrowser &&
            result.status == .succeeded &&
            result.artifacts.contains { $0.kind == .browserTrace }
        })
    }

    func testLiveGatewayReconnectDiagnosticsCompleteAfterRetry() async {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.setGateway(url: "ws://127.0.0.1:18789", token: "paired-secret")
        store.phoneAgentCommand = "打开浏览器搜索资料"
        store.generatePhoneAgentPlan()
        store.queueClawMobileTaskFromCurrentPlan()
        store.approveLatestClawMobileTask()

        await store.sendLatestClawMobileTaskOverLiveGateway(transport: ReconnectingClawGatewayTransport())

        XCTAssertEqual(store.gatewayConnectionState, .completed)
        XCTAssertTrue(store.gatewayLiveHealthSummary.isCompleted)
        XCTAssertFalse(store.gatewayLiveHealthSummary.hasError)
        XCTAssertEqual(store.gatewayLiveHealthSummary.transportAttemptCount, 2)
        XCTAssertEqual(store.gatewayLiveHealthSummary.reconnectCount, 1)
        XCTAssertTrue(store.gatewayLiveHealthSummary.hasReconnectAttempt)
        XCTAssertEqual(store.gatewayLiveHealthSummary.lastPingSucceeded, true)
        XCTAssertEqual(store.gatewayLiveHealthSummary.lastTransportErrorSummary, "network_lost")
        XCTAssertFalse(store.gatewayLiveHealthSummary.detailLine.contains("Authorization"))
    }

    func testLiveGatewayTransportDiagnosticsRedactSensitiveFragments() {
        let taskID = UUID()
        let sessionID = UUID()
        let rawEndpoint = "ws://user:secret@127.0.0.1:18789/live?token=raw"
        let safeEndpoint = ClawGatewayLiveRequest.safeEndpointDisplay(rawEndpoint)
        let sensitiveSummary = """
        Live Gateway WebSocket 将重连。 attempt=2 reconnect=1 ping=failed \
        transportError=headers={Authorization: Bearer paired-secret} \
        password:open-sesame secret=raw-secret token=raw-token \
        file:///Users/a114514/Desktop/codex/aiclaw/private.txt workspace=/private/tmp/claw-work
        """
        let summary = ClawGatewayLiveHealthSummary.make(
            request: ClawGatewayLiveRequest(
                endpoint: rawEndpoint,
                tokenFingerprint: "sha256:abc123",
                headers: ["Authorization": "Bearer paired-secret"],
                bodyBytes: 128,
                taskID: taskID,
                command: "打开浏览器搜索资料",
                actionCount: 1,
                canAttemptLive: true,
                preflightMessage: "Live Gateway request ready"
            ),
            connectionState: .streaming,
            events: [
                ClawGatewayEvent(
                    sessionID: sessionID,
                    taskID: taskID,
                    sequence: 2,
                    kind: .gatewayConnected,
                    summary: sensitiveSummary
                )
            ],
            latestSession: nil
        )

        XCTAssertEqual(summary.endpoint, safeEndpoint)
        XCTAssertEqual(summary.transportAttemptCount, 2)
        XCTAssertEqual(summary.reconnectCount, 1)
        XCTAssertEqual(summary.lastPingSucceeded, false)
        XCTAssertFalse(summary.detailLine.contains("paired-secret"))
        XCTAssertFalse(summary.latestEventSummary?.contains("paired-secret") ?? true)
        XCTAssertFalse(summary.lastTransportErrorSummary?.contains("paired-secret") ?? true)
        XCTAssertFalse(summary.latestEventSummary?.contains("Authorization: Bearer") ?? true)
        XCTAssertFalse(summary.latestEventSummary?.contains("open-sesame") ?? true)
        XCTAssertFalse(summary.latestEventSummary?.contains("raw-secret") ?? true)
        XCTAssertFalse(summary.latestEventSummary?.contains("raw-token") ?? true)
        XCTAssertFalse(summary.latestEventSummary?.contains("/Users/a114514") ?? true)
        XCTAssertFalse(summary.latestEventSummary?.contains("/private/tmp") ?? true)
    }

    func testLiveGatewayPingFailureCanContinueWithoutFallback() async {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.setGateway(url: "ws://127.0.0.1:18789", token: "paired-secret")
        store.phoneAgentCommand = "打开浏览器搜索资料"
        store.generatePhoneAgentPlan()
        store.queueClawMobileTaskFromCurrentPlan()
        store.approveLatestClawMobileTask()

        await store.sendLatestClawMobileTaskOverLiveGateway(transport: PingFailedClawGatewayTransport())

        XCTAssertEqual(store.gatewayConnectionState, .completed)
        XCTAssertFalse(store.gatewayLiveHealthSummary.hasFallback)
        XCTAssertEqual(store.gatewayLiveHealthSummary.transportAttemptCount, 1)
        XCTAssertEqual(store.gatewayLiveHealthSummary.reconnectCount, 0)
        XCTAssertEqual(store.gatewayLiveHealthSummary.lastPingSucceeded, false)
    }

    func testLiveGatewayTransportErrorFallsBackWithHealthSummary() async {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.setGateway(url: "ws://127.0.0.1:18789", token: "paired-secret")
        store.phoneAgentCommand = "打开浏览器搜索资料"
        store.generatePhoneAgentPlan()
        store.queueClawMobileTaskFromCurrentPlan()
        store.approveLatestClawMobileTask()

        await store.sendLatestClawMobileTaskOverLiveGateway(transport: SensitiveFailingClawGatewayTransport())

        XCTAssertEqual(store.gatewayConnectionState, .completed)
        XCTAssertTrue(store.gatewayLiveHealthSummary.hasFallback)
        XCTAssertTrue(store.gatewayLiveHealthSummary.hasError)
        XCTAssertNotNil(store.gatewayLiveHealthSummary.lastTransportErrorSummary)
        for sensitiveFragment in [
            "paired-secret",
            "Authorization: Bearer",
            "open-sesame",
            "raw-secret",
            "raw-token",
            "/Users/a114514",
            "/private/tmp"
        ] {
            XCTAssertFalse(store.gatewayLiveHealthSummary.detailLine.contains(sensitiveFragment))
            XCTAssertFalse(store.gatewayLiveHealthSummary.latestEventSummary?.contains(sensitiveFragment) ?? true)
            XCTAssertFalse(store.gatewayLiveHealthSummary.lastTransportErrorSummary?.contains(sensitiveFragment) ?? true)
        }
    }

    func testLiveGatewayHealthSummaryFallsBackWhenNoRequestExists() {
        let store = ClawStore(autoScanLocalArtifacts: false)

        let summary = store.gatewayLiveHealthSummary

        XCTAssertEqual(summary.endpoint, "未配置")
        XCTAssertEqual(summary.connectionState, .idle)
        XCTAssertFalse(summary.canAttemptLive)
        XCTAssertEqual(summary.eventCount, 0)
        XCTAssertTrue(summary.compactStatus.contains("尚未准备"))
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

private struct ReconnectingClawGatewayTransport: ClawGatewayTransport {
    func streamEvents(
        request: ClawGatewayLiveRequest,
        envelopeJSON: String,
        sessionID: UUID,
        taskID: UUID
    ) -> AsyncThrowingStream<ClawGatewayEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(ClawGatewayLiveClient.liveTransportProgressEvent(
                taskID: taskID,
                sessionID: sessionID,
                sequence: 2,
                attempt: 1,
                reconnectCount: 0,
                pingStatus: "failed",
                transportErrorSummary: "network_lost",
                willRetry: true
            ))
            continuation.yield(ClawGatewayLiveClient.liveTransportProgressEvent(
                taskID: taskID,
                sessionID: sessionID,
                sequence: 3,
                attempt: 2,
                reconnectCount: 1,
                pingStatus: "ok"
            ))
            yieldSimulatedEvents(envelopeJSON: envelopeJSON, sessionID: sessionID, startingSequence: 4, continuation: continuation)
            continuation.finish()
        }
    }
}

private struct PingFailedClawGatewayTransport: ClawGatewayTransport {
    func streamEvents(
        request: ClawGatewayLiveRequest,
        envelopeJSON: String,
        sessionID: UUID,
        taskID: UUID
    ) -> AsyncThrowingStream<ClawGatewayEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(ClawGatewayLiveClient.liveTransportProgressEvent(
                taskID: taskID,
                sessionID: sessionID,
                sequence: 2,
                attempt: 1,
                reconnectCount: 0,
                pingStatus: "failed"
            ))
            yieldSimulatedEvents(envelopeJSON: envelopeJSON, sessionID: sessionID, startingSequence: 3, continuation: continuation)
            continuation.finish()
        }
    }
}

private struct SensitiveFailingClawGatewayTransport: ClawGatewayTransport {
    func streamEvents(
        request: ClawGatewayLiveRequest,
        envelopeJSON: String,
        sessionID: UUID,
        taskID: UUID
    ) -> AsyncThrowingStream<ClawGatewayEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: ClawGatewayTransportError.invalidEndpoint(
                "headers={Authorization: Bearer paired-secret} password:open-sesame secret=raw-secret token=raw-token file:///Users/a114514/private.txt workspace=/private/tmp/claw-work"
            ))
        }
    }
}

private func yieldSimulatedEvents(
    envelopeJSON: String,
    sessionID: UUID,
    startingSequence: Int,
    continuation: AsyncThrowingStream<ClawGatewayEvent, Error>.Continuation
) {
    let decoder = JSONDecoder.clawGateway
    guard let data = envelopeJSON.data(using: .utf8),
          let envelope = try? decoder.decode(ClawMobileEnvelope.self, from: data) else {
        return
    }
    let events = ClawGatewayEventStream.simulatedEvents(
        task: envelope.task,
        profile: ClawStore.defaultClawGatewayProfile,
        sessionID: sessionID,
        startingSequence: startingSequence
    )
    for event in events {
        continuation.yield(event)
    }
}
