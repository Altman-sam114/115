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

    func testMissionRunSummaryDerivesArtifactMetadataReview() throws {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.phoneAgentCommand = "打开浏览器搜索资料并发到 Slack"
        store.startAutonomousComputerTakeover()
        store.approveAndContinueAutonomousLoop()
        let review = try XCTUnwrap(store.missionRunSummary.artifactMetadataReview)

        XCTAssertGreaterThan(review.artifactCount, 0)
        XCTAssertGreaterThan(review.metadataArtifactCount, 0)
        XCTAssertGreaterThan(review.redactedArtifactCount, 0)
        XCTAssertTrue(review.hasMetadata)
        XCTAssertFalse(review.safeMetadataPairs.isEmpty)
        XCTAssertTrue(review.compactStatus.contains("metadata"))
        XCTAssertTrue(review.compactStatus.contains("redacted"))
    }

    func testMissionRunSummaryDerivesExtractionCompletenessReview() throws {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.phoneAgentCommand = "在项目目录运行测试，失败时导出日志文件"
        store.startAutonomousComputerTakeover()
        store.approveAndContinueAutonomousLoop()
        let review = try XCTUnwrap(store.missionRunSummary.gatewayExtractionCompletenessReview)

        XCTAssertEqual(review.extractionCount, 1)
        XCTAssertTrue(review.hasMetadata)
        XCTAssertEqual(review.mode, "artifact-grounded-extraction")
        XCTAssertEqual(review.validateCompleteness, true)
        XCTAssertEqual(review.rowCount, 4)
        XCTAssertEqual(review.completenessStatus, "complete")
        XCTAssertEqual(review.browserTraceCount, 1)
        XCTAssertEqual(review.fileDiffCount, 1)
        XCTAssertEqual(review.commandOutputCount, 1)
        XCTAssertEqual(review.screenObservationCount, 1)
        XCTAssertEqual(review.accessibilityTreeCount, 1)
        XCTAssertTrue(review.sourceArtifactKinds.contains("browserTrace"))
        XCTAssertTrue(review.sourceArtifactKinds.contains("fileDiff"))
        XCTAssertTrue(review.safetyFlags.contains("row-content-omitted"))
        XCTAssertTrue(review.compactStatus.contains("complete"))
        XCTAssertTrue(review.compactStatus.contains("rows 4"))
    }

    func testMissionRunSummaryDerivesBrowserControlReview() throws {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.phoneAgentCommand = "在项目目录运行测试，失败时导出日志文件"
        store.startAutonomousComputerTakeover()
        store.approveAndContinueAutonomousLoop()
        let review = try XCTUnwrap(store.missionRunSummary.gatewayBrowserControlReview)

        XCTAssertGreaterThanOrEqual(review.reviewCount, 2)
        XCTAssertTrue(review.hasMetadata)
        XCTAssertEqual(review.mode, "browser-control-dry-run")
        XCTAssertEqual(review.actionKind, "controlBrowser")
        XCTAssertEqual(review.browserControlPolicy, "dry-run")
        XCTAssertEqual(review.browserControlRequested, true)
        XCTAssertEqual(review.openInBrowser, true)
        XCTAssertEqual(review.targetURLPresent, true)
        XCTAssertEqual(review.searchQueryPresent, true)
        XCTAssertEqual(review.networkFetchAttempted, false)
        XCTAssertEqual(review.networkBlocked, false)
        XCTAssertEqual(review.resultStatus, "succeeded")
        XCTAssertTrue(review.safetyFlags.contains("metadata-only"))
        XCTAssertTrue(review.safetyFlags.contains("url-omitted"))
        XCTAssertTrue(review.safetyFlags.contains("search-query-omitted"))
        XCTAssertTrue(review.safetyFlags.contains("tool-arguments-omitted"))
        XCTAssertTrue(review.compactStatus.contains("policy dry-run"))

        let browserResult = try XCTUnwrap(store.clawGatewaySessions.first?.results.first { $0.actionKind == .controlBrowser })
        let browserReview = try XCTUnwrap(ClawGatewayBrowserControlReviewSummary.latest(from: browserResult.artifacts))
        XCTAssertEqual(browserReview.mode, "browser-control-dry-run")
        XCTAssertEqual(browserReview.browserControlRequested, true)
        XCTAssertEqual(browserReview.executed, false)
        XCTAssertEqual(browserReview.timedOut, false)
        XCTAssertTrue(browserReview.safetyFlags.contains("candidate-labels-omitted"))
    }

    func testMissionRunSummaryDerivesDeliverySafetyReview() throws {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.phoneAgentCommand = "打开浏览器搜索资料，整理结果并发到 Slack"
        store.startAutonomousComputerTakeover()
        store.approveAndContinueAutonomousLoop()
        let review = try XCTUnwrap(store.missionRunSummary.gatewayDeliverySafetyReview)

        XCTAssertGreaterThanOrEqual(review.reviewCount, 2)
        XCTAssertTrue(review.hasMetadata)
        XCTAssertEqual(review.finalSubmitRequiresApproval, true)
        XCTAssertEqual(review.userApprovalRequired, true)
        XCTAssertEqual(review.draftBodyOmitted, true)
        XCTAssertEqual(review.submitBlocked, true)
        XCTAssertTrue(review.safetyFlags.contains("metadata-only"))
        XCTAssertTrue(review.safetyFlags.contains("final-submit-gated"))
        XCTAssertTrue(review.safetyFlags.contains("tool-arguments-omitted"))
        XCTAssertTrue(review.compactStatus.contains("最终提交"))
        XCTAssertTrue(review.compactStatus.contains("正文省略"))

        let desktopResult = try XCTUnwrap(store.clawGatewaySessions.first?.results.first { $0.actionKind == .operateDesktopApp })
        let desktopReview = try XCTUnwrap(ClawGatewayDeliverySafetyReviewSummary.latest(from: desktopResult.artifacts))
        XCTAssertEqual(desktopReview.mode, "desktop-control-dry-run")
        XCTAssertEqual(desktopReview.actionKind, "operateDesktopApp")
        XCTAssertEqual(desktopReview.targetKind, "desktopApp")
        XCTAssertEqual(desktopReview.pasteTextOmitted, true)
        XCTAssertEqual(desktopReview.allowedKeyCount, 1)
        XCTAssertEqual(desktopReview.blockedKeyCount, 1)
        XCTAssertEqual(desktopReview.blockedSubmitKeyCount, 1)
        XCTAssertTrue(desktopReview.safetyFlags.contains("paste-text-omitted"))
    }

    func testMissionRunSummaryDerivesFileChangeSafetyReview() throws {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.phoneAgentCommand = "打开浏览器搜索资料，整理结果并发到 Slack"
        store.startAutonomousComputerTakeover()
        store.approveAndContinueAutonomousLoop()
        let review = try XCTUnwrap(store.missionRunSummary.gatewayFileChangeSafetyReview)

        XCTAssertEqual(review.reviewCount, 1)
        XCTAssertTrue(review.hasMetadata)
        XCTAssertEqual(review.mode, "workspace-write")
        XCTAssertEqual(review.actionKind, "manageFiles")
        XCTAssertEqual(review.workspacePolicy, "session-workspace-only")
        XCTAssertEqual(review.workspaceScoped, true)
        XCTAssertEqual(review.pathEscapeBlocked, false)
        XCTAssertEqual(review.writeAttempted, true)
        XCTAssertEqual(review.writeSucceeded, true)
        XCTAssertEqual(review.createdFileCount, 1)
        XCTAssertEqual(review.modifiedFileCount, 0)
        XCTAssertEqual(review.deletedFileCount, 0)
        XCTAssertEqual(review.requestedPathPresent, true)
        XCTAssertEqual(review.writeTextPresent, true)
        XCTAssertEqual(review.rawPathOmitted, true)
        XCTAssertEqual(review.contentOmitted, true)
        XCTAssertEqual(review.diffOmitted, true)
        XCTAssertEqual(review.resultStatus, "succeeded")
        XCTAssertTrue(review.safetyFlags.contains("metadata-only"))
        XCTAssertTrue(review.safetyFlags.contains("raw-path-omitted"))
        XCTAssertTrue(review.safetyFlags.contains("workspace-path-omitted"))
        XCTAssertTrue(review.safetyFlags.contains("file-content-omitted"))
        XCTAssertTrue(review.safetyFlags.contains("diff-content-omitted"))
        XCTAssertTrue(review.compactStatus.contains("session-workspace-only"))
        XCTAssertTrue(review.compactStatus.contains("created 1"))

        let fileResult = try XCTUnwrap(store.clawGatewaySessions.first?.results.first { $0.actionKind == .manageFiles })
        let fileReview = try XCTUnwrap(ClawGatewayFileChangeSafetyReviewSummary.latest(from: fileResult.artifacts))
        XCTAssertEqual(fileReview.mode, "workspace-write")
        XCTAssertEqual(fileReview.writeSucceeded, true)
        XCTAssertTrue(fileReview.safetyFlags.contains("session-workspace-only"))
    }

    func testMissionRunSummaryDerivesShellCommandSafetyReview() throws {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.phoneAgentCommand = "在项目目录运行测试，失败时导出日志文件"
        store.startAutonomousComputerTakeover()
        store.approveAndContinueAutonomousLoop()
        let review = try XCTUnwrap(store.missionRunSummary.gatewayShellCommandSafetyReview)

        XCTAssertEqual(review.reviewCount, 1)
        XCTAssertTrue(review.hasMetadata)
        XCTAssertEqual(review.mode, "shell-policy-blocked")
        XCTAssertEqual(review.actionKind, "runShellCommand")
        XCTAssertEqual(review.shellPolicy, "dry-run")
        XCTAssertEqual(review.structuredCommandPresent, true)
        XCTAssertEqual(review.commandParsed, true)
        XCTAssertEqual(review.allowlistConfigured, false)
        XCTAssertEqual(review.allowlistMatched, false)
        XCTAssertEqual(review.executionAttempted, false)
        XCTAssertEqual(review.executed, false)
        XCTAssertEqual(review.exitCodePresent, false)
        XCTAssertEqual(review.stdoutPresent, false)
        XCTAssertEqual(review.stderrPresent, false)
        XCTAssertEqual(review.commandOmitted, true)
        XCTAssertEqual(review.stdoutOmitted, true)
        XCTAssertEqual(review.stderrOmitted, true)
        XCTAssertEqual(review.cwdOmitted, true)
        XCTAssertEqual(review.resultStatus, "failed")
        XCTAssertTrue(review.safetyFlags.contains("metadata-only"))
        XCTAssertTrue(review.safetyFlags.contains("structured-arguments-only"))
        XCTAssertTrue(review.safetyFlags.contains("shell-allowlist-enforced"))
        XCTAssertTrue(review.safetyFlags.contains("command-omitted"))
        XCTAssertTrue(review.compactStatus.contains("policy dry-run"))

        let shellResult = try XCTUnwrap(store.clawGatewaySessions.first?.results.first { $0.actionKind == .runShellCommand })
        let shellReview = try XCTUnwrap(ClawGatewayShellCommandSafetyReviewSummary.latest(from: shellResult.artifacts))
        XCTAssertEqual(shellReview.mode, "shell-policy-blocked")
        XCTAssertEqual(shellReview.executed, false)
        XCTAssertTrue(shellReview.safetyFlags.contains("stdout-omitted"))
    }

    func testMissionRunSummaryDerivesReviewPriorityQueue() throws {
        let idleStore = ClawStore(autoScanLocalArtifacts: false)
        XCTAssertTrue(idleStore.missionRunSummary.reviewPriorityQueue.isEmpty)
        let idleReadiness = idleStore.missionRunSummary.reviewReadinessSummary
        XCTAssertEqual(idleReadiness.totalPriorityCount, 0)
        XCTAssertEqual(idleReadiness.actionablePriorityCount, 0)
        XCTAssertEqual(idleReadiness.criticalOrHighCount, 0)
        XCTAssertEqual(idleReadiness.metadataPendingCount, 0)
        XCTAssertNil(idleReadiness.topReviewKind)
        XCTAssertFalse(idleReadiness.isReviewable)
        XCTAssertFalse(idleReadiness.requiresHumanAction)
        let idleNextAction = idleStore.missionRunSummary.nextReviewAction
        XCTAssertFalse(idleNextAction.isReviewable)
        XCTAssertFalse(idleNextAction.requiresHumanAction)
        XCTAssertNil(idleNextAction.reviewKind)
        let idleEvidence = idleStore.missionRunSummary.artifactEvidenceIndex
        XCTAssertEqual(idleEvidence.artifactKindCount, 0)
        XCTAssertEqual(idleEvidence.metadataArtifactCount, 0)
        XCTAssertEqual(idleEvidence.redactedArtifactCount, 0)
        XCTAssertEqual(idleEvidence.coveredReviewCount, 0)
        XCTAssertFalse(idleEvidence.focusedHasEvidence)
        let idleOperatorStrip = idleStore.missionRunSummary.operatorStrip
        XCTAssertEqual(idleOperatorStrip.lanes.map(\.id), ["gateway", "evidence", "review", "next"])
        XCTAssertNil(idleOperatorStrip.focusedReviewKind)
        XCTAssertTrue(idleOperatorStrip.lanes.allSatisfy { $0.canFocusReview == false })
        XCTAssertTrue(idleOperatorStrip.lanes.contains { $0.id == "evidence" && $0.status == "0/0 类覆盖" })

        let store = ClawStore(autoScanLocalArtifacts: false)
        store.phoneAgentCommand = "打开浏览器搜索资料，整理结果并发到 Slack"
        store.startAutonomousComputerTakeover()
        store.approveAndContinueAutonomousLoop()

        let queue = store.missionRunSummary.reviewPriorityQueue
        XCTAssertFalse(queue.isEmpty)
        XCTAssertEqual(queue.map(\.rank), queue.map(\.rank).sorted())
        XCTAssertTrue(queue.contains { $0.reviewKind == "delivery-safety" && $0.severity == .high })
        XCTAssertTrue(queue.contains { $0.reviewKind == "file-change-safety" })
        XCTAssertTrue(queue.contains { $0.reviewKind == "browser-control" })
        XCTAssertTrue(queue.contains { $0.reviewKind == "artifact-metadata" })

        let summary = store.missionRunSummary
        let availableDetailKinds = summary.availableDetailReviewKinds
        XCTAssertFalse(availableDetailKinds.isEmpty)
        let evidenceIndex = summary.artifactEvidenceIndex
        XCTAssertEqual(evidenceIndex.artifactKindCount, summary.artifactKinds.count)
        XCTAssertEqual(evidenceIndex.metadataArtifactCount, summary.artifactMetadataReview?.metadataArtifactCount ?? 0)
        XCTAssertEqual(evidenceIndex.redactedArtifactCount, summary.artifactMetadataReview?.redactedArtifactCount ?? 0)
        XCTAssertEqual(evidenceIndex.items.map(\.reviewKind), availableDetailKinds)
        XCTAssertGreaterThan(evidenceIndex.coveredReviewCount, 0)
        XCTAssertTrue(evidenceIndex.items.contains { $0.reviewKind == "artifact-metadata" && $0.hasEvidence })
        XCTAssertTrue(evidenceIndex.items.contains { $0.reviewKind == "browser-control" && $0.artifactKinds.contains(.browserTrace) })
        XCTAssertTrue(evidenceIndex.items.contains { $0.reviewKind == "delivery-safety" && $0.artifactKinds.contains(.messageDraft) })
        let focusedEvidenceIndex = summary.artifactEvidenceIndex(focusedOn: "delivery-safety")
        XCTAssertEqual(focusedEvidenceIndex.focusedReviewKind, "delivery-safety")
        XCTAssertEqual(focusedEvidenceIndex.focusedReviewTitle, "最终提交安全")
        XCTAssertTrue(focusedEvidenceIndex.focusedHasEvidence)
        XCTAssertTrue(focusedEvidenceIndex.items.contains { $0.reviewKind == "delivery-safety" && $0.isFocused })
        let operatorStrip = summary.operatorStrip
        XCTAssertEqual(operatorStrip.lanes.map(\.id), ["gateway", "evidence", "review", "next"])
        XCTAssertEqual(operatorStrip.title, "Mission Operator")
        XCTAssertTrue(operatorStrip.lanes.contains { $0.id == "gateway" && $0.status.contains(summary.phaseTitle) })
        XCTAssertTrue(operatorStrip.lanes.contains { $0.id == "evidence" && $0.status == "\(evidenceIndex.coveredReviewCount)/\(evidenceIndex.items.count) 类覆盖" })
        XCTAssertTrue(operatorStrip.lanes.contains { $0.id == "review" && $0.status == "\(summary.reviewReadinessSummary.actionablePriorityCount) 可行动 · \(summary.reviewReadinessSummary.criticalOrHighCount) 高优先" })
        XCTAssertTrue(operatorStrip.lanes.contains { $0.id == "next" && $0.reviewKind == summary.nextReviewAction.reviewKind })
        let focusedOperatorStrip = summary.operatorStrip(focusedOn: "delivery-safety")
        XCTAssertEqual(focusedOperatorStrip.focusedReviewKind, "delivery-safety")
        XCTAssertTrue(focusedOperatorStrip.lanes.contains { $0.id == "next" && $0.reviewKind == "delivery-safety" && $0.isFocused })
        XCTAssertEqual(summary.detailReviewKinds(focusedOn: nil), availableDetailKinds)
        XCTAssertEqual(summary.detailReviewKinds(focusedOn: "delivery-safety"), ["delivery-safety"])
        XCTAssertEqual(summary.detailReviewKinds(focusedOn: "gateway-status"), availableDetailKinds)
        XCTAssertEqual(summary.detailReviewKinds(focusedOn: "unknown-review-kind"), availableDetailKinds)
        XCTAssertTrue(summary.shouldShowDetailReview("delivery-safety", focusedOn: "delivery-safety"))
        XCTAssertFalse(summary.shouldShowDetailReview("artifact-metadata", focusedOn: "delivery-safety"))
        XCTAssertFalse(summary.focusUsesDetailReview("gateway-status"))
        XCTAssertNotNil(summary.reviewPriorityItem(focusedOn: "delivery-safety"))
        let readiness = summary.reviewReadinessSummary
        XCTAssertEqual(readiness.totalPriorityCount, queue.count)
        XCTAssertEqual(readiness.actionablePriorityCount, queue.filter(\.isActionable).count)
        XCTAssertEqual(readiness.criticalOrHighCount, queue.filter { $0.severity == .critical || $0.severity == .high }.count)
        XCTAssertEqual(readiness.metadataPendingCount, queue.filter { $0.hasMetadata == false }.count)
        XCTAssertEqual(readiness.availableDetailReviewCount, availableDetailKinds.count)
        XCTAssertEqual(readiness.topReviewKind, queue.first?.reviewKind)
        XCTAssertEqual(readiness.topReviewTitle, queue.first?.title)
        XCTAssertTrue(readiness.isReviewable)
        XCTAssertTrue(readiness.requiresHumanAction)
        let nextAction = summary.nextReviewAction
        XCTAssertEqual(nextAction.reviewKind, queue.first?.reviewKind)
        XCTAssertEqual(nextAction.reviewTitle, queue.first?.title)
        XCTAssertEqual(nextAction.actionHint, queue.first?.actionHint)
        XCTAssertTrue(nextAction.isReviewable)
        XCTAssertTrue(nextAction.requiresHumanAction)
        let focusedReadiness = summary.reviewReadinessSummary(focusedOn: "delivery-safety")
        XCTAssertEqual(focusedReadiness.focusedReviewKind, "delivery-safety")
        XCTAssertEqual(focusedReadiness.focusedReviewTitle, "最终提交安全")
        XCTAssertTrue(focusedReadiness.focusedHasDetailReview)
        let focusedNextAction = summary.nextReviewAction(focusedOn: "delivery-safety")
        XCTAssertEqual(focusedNextAction.reviewKind, "delivery-safety")
        XCTAssertEqual(focusedNextAction.reviewTitle, "最终提交安全")
        XCTAssertTrue(focusedNextAction.canFocusDetailReview)
        let staleFocusNextAction = summary.nextReviewAction(focusedOn: "gateway-status")
        XCTAssertEqual(staleFocusNextAction.reviewKind, queue.first?.reviewKind)

        let queueVisibleChunks = queue.map {
            "\($0.title) \($0.status) \($0.reason) \($0.actionHint) \($0.reviewKind)"
        }
        let readinessVisibleChunks = [
            availableDetailKinds.joined(separator: " "),
            readiness.title,
            readiness.status,
            readiness.guidance,
            readiness.topReviewKind ?? "",
            readiness.topReviewTitle ?? "",
            readiness.topActionHint ?? "",
            focusedReadiness.focusedReviewKind ?? "",
            focusedReadiness.focusedReviewTitle ?? ""
        ]
        let nextActionVisibleChunks = [
            nextAction.title,
            nextAction.status,
            nextAction.guidance,
            nextAction.reviewKind ?? "",
            nextAction.reviewTitle ?? "",
            nextAction.actionHint ?? "",
            nextAction.primaryButtonTitle ?? "",
            focusedNextAction.title,
            focusedNextAction.status,
            focusedNextAction.guidance,
            focusedNextAction.reviewKind ?? "",
            focusedNextAction.reviewTitle ?? "",
            focusedNextAction.actionHint ?? "",
            focusedNextAction.primaryButtonTitle ?? ""
        ]
        let evidenceVisibleChunks = evidenceIndex.items.flatMap {
            [
                $0.reviewKind,
                $0.reviewTitle,
                $0.status,
                $0.guidance,
                $0.artifactKinds.map(\.title).joined(separator: " ")
            ]
        } + [
            evidenceIndex.title,
            evidenceIndex.status,
            evidenceIndex.guidance,
            focusedEvidenceIndex.focusedReviewKind ?? "",
            focusedEvidenceIndex.focusedReviewTitle ?? ""
        ]
        let operatorVisibleChunks = operatorStrip.lanes.flatMap {
            [
                $0.id,
                $0.title,
                $0.status,
                $0.guidance,
                $0.reviewKind ?? ""
            ]
        } + [
            operatorStrip.title,
            operatorStrip.status,
            focusedOperatorStrip.focusedReviewKind ?? ""
        ]
        let visibleText = (queueVisibleChunks + readinessVisibleChunks + nextActionVisibleChunks + evidenceVisibleChunks + operatorVisibleChunks).joined(separator: " ")
        for forbidden in ["Authorization", "Bearer", "toolArguments", "file://", "/private", "/Users", "/home", "C:\\", "stdout", "stderr", "diff"] {
            XCTAssertFalse(visibleText.contains(forbidden), "queue leaked \(forbidden)")
        }

        let shellStore = ClawStore(autoScanLocalArtifacts: false)
        shellStore.phoneAgentCommand = "在项目目录运行测试，失败时导出日志文件"
        shellStore.startAutonomousComputerTakeover()
        shellStore.approveAndContinueAutonomousLoop()

        let shellQueue = shellStore.missionRunSummary.reviewPriorityQueue
        let shellItem = try XCTUnwrap(shellQueue.first { $0.reviewKind == "shell-safety" })
        XCTAssertEqual(shellItem.severity, .high)
        XCTAssertTrue(shellItem.isActionable)
        XCTAssertTrue(shellItem.hasMetadata)
        XCTAssertTrue(shellItem.status.contains("policy dry-run"))
        XCTAssertEqual(shellStore.missionRunSummary.detailReviewKinds(focusedOn: "shell-safety"), ["shell-safety"])
        let shellReadiness = shellStore.missionRunSummary.reviewReadinessSummary
        XCTAssertGreaterThanOrEqual(shellReadiness.criticalOrHighCount, 1)
        XCTAssertGreaterThanOrEqual(shellReadiness.actionablePriorityCount, 1)
        let shellNextAction = shellStore.missionRunSummary.nextReviewAction(focusedOn: "shell-safety")
        XCTAssertEqual(shellNextAction.reviewKind, "shell-safety")
        XCTAssertEqual(shellNextAction.reviewTitle, "Shell 命令安全")
        XCTAssertTrue(shellNextAction.requiresHumanAction)
        XCTAssertTrue(shellNextAction.canFocusDetailReview)
        let shellEvidence = shellStore.missionRunSummary.artifactEvidenceIndex(focusedOn: "shell-safety")
        let shellEvidenceItem = try XCTUnwrap(shellEvidence.items.first { $0.reviewKind == "shell-safety" })
        XCTAssertTrue(shellEvidenceItem.hasEvidence)
        XCTAssertTrue(shellEvidenceItem.metadataReady)
        XCTAssertTrue(shellEvidenceItem.artifactKinds.contains(.commandOutput))
        XCTAssertTrue(shellEvidenceItem.isFocused)
        let shellOperatorStrip = shellStore.missionRunSummary.operatorStrip(focusedOn: "shell-safety")
        XCTAssertEqual(shellOperatorStrip.focusedReviewKind, "shell-safety")
        XCTAssertTrue(shellOperatorStrip.lanes.contains { $0.id == "next" && $0.reviewKind == "shell-safety" && $0.isFocused })
        XCTAssertFalse(
            [
                shellReadiness.title,
                shellReadiness.status,
                shellReadiness.guidance,
                shellReadiness.topActionHint ?? "",
                shellNextAction.title,
                shellNextAction.status,
                shellNextAction.guidance,
                shellNextAction.actionHint ?? "",
                shellNextAction.primaryButtonTitle ?? "",
                shellEvidence.title,
                shellEvidence.status,
                shellEvidence.guidance,
                shellEvidenceItem.status,
                shellEvidenceItem.guidance,
                shellOperatorStrip.status
            ].joined(separator: " ").contains("stdout")
        )
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
        XCTAssertEqual(review.accessibilityTreeState, "dry-run")
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
        XCTAssertEqual(review.readinessScore, 50)
        XCTAssertEqual(review.readinessCanContinue, true)
        XCTAssertEqual(review.satisfiedSignals, ["browserTrace", "fileDiff", "commandOutput"])
        XCTAssertEqual(review.degradedSignals, ["screenObservation", "accessibilityTree"])
        XCTAssertTrue(review.missingSignals.contains("messageDraft"))
        XCTAssertEqual(review.selectedNextActionKind, "composeMessage")
        XCTAssertEqual(review.selectedNextActionRequiresApproval, true)
        XCTAssertTrue(review.riskTags.contains("degraded-screen-observation"))
        XCTAssertTrue(review.riskTags.contains("final-submit-gate"))
        XCTAssertEqual(review.stopReason, "final-submit")
        XCTAssertEqual(review.handoffStatus, "final-submit-review")
        XCTAssertTrue(review.needsHandoffReview)
        XCTAssertTrue(review.isRedacted)
        XCTAssertTrue(review.compactStatus.contains("50/100"))
        XCTAssertTrue(review.compactStatus.contains("composeMessage"))
        XCTAssertTrue(review.compactStatus.contains("final-submit-review"))

        let continuation = store.missionRunSummary.loopContinuationSummary
        XCTAssertEqual(continuation.title, "Loop 最终提交复核")
        XCTAssertEqual(continuation.handoffStatus, "final-submit-review")
        XCTAssertEqual(continuation.readinessScore, 50)
        XCTAssertEqual(continuation.satisfiedSignalCount, 3)
        XCTAssertEqual(continuation.degradedSignalCount, 2)
        XCTAssertEqual(continuation.missingSignalCount, 1)
        XCTAssertEqual(continuation.selectedNextActionKind, "composeMessage")
        XCTAssertTrue(continuation.selectedNextActionRequiresApproval)
        XCTAssertEqual(continuation.focusReviewKind, "agent-trace")
        XCTAssertTrue(continuation.canFocusAgentTrace)
        XCTAssertFalse(continuation.canContinueLoop)
        XCTAssertTrue(continuation.requiresHumanAction)
        XCTAssertTrue(continuation.isReviewable)
    }

    func testMissionRunLoopContinuationCanBeReadyToContinue() throws {
        let artifact = ClawGatewayArtifact(
            kind: .agentTrace,
            title: "agent-loop-ready.json",
            reference: "file:///tmp/agent-loop-ready.json",
            isRedacted: true,
            metadata: [
                "readinessScore": "100",
                "readinessCanContinue": "true",
                "satisfiedSignals": "browserTrace,fileDiff,commandOutput",
                "degradedSignals": "",
                "missingSignals": "",
                "selectedNextActionKind": "extractData",
                "selectedNextActionRequiresApproval": "false",
                "riskTags": "",
                "stopReason": "none",
                "handoffStatus": "ready-to-continue",
                "handoffSummary": "Evidence score 100/100 from browserTrace, fileDiff, commandOutput. Selected next action: extractData. Stop reason: none."
            ]
        )
        let review = try XCTUnwrap(ClawAgentTraceReviewSummary.latest(from: [artifact]))
        let summary = ClawMissionRunSummary(
            command: "ready loop",
            phaseTitle: "复核中",
            phaseIcon: "arrow.triangle.2.circlepath",
            progressCurrent: 1,
            progressTotal: 3,
            riskScore: 0,
            approvalCount: 0,
            blockedCount: 0,
            succeededCount: 1,
            failedCount: 0,
            retryableCount: 0,
            artifactCount: 1,
            artifactKinds: [.agentTrace],
            artifactMetadataReview: nil,
            gatewayExtractionCompletenessReview: nil,
            gatewayBrowserControlReview: nil,
            gatewayDeliverySafetyReview: nil,
            gatewayFileChangeSafetyReview: nil,
            gatewayShellCommandSafetyReview: nil,
            agentTraceReview: review,
            gatewayAccessibilityReview: nil,
            gatewayCapabilityReview: nil,
            gatewayTaskReplayGuardReview: nil,
            reviewPriorityQueue: [],
            primaryActionTitle: "继续",
            primaryActionIcon: "arrow.forward.circle.fill",
            primaryActionKind: .continueAfterReview,
            isPrimaryActionEnabled: true,
            requiresUserApproval: false,
            statusLine: "ready",
            stageTrack: []
        )

        let continuation = summary.loopContinuationSummary

        XCTAssertEqual(continuation.title, "Loop 可继续")
        XCTAssertEqual(continuation.handoffStatus, "ready-to-continue")
        XCTAssertEqual(continuation.readinessScore, 100)
        XCTAssertEqual(continuation.satisfiedSignalCount, 3)
        XCTAssertEqual(continuation.degradedSignalCount, 0)
        XCTAssertEqual(continuation.missingSignalCount, 0)
        XCTAssertTrue(continuation.canContinueLoop)
        XCTAssertFalse(continuation.requiresHumanAction)
        XCTAssertTrue(continuation.canFocusAgentTrace)
    }

    func testMissionRunSummaryDerivesAccessibilityReview() throws {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.phoneAgentCommand = "打开浏览器搜索资料并发到 Slack"
        store.startAutonomousComputerTakeover()
        store.approveAndContinueAutonomousLoop()
        let review = try XCTUnwrap(store.missionRunSummary.gatewayAccessibilityReview)

        XCTAssertEqual(review.treeCount, 1)
        XCTAssertTrue(review.hasMetadata)
        XCTAssertEqual(review.mode, "dry-run")
        XCTAssertEqual(review.accessibilityPolicy, "dry-run")
        XCTAssertEqual(review.includeAccessibilityTree, true)
        XCTAssertEqual(review.maxCandidateControls, 20)
        XCTAssertEqual(review.nodeCount, 1)
        XCTAssertEqual(review.candidateControlCount, 2)
        XCTAssertEqual(review.platform, "simulated")
        XCTAssertEqual(review.redaction, "maskSensitiveText")
        XCTAssertTrue(review.safetyFlags.contains("action-execution-not-supported"))
        XCTAssertTrue(review.compactStatus.contains("ax dry-run"))
        XCTAssertTrue(review.compactStatus.contains("controls 2/20"))
        XCTAssertTrue(review.isRedacted)
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

    func testArtifactMetadataReviewParsesMetadataAndRedactsSensitiveValues() throws {
        let legacyArtifact = ClawGatewayArtifact(
            kind: .screenshot,
            title: "screen.png",
            reference: "file:///tmp/screen.png",
            isRedacted: true
        )
        let metadataArtifact = ClawGatewayArtifact(
            kind: .browserTrace,
            title: "browser-trace.json",
            reference: "file:///private/tmp/browser-trace.json",
            isRedacted: true,
            metadata: [
                "apiKey": "raw-api-key",
                "cookie": "session=secret-cookie",
                "Authorization": "Bearer raw-token",
                "pageText": "private page text",
                "stdout": "command output secret",
                "toolArguments": "{\"shellCommand\":\"cat /private/tmp/secret.txt\"}",
                "workspace": "/private/tmp/claw-work",
                "deliveryReview": "finalSubmitGate",
                "finalSubmitRequiresApproval": "true",
                "blockedSubmitKeyCount": "1",
                "mode": "browser-trace",
                "platform": "darwin",
                "safetyFlags": "metadata-only,raw-token-omitted"
            ]
        )
        let latestArtifact = ClawGatewayArtifact(
            kind: .messageDraft,
            title: "message-draft.txt",
            reference: "file:///private/tmp/message-draft.txt",
            isRedacted: false
        )

        let review = try XCTUnwrap(ClawGatewayArtifactMetadataReviewSummary.latest(from: [legacyArtifact, metadataArtifact, latestArtifact]))

        XCTAssertEqual(review.artifactCount, 3)
        XCTAssertEqual(review.metadataArtifactCount, 1)
        XCTAssertEqual(review.redactedArtifactCount, 2)
        XCTAssertEqual(review.latestKind, .messageDraft)
        XCTAssertEqual(review.latestTitle, "message-draft.txt")
        XCTAssertEqual(review.latestMetadataKind, .browserTrace)
        XCTAssertEqual(review.latestMetadataTitle, "browser-trace.json")
        XCTAssertFalse(review.isLatestRedacted)
        XCTAssertTrue(review.hasMetadata)
        XCTAssertTrue(review.safetyFlags.contains("metadata-only"))
        XCTAssertTrue(review.safeMetadataPairs.contains { $0.key == "mode" && $0.value == "browser-trace" })
        XCTAssertTrue(review.safeMetadataPairs.contains { $0.key == "platform" && $0.value == "darwin" })
        XCTAssertTrue(review.safeMetadataPairs.contains { $0.key == "deliveryReview" && $0.value == "finalSubmitGate" })
        XCTAssertTrue(review.safeMetadataPairs.contains { $0.key == "finalSubmitRequiresApproval" && $0.value == "true" })
        XCTAssertTrue(review.safeMetadataPairs.contains { $0.key == "blockedSubmitKeyCount" && $0.value == "1" })
        let visibleText = review.safeMetadataPairs
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        XCTAssertFalse(visibleText.contains("apiKey"))
        XCTAssertFalse(visibleText.contains("raw-api-key"))
        XCTAssertFalse(visibleText.contains("cookie"))
        XCTAssertFalse(visibleText.contains("secret-cookie"))
        XCTAssertFalse(visibleText.contains("Authorization"))
        XCTAssertFalse(visibleText.contains("Bearer"))
        XCTAssertFalse(visibleText.contains("raw-token"))
        XCTAssertFalse(visibleText.contains("pageText"))
        XCTAssertFalse(visibleText.contains("private page text"))
        XCTAssertFalse(visibleText.contains("stdout"))
        XCTAssertFalse(visibleText.contains("command output"))
        XCTAssertFalse(visibleText.contains("toolArguments"))
        XCTAssertFalse(visibleText.contains("shellCommand"))
        XCTAssertFalse(visibleText.contains("file://"))
        XCTAssertFalse(visibleText.contains("/private"))
        XCTAssertFalse(visibleText.contains("workspace=/"))

        let legacyReview = try XCTUnwrap(ClawGatewayArtifactMetadataReviewSummary.latest(from: [legacyArtifact]))
        XCTAssertFalse(legacyReview.hasMetadata)
        XCTAssertTrue(legacyReview.compactStatus.contains("metadata"))

        let fileChangeArtifact = ClawGatewayArtifact(
            kind: .fileDiff,
            title: "file-diff.json",
            reference: "file:///tmp/file-diff.json",
            isRedacted: true,
            metadata: [
                "fileChangeReview": "workspaceWrite notes/result.txt",
                "workspacePolicy": "session-workspace-only /private/tmp/workspace",
                "writeSucceeded": "true secret body",
                "createdFileCount": "1",
                "writeTextPresent": "private body",
                "rawPathOmitted": "true",
                "safetyFlags": "metadata-only,writePath=notes/result.txt,content=private body,/private/tmp/workspace",
                "toolArguments": "{\"writePath\":\"notes/result.txt\",\"writeText\":\"private body\"}"
            ]
        )
        let fileChangeMetadataReview = try XCTUnwrap(ClawGatewayArtifactMetadataReviewSummary.latest(from: [fileChangeArtifact]))
        let fileChangeVisibleText = (fileChangeMetadataReview.safeMetadataPairs.map { "\($0.key)=\($0.value)" } + fileChangeMetadataReview.safetyFlags).joined(separator: " ")
        XCTAssertTrue(fileChangeMetadataReview.hasMetadata)
        XCTAssertTrue(fileChangeMetadataReview.safeMetadataPairs.isEmpty)
        XCTAssertTrue(fileChangeMetadataReview.safetyFlags.isEmpty)
        XCTAssertFalse(fileChangeVisibleText.contains("notes/result.txt"))
        XCTAssertFalse(fileChangeVisibleText.contains("private body"))
        XCTAssertFalse(fileChangeVisibleText.contains("toolArguments"))
        XCTAssertFalse(fileChangeVisibleText.contains("/private"))
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
        XCTAssertNil(review.handoffStatus)
        XCTAssertTrue(review.degradedSignals.isEmpty)
        XCTAssertTrue(review.needsHandoffReview)
        XCTAssertEqual(review.latestTitle, "legacy-agent-loop.json")
        XCTAssertTrue(review.isRedacted)
        XCTAssertTrue(review.compactStatus.contains("metadata"))

        let summary = ClawMissionRunSummary(
            command: "legacy",
            phaseTitle: "完成",
            phaseIcon: "checkmark.circle.fill",
            progressCurrent: 1,
            progressTotal: 1,
            riskScore: 0,
            approvalCount: 0,
            blockedCount: 0,
            succeededCount: 1,
            failedCount: 0,
            retryableCount: 0,
            artifactCount: 1,
            artifactKinds: [.agentTrace],
            artifactMetadataReview: nil,
            gatewayExtractionCompletenessReview: nil,
            gatewayBrowserControlReview: nil,
            gatewayDeliverySafetyReview: nil,
            gatewayFileChangeSafetyReview: nil,
            gatewayShellCommandSafetyReview: nil,
            agentTraceReview: review,
            gatewayAccessibilityReview: nil,
            gatewayCapabilityReview: nil,
            gatewayTaskReplayGuardReview: nil,
            reviewPriorityQueue: [],
            primaryActionTitle: "完成",
            primaryActionIcon: "checkmark.circle.fill",
            primaryActionKind: .waitForGateway,
            isPrimaryActionEnabled: false,
            requiresUserApproval: false,
            statusLine: "legacy",
            stageTrack: []
        )
        XCTAssertEqual(summary.loopContinuationSummary.title, "Loop metadata 待同步")
        XCTAssertTrue(summary.loopContinuationSummary.hasMetadataGap)
        XCTAssertTrue(summary.loopContinuationSummary.requiresHumanAction)
    }

    func testExtractionCompletenessReviewParsesMetadataAndRedactsSensitiveValues() throws {
        let artifact = ClawGatewayArtifact(
            kind: .browserTrace,
            title: "extracted-data-1 https://example.com/private-row.json",
            reference: "file:///tmp/extracted-data-1.json",
            isRedacted: true,
            metadata: [
                "extractionReview": "artifactGrounded",
                "mode": "artifact-grounded-extraction Authorization: Bearer raw-token",
                "validateCompleteness": "true",
                "rowCount": "8",
                "completenessStatus": "complete file:///private/tmp/secret.json",
                "browserTraceCount": "2",
                "fileDiffCount": "1",
                "commandOutputCount": "1",
                "screenObservationCount": "1",
                "accessibilityTreeCount": "1",
                "messageDraftCount": "0",
                "sourceArtifactKinds": "browserTrace,fileDiff,commandOutput,toolArguments,/home/alice/private.txt,https://example.com/row",
                "safetyFlags": "metadata-only,row-content-omitted,headers={Authorization: Bearer raw-token},~/Library/Claw/private.txt,https://example.com/row"
            ]
        )

        let review = try XCTUnwrap(ClawGatewayExtractionCompletenessReviewSummary.latest(from: [artifact]))
        let visibleText = [
            review.latestTitle,
            review.compactStatus,
            review.mode ?? "",
            review.completenessStatus ?? "",
            review.sourceArtifactKinds.joined(separator: " "),
            review.safetyFlags.joined(separator: " ")
        ].joined(separator: " ")

        XCTAssertEqual(review.extractionCount, 1)
        XCTAssertTrue(review.hasMetadata)
        XCTAssertEqual(review.validateCompleteness, true)
        XCTAssertEqual(review.rowCount, 8)
        XCTAssertEqual(review.browserTraceCount, 2)
        XCTAssertEqual(review.fileDiffCount, 1)
        XCTAssertEqual(review.commandOutputCount, 1)
        XCTAssertNil(review.mode)
        XCTAssertNil(review.completenessStatus)
        XCTAssertTrue(review.sourceArtifactKinds.contains("browserTrace"))
        XCTAssertFalse(review.sourceArtifactKinds.contains("toolArguments"))
        XCTAssertFalse(review.safetyFlags.contains { $0.contains("headers") })
        XCTAssertFalse(visibleText.contains("Authorization"))
        XCTAssertFalse(visibleText.contains("Bearer"))
        XCTAssertFalse(visibleText.contains("raw-token"))
        XCTAssertFalse(visibleText.contains("https://"))
        XCTAssertFalse(visibleText.contains("file://"))
        XCTAssertFalse(visibleText.contains("/private"))
        XCTAssertFalse(visibleText.contains("/home"))
        XCTAssertFalse(visibleText.contains("~/"))
        XCTAssertFalse(visibleText.contains("toolArguments"))

        let legacyArtifact = ClawGatewayArtifact(
            kind: .browserTrace,
            title: "extracted-data-legacy.json",
            reference: "file:///tmp/extracted-data-legacy.json",
            isRedacted: true
        )
        let legacyReview = try XCTUnwrap(ClawGatewayExtractionCompletenessReviewSummary.latest(from: [legacyArtifact]))
        XCTAssertFalse(legacyReview.hasMetadata)
        XCTAssertTrue(legacyReview.compactStatus.contains("metadata"))
    }

    func testBrowserControlReviewFallsBackAndRedactsSensitiveMetadata() throws {
        let legacyArtifact = ClawGatewayArtifact(
            kind: .browserTrace,
            title: "browser-trace-legacy.json",
            reference: "file:///tmp/browser-trace-legacy.json",
            isRedacted: false
        )
        let legacyReview = try XCTUnwrap(ClawGatewayBrowserControlReviewSummary.latest(from: [legacyArtifact]))
        XCTAssertEqual(legacyReview.reviewCount, 1)
        XCTAssertFalse(legacyReview.hasMetadata)
        XCTAssertNil(legacyReview.browserControlPolicy)
        XCTAssertTrue(legacyReview.compactStatus.contains("metadata"))

        let artifact = ClawGatewayArtifact(
            kind: .screenshot,
            title: "browser-control file:///private/tmp/browser.json https://example.com/private?q=secret",
            reference: "file:///tmp/browser-control.json",
            isRedacted: true,
            metadata: [
                "browserReview": "controlPlan",
                "mode": "browser-control-dry-run Authorization: Bearer raw-token",
                "actionKind": "controlBrowser token=raw-token",
                "browserControlPolicy": "enabled https://example.com/private",
                "browserControlRequested": "true",
                "openInBrowser": "true",
                "targetURLPresent": "true",
                "searchQueryPresent": "true",
                "localHTMLInput": "true",
                "networkFetchAttempted": "true",
                "networkBlocked": "true",
                "appAllowlistEnforced": "true",
                "hostAllowlistEnforced": "true",
                "executed": "false",
                "timedOut": "false",
                "resultStatus": "failed file:///private/tmp/log.txt",
                "safetyFlags": "metadata-only,url-omitted,search-query-omitted,page-content-omitted,form-fields-omitted,candidate-labels-omitted,headers={Authorization: Bearer raw-token},searchQuery=secret,html=<input name=password>,candidateLabel=Submit,toolArguments=/private/tmp/input.json",
                "toolArguments": "{\"url\":\"https://example.com/private\",\"searchQuery\":\"secret\"}"
            ]
        )

        let review = try XCTUnwrap(ClawGatewayBrowserControlReviewSummary.latest(from: [artifact]))
        let visibleText = [
            review.latestTitle,
            review.compactStatus,
            review.mode ?? "",
            review.actionKind ?? "",
            review.browserControlPolicy ?? "",
            review.resultStatus ?? "",
            review.safetyFlags.joined(separator: " ")
        ].joined(separator: " ")

        XCTAssertTrue(review.hasMetadata)
        XCTAssertNil(review.mode)
        XCTAssertNil(review.actionKind)
        XCTAssertNil(review.browserControlPolicy)
        XCTAssertNil(review.resultStatus)
        XCTAssertEqual(review.browserControlRequested, true)
        XCTAssertEqual(review.openInBrowser, true)
        XCTAssertEqual(review.targetURLPresent, true)
        XCTAssertEqual(review.searchQueryPresent, true)
        XCTAssertEqual(review.localHTMLInput, true)
        XCTAssertEqual(review.networkFetchAttempted, true)
        XCTAssertEqual(review.networkBlocked, true)
        XCTAssertEqual(review.appAllowlistEnforced, true)
        XCTAssertEqual(review.hostAllowlistEnforced, true)
        XCTAssertEqual(review.executed, false)
        XCTAssertEqual(review.timedOut, false)
        XCTAssertTrue(review.safetyFlags.contains("metadata-only"))
        XCTAssertTrue(review.safetyFlags.contains("url-omitted"))
        XCTAssertTrue(review.safetyFlags.contains("search-query-omitted"))
        XCTAssertFalse(visibleText.contains("Authorization"))
        XCTAssertFalse(visibleText.contains("Bearer"))
        XCTAssertFalse(visibleText.contains("raw-token"))
        XCTAssertFalse(visibleText.contains("https://"))
        XCTAssertFalse(visibleText.contains("file://"))
        XCTAssertFalse(visibleText.contains("/private"))
        XCTAssertFalse(visibleText.contains("toolArguments"))
        XCTAssertFalse(visibleText.contains("searchQuery"))
        XCTAssertFalse(visibleText.contains("secret"))
        XCTAssertFalse(visibleText.contains("<input"))
        XCTAssertFalse(visibleText.contains("candidateLabel"))
    }

    func testDeliverySafetyReviewFallsBackAndRedactsSensitiveMetadata() throws {
        let legacyArtifact = ClawGatewayArtifact(
            kind: .messageDraft,
            title: "legacy-draft.txt",
            reference: "file:///tmp/legacy-draft.txt",
            isRedacted: true
        )
        let legacyReview = try XCTUnwrap(ClawGatewayDeliverySafetyReviewSummary.latest(from: [legacyArtifact]))
        XCTAssertEqual(legacyReview.reviewCount, 1)
        XCTAssertFalse(legacyReview.hasMetadata)
        XCTAssertNil(legacyReview.finalSubmitRequiresApproval)
        XCTAssertTrue(legacyReview.compactStatus.contains("metadata"))

        let artifact = ClawGatewayArtifact(
            kind: .messageDraft,
            title: "draft file:///private/tmp/draft.txt https://example.com/private",
            reference: "file:///tmp/draft.txt",
            isRedacted: true,
            metadata: [
                "deliveryReview": "finalSubmitGate",
                "mode": "message-draft-pending-approval Authorization: Bearer raw-token",
                "actionKind": "composeMessage token=raw-token",
                "targetKind": "message file:///private/tmp/message.txt",
                "finalSubmitRequiresApproval": "true",
                "userApprovalRequired": "true",
                "draftBodyOmitted": "true",
                "pasteTextOmitted": "false",
                "submitBlocked": "true",
                "allowedKeyCount": "0",
                "blockedKeyCount": "0",
                "blockedSubmitKeyCount": "0",
                "safetyFlags": "metadata-only,final-submit-gated,headers={Authorization: Bearer raw-token},draftText=private body,pasteText=secret,keySequence=return,/private/tmp/draft.txt,https://example.com/private",
                "toolArguments": "{\"draftText\":\"private body\"}"
            ]
        )

        let review = try XCTUnwrap(ClawGatewayDeliverySafetyReviewSummary.latest(from: [artifact]))
        let visibleText = [
            review.latestTitle,
            review.compactStatus,
            review.mode ?? "",
            review.actionKind ?? "",
            review.targetKind ?? "",
            review.safetyFlags.joined(separator: " ")
        ].joined(separator: " ")

        XCTAssertTrue(review.hasMetadata)
        XCTAssertNil(review.mode)
        XCTAssertNil(review.actionKind)
        XCTAssertNil(review.targetKind)
        XCTAssertEqual(review.finalSubmitRequiresApproval, true)
        XCTAssertEqual(review.userApprovalRequired, true)
        XCTAssertEqual(review.draftBodyOmitted, true)
        XCTAssertEqual(review.pasteTextOmitted, false)
        XCTAssertEqual(review.submitBlocked, true)
        XCTAssertEqual(review.blockedSubmitKeyCount, 0)
        XCTAssertTrue(review.safetyFlags.contains("metadata-only"))
        XCTAssertTrue(review.safetyFlags.contains("final-submit-gated"))
        XCTAssertFalse(visibleText.contains("Authorization"))
        XCTAssertFalse(visibleText.contains("Bearer"))
        XCTAssertFalse(visibleText.contains("raw-token"))
        XCTAssertFalse(visibleText.contains("draftText"))
        XCTAssertFalse(visibleText.contains("pasteText"))
        XCTAssertFalse(visibleText.contains("keySequence"))
        XCTAssertFalse(visibleText.contains("private body"))
        XCTAssertFalse(visibleText.contains("file://"))
        XCTAssertFalse(visibleText.contains("https://"))
        XCTAssertFalse(visibleText.contains("/private"))
        XCTAssertFalse(visibleText.contains("toolArguments"))
    }

    func testFileChangeSafetyReviewFallsBackAndRedactsSensitiveMetadata() throws {
        let legacyArtifact = ClawGatewayArtifact(
            kind: .fileDiff,
            title: "legacy-file-diff.json",
            reference: "file:///tmp/legacy-file-diff.json",
            isRedacted: false
        )
        let legacyReview = try XCTUnwrap(ClawGatewayFileChangeSafetyReviewSummary.latest(from: [legacyArtifact]))
        XCTAssertEqual(legacyReview.reviewCount, 1)
        XCTAssertFalse(legacyReview.hasMetadata)
        XCTAssertNil(legacyReview.workspacePolicy)
        XCTAssertTrue(legacyReview.compactStatus.contains("metadata"))

        let artifact = ClawGatewayArtifact(
            kind: .fileDiff,
            title: "file-diff file:///private/tmp/diff.json /Users/alice/project/notes/result.txt",
            reference: "file:///tmp/file-diff.json",
            isRedacted: true,
            metadata: [
                "fileChangeReview": "workspaceWrite",
                "mode": "workspace-write Authorization: Bearer raw-token",
                "actionKind": "manageFiles token=raw-token",
                "workspacePolicy": "session-workspace-only /private/tmp/workspace",
                "workspaceScoped": "true",
                "pathEscapeBlocked": "false",
                "writeAttempted": "true",
                "writeSucceeded": "true",
                "createdFileCount": "1",
                "modifiedFileCount": "0",
                "deletedFileCount": "0",
                "requestedPathPresent": "true",
                "writeTextPresent": "true",
                "rawPathOmitted": "true",
                "contentOmitted": "true",
                "diffOmitted": "true",
                "resultStatus": "succeeded file:///private/tmp/log.txt",
                "safetyFlags": "metadata-only,raw-path-omitted,workspace-path-omitted,file-content-omitted,diff-content-omitted,headers={Authorization: Bearer raw-token},writePath=notes/result.txt,patch=@@ secret,content=private body,/private/tmp/workspace",
                "toolArguments": "{\"writePath\":\"notes/result.txt\",\"writeText\":\"private body\"}",
                "workspace": "/private/tmp/workspace",
                "requestedPath": "notes/result.txt",
                "diff": "@@ secret"
            ]
        )

        let review = try XCTUnwrap(ClawGatewayFileChangeSafetyReviewSummary.latest(from: [artifact]))
        let visibleText = [
            review.latestTitle,
            review.compactStatus,
            review.mode ?? "",
            review.actionKind ?? "",
            review.workspacePolicy ?? "",
            review.resultStatus ?? "",
            review.safetyFlags.joined(separator: " ")
        ].joined(separator: " ")

        XCTAssertTrue(review.hasMetadata)
        XCTAssertNil(review.mode)
        XCTAssertNil(review.actionKind)
        XCTAssertNil(review.workspacePolicy)
        XCTAssertNil(review.resultStatus)
        XCTAssertEqual(review.workspaceScoped, true)
        XCTAssertEqual(review.pathEscapeBlocked, false)
        XCTAssertEqual(review.writeAttempted, true)
        XCTAssertEqual(review.writeSucceeded, true)
        XCTAssertEqual(review.createdFileCount, 1)
        XCTAssertEqual(review.rawPathOmitted, true)
        XCTAssertEqual(review.contentOmitted, true)
        XCTAssertEqual(review.diffOmitted, true)
        XCTAssertTrue(review.safetyFlags.contains("metadata-only"))
        XCTAssertTrue(review.safetyFlags.contains("raw-path-omitted"))
        XCTAssertTrue(review.safetyFlags.contains("workspace-path-omitted"))
        XCTAssertTrue(review.safetyFlags.contains("file-content-omitted"))
        XCTAssertTrue(review.safetyFlags.contains("diff-content-omitted"))
        XCTAssertFalse(visibleText.contains("Authorization"))
        XCTAssertFalse(visibleText.contains("Bearer"))
        XCTAssertFalse(visibleText.contains("raw-token"))
        XCTAssertFalse(visibleText.contains("writePath"))
        XCTAssertFalse(visibleText.contains("notes/result.txt"))
        XCTAssertFalse(visibleText.contains("patch"))
        XCTAssertFalse(visibleText.contains("@@"))
        XCTAssertFalse(visibleText.contains("private body"))
        XCTAssertFalse(visibleText.contains("file://"))
        XCTAssertFalse(visibleText.contains("/private"))
        XCTAssertFalse(visibleText.contains("/Users"))
        XCTAssertFalse(visibleText.contains("toolArguments"))
    }

    func testShellCommandSafetyReviewFallsBackAndRedactsSensitiveMetadata() throws {
        let legacyArtifact = ClawGatewayArtifact(
            kind: .commandOutput,
            title: "legacy-shell.log",
            reference: "file:///tmp/legacy-shell.log",
            isRedacted: true
        )
        let legacyReview = try XCTUnwrap(ClawGatewayShellCommandSafetyReviewSummary.latest(from: [legacyArtifact]))
        XCTAssertEqual(legacyReview.reviewCount, 1)
        XCTAssertFalse(legacyReview.hasMetadata)
        XCTAssertNil(legacyReview.shellPolicy)
        XCTAssertTrue(legacyReview.compactStatus.contains("metadata"))

        let artifact = ClawGatewayArtifact(
            kind: .commandOutput,
            title: "shell-output file:///private/tmp/shell.log /Users/alice/project",
            reference: "file:///tmp/shell-output.log",
            isRedacted: true,
            metadata: [
                "shellReview": "commandSafety",
                "mode": "shell-executed Authorization: Bearer raw-token",
                "actionKind": "runShellCommand token=raw-token",
                "shellPolicy": "allowlist-enabled /private/tmp/workspace",
                "structuredCommandPresent": "true",
                "commandParsed": "true",
                "allowlistConfigured": "true",
                "allowlistMatched": "true",
                "executionAttempted": "true",
                "executed": "true",
                "timedOut": "false",
                "exitCodePresent": "true",
                "exitCodeZero": "true",
                "stdoutPresent": "true",
                "stderrPresent": "false",
                "commandOmitted": "true",
                "stdoutOmitted": "true",
                "stderrOmitted": "true",
                "cwdOmitted": "true",
                "resultStatus": "succeeded file:///private/tmp/log.txt",
                "safetyFlags": "metadata-only,command-omitted,stdout-omitted,stderr-omitted,cwd-omitted,headers={Authorization: Bearer raw-token},shellCommand=pwd,stdout=/private/tmp/workspace,toolArguments=/private/tmp/input.json",
                "shellCommand": "pwd",
                "stdout": "/private/tmp/workspace",
                "stderr": "secret stderr",
                "cwd": "/private/tmp/workspace"
            ]
        )

        let review = try XCTUnwrap(ClawGatewayShellCommandSafetyReviewSummary.latest(from: [artifact]))
        let visibleText = [
            review.latestTitle,
            review.compactStatus,
            review.mode ?? "",
            review.actionKind ?? "",
            review.shellPolicy ?? "",
            review.resultStatus ?? "",
            review.safetyFlags.joined(separator: " ")
        ].joined(separator: " ")

        XCTAssertTrue(review.hasMetadata)
        XCTAssertNil(review.mode)
        XCTAssertNil(review.actionKind)
        XCTAssertNil(review.shellPolicy)
        XCTAssertNil(review.resultStatus)
        XCTAssertEqual(review.executed, true)
        XCTAssertEqual(review.exitCodeZero, true)
        XCTAssertEqual(review.commandOmitted, true)
        XCTAssertEqual(review.stdoutOmitted, true)
        XCTAssertEqual(review.stderrOmitted, true)
        XCTAssertEqual(review.cwdOmitted, true)
        XCTAssertTrue(review.safetyFlags.contains("command-omitted"))
        XCTAssertTrue(review.safetyFlags.contains("stdout-omitted"))
        XCTAssertFalse(visibleText.contains("Authorization"))
        XCTAssertFalse(visibleText.contains("Bearer"))
        XCTAssertFalse(visibleText.contains("raw-token"))
        XCTAssertFalse(visibleText.contains("shellCommand"))
        XCTAssertFalse(visibleText.contains("pwd"))
        XCTAssertFalse(visibleText.contains("secret stderr"))
        XCTAssertFalse(visibleText.contains("file://"))
        XCTAssertFalse(visibleText.contains("/private"))
        XCTAssertFalse(visibleText.contains("/Users"))
        XCTAssertFalse(visibleText.contains("toolArguments"))
    }

    func testAgentTraceReviewRedactsSensitiveMetadata() throws {
        let artifact = ClawGatewayArtifact(
            kind: .agentTrace,
            title: "agent-loop file:///private/tmp/agent-loop.json",
            reference: "file:///tmp/agent-loop.json",
            isRedacted: true,
            metadata: [
                "readinessScore": "64",
                "readinessCanContinue": "true",
                "satisfiedSignals": "browserTrace,Authorization: Bearer raw-token,file:///private/tmp/browser.json,/home/alice/browser.json",
                "degradedSignals": "accessibilityTree,Authorization: Bearer raw-token,file:///private/tmp/accessibility.json,/Users/alice/window.json",
                "missingSignals": "messageDraft,workspace=/private/tmp/claw-work,~/Library/Claw/state.json",
                "selectedNextActionKind": "composeMessage token=raw-token",
                "selectedNextActionRequiresApproval": "true",
                "riskTags": "final-submit-gate,headers={Authorization: Bearer raw-token},C:\\Users\\alice\\secret.txt",
                "stopReason": "final-submit file:///private/tmp/secret.txt \\\\server\\share\\secret.txt",
                "handoffStatus": "waiting-for-approval Authorization: Bearer raw-token file:///private/tmp/secret.txt",
                "handoffSummary": "Use toolArguments with Authorization: Bearer raw-token in /private/tmp/claw-work and /home/alice/claw"
            ]
        )

        let review = try XCTUnwrap(ClawAgentTraceReviewSummary.latest(from: [artifact]))
        let visibleText = [
            review.latestTitle,
            review.compactStatus,
            review.satisfiedSignals.joined(separator: " "),
            review.degradedSignals.joined(separator: " "),
            review.missingSignals.joined(separator: " "),
            review.selectedNextActionKind ?? "",
            review.riskTags.joined(separator: " "),
            review.stopReason ?? "",
            review.handoffStatus ?? "",
            review.handoffSummary ?? ""
        ].joined(separator: " ")

        XCTAssertEqual(review.readinessScore, 64)
        XCTAssertEqual(review.readinessCanContinue, true)
        XCTAssertEqual(review.selectedNextActionRequiresApproval, true)
        XCTAssertEqual(review.degradedSignals, ["accessibilityTree"])
        XCTAssertNil(review.handoffStatus)
        XCTAssertFalse(visibleText.contains("Authorization"))
        XCTAssertFalse(visibleText.contains("Bearer"))
        XCTAssertFalse(visibleText.contains("raw-token"))
        XCTAssertFalse(visibleText.contains("file://"))
        XCTAssertFalse(visibleText.contains("/private"))
        XCTAssertFalse(visibleText.contains("/home"))
        XCTAssertFalse(visibleText.contains("~/"))
        XCTAssertFalse(visibleText.contains("C:\\"))
        XCTAssertFalse(visibleText.contains("\\\\server"))
        XCTAssertFalse(visibleText.contains("workspace=/"))
        XCTAssertFalse(visibleText.contains("toolArguments"))
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
                "accessibilityTreeState": "dry-run",
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
        XCTAssertEqual(review.accessibilityTreeState, "dry-run")
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

        let sensitiveArtifact = ClawGatewayArtifact(
            kind: .auditLog,
            title: "gateway-capability file:///private/tmp/snapshot.json",
            reference: "file:///tmp/sensitive-gateway-capability-snapshot.json",
            isRedacted: true,
            metadata: [
                "snapshotKind": "gatewayCapability",
                "tokenConfigured": "true",
                "tokenRequired": "true",
                "tokenFingerprint": "Authorization: Bearer raw-token",
                "allowedActionKinds": "controlBrowser,toolArguments,token=raw-token,C:\\Users\\alice\\secret.txt",
                "workspaceState": "workspace=/private/tmp/claw-work",
                "shellState": "dry-run file:///private/tmp/shell.log /home/alice/shell.log",
                "browserControlState": "real",
                "browserNetworkState": "headers={Authorization: Bearer raw-token}",
                "screenCaptureState": "dry-run",
                "windowMetadataState": "dry-run",
                "accessibilityTreeState": "dry-run",
                "desktopControlState": "unavailable",
                "safetyFlags": "allowlists-enforced,headers={Authorization: Bearer raw-token},file:///private/tmp/private.txt,~/Library/Claw/private.txt",
                "platform": "darwin /private/tmp/claw-work \\\\server\\share\\claw"
            ]
        )
        let sensitiveReview = try XCTUnwrap(ClawGatewayCapabilityReviewSummary.latest(from: [sensitiveArtifact]))
        let visibleText = [
            sensitiveReview.latestTitle,
            sensitiveReview.compactStatus,
            sensitiveReview.tokenFingerprint ?? "",
            sensitiveReview.allowedActionKinds.joined(separator: " "),
            sensitiveReview.workspaceState ?? "",
            sensitiveReview.shellState ?? "",
            sensitiveReview.browserNetworkState ?? "",
            sensitiveReview.safetyFlags.joined(separator: " "),
            sensitiveReview.platform ?? ""
        ].joined(separator: " ")
        XCTAssertFalse(visibleText.contains("Authorization"))
        XCTAssertFalse(visibleText.contains("Bearer"))
        XCTAssertFalse(visibleText.contains("raw-token"))
        XCTAssertFalse(visibleText.contains("file://"))
        XCTAssertFalse(visibleText.contains("/private"))
        XCTAssertFalse(visibleText.contains("/home"))
        XCTAssertFalse(visibleText.contains("~/"))
        XCTAssertFalse(visibleText.contains("C:\\"))
        XCTAssertFalse(visibleText.contains("\\\\server"))
        XCTAssertFalse(visibleText.contains("workspace=/"))
        XCTAssertFalse(visibleText.contains("toolArguments"))
    }

    func testAccessibilityReviewParsesMetadataAndFallsBack() throws {
        let artifact = ClawGatewayArtifact(
            kind: .accessibilityTree,
            title: "accessibility-tree-1.json",
            reference: "file:///tmp/accessibility-tree-1.json",
            isRedacted: true,
            metadata: [
                "accessibilityTree": "observeSummary",
                "mode": "accessibility-summary",
                "accessibilityPolicy": "enabled",
                "includeAccessibilityTree": "true",
                "maxCandidateControls": "12",
                "nodeCount": "1",
                "candidateControlCount": "8",
                "platform": "darwin",
                "redaction": "maskSensitiveText",
                "safetyFlags": "observe-only,values-omitted,password-fields-omitted"
            ]
        )

        let review = try XCTUnwrap(ClawGatewayAccessibilityReviewSummary.latest(from: [artifact]))

        XCTAssertEqual(review.treeCount, 1)
        XCTAssertTrue(review.hasMetadata)
        XCTAssertEqual(review.mode, "accessibility-summary")
        XCTAssertEqual(review.accessibilityPolicy, "enabled")
        XCTAssertEqual(review.includeAccessibilityTree, true)
        XCTAssertEqual(review.maxCandidateControls, 12)
        XCTAssertEqual(review.nodeCount, 1)
        XCTAssertEqual(review.candidateControlCount, 8)
        XCTAssertEqual(review.platform, "darwin")
        XCTAssertEqual(review.redaction, "maskSensitiveText")
        XCTAssertTrue(review.safetyFlags.contains("values-omitted"))
        XCTAssertTrue(review.compactStatus.contains("controls 8/12"))
        XCTAssertTrue(review.isRedacted)

        let legacyArtifact = ClawGatewayArtifact(
            kind: .accessibilityTree,
            title: "legacy-accessibility-tree.json",
            reference: "file:///tmp/legacy-accessibility-tree.json",
            isRedacted: true
        )
        let legacyReview = try XCTUnwrap(ClawGatewayAccessibilityReviewSummary.latest(from: [legacyArtifact]))
        XCTAssertFalse(legacyReview.hasMetadata)
        XCTAssertTrue(legacyReview.compactStatus.contains("metadata"))

        let sensitiveArtifact = ClawGatewayArtifact(
            kind: .accessibilityTree,
            title: "sensitive-accessibility-tree.json",
            reference: "file:///tmp/sensitive-accessibility-tree.json",
            isRedacted: true,
            metadata: [
                "accessibilityTree": "observeSummary",
                "mode": "dry-run Authorization: Bearer raw-token",
                "accessibilityPolicy": "dry-run",
                "redaction": "workspace=/private/tmp/claw-work",
                "safetyFlags": "observe-only,headers={Authorization: Bearer raw-token},file:///tmp/private.txt"
            ]
        )
        let sensitiveReview = try XCTUnwrap(ClawGatewayAccessibilityReviewSummary.latest(from: [sensitiveArtifact]))
        let visibleText = [
            sensitiveReview.compactStatus,
            sensitiveReview.redaction ?? "",
            sensitiveReview.safetyFlags.joined(separator: " ")
        ].joined(separator: " ")
        XCTAssertFalse(visibleText.contains("Authorization"))
        XCTAssertFalse(visibleText.contains("Bearer"))
        XCTAssertFalse(visibleText.contains("raw-token"))
        XCTAssertFalse(visibleText.contains("file://"))
        XCTAssertFalse(visibleText.contains("/private"))
        XCTAssertFalse(visibleText.contains("workspace=/"))
    }

    func testGatewayTaskReplayGuardReviewParsesMetadataAndFallsBack() throws {
        let artifact = ClawGatewayArtifact(
            kind: .auditLog,
            title: "task-replay-guard.json",
            reference: "file:///tmp/task-replay-guard.json",
            isRedacted: true,
            metadata: [
                "replayGuard": "taskReplayGuard",
                "decision": "skip-duplicate-task",
                "taskID": "12345678-1234-1234-1234-123456789abc",
                "replayDigest": "sha256:abcdef1234567890",
                "digestMatchesFirst": "true",
                "firstSessionID": "87654321-4321-4321-4321-cba987654321",
                "originalStatus": "completed",
                "replayCount": "2",
                "actionCount": "5",
                "actionKinds": "controlBrowser,manageFiles,runAgentLoop",
                "safetyFlags": "process-local,actions-skipped,business-artifacts-not-written",
                "toolArguments": "should-not-be-read",
                "Authorization": "Bearer raw-token"
            ]
        )

        let review = try XCTUnwrap(ClawGatewayTaskReplayGuardReviewSummary.latest(from: [artifact]))

        XCTAssertEqual(review.replayCountArtifacts, 1)
        XCTAssertTrue(review.hasMetadata)
        XCTAssertEqual(review.decision, "skip-duplicate-task")
        XCTAssertEqual(review.shortTaskID, "12345678")
        XCTAssertEqual(review.shortReplayDigest, "sha256:abcdef123456")
        XCTAssertEqual(review.shortFirstSessionID, "87654321")
        XCTAssertEqual(review.digestMatchesFirst, true)
        XCTAssertEqual(review.originalStatus, "completed")
        XCTAssertEqual(review.replayCount, 2)
        XCTAssertEqual(review.actionCount, 5)
        XCTAssertEqual(review.actionKinds, ["controlBrowser", "manageFiles", "runAgentLoop"])
        XCTAssertTrue(review.safetyFlags.contains("actions-skipped"))
        XCTAssertTrue(review.compactStatus.contains("skip-duplicate-task"))
        XCTAssertTrue(review.compactStatus.contains("重复 2 次"))
        XCTAssertFalse(review.compactStatus.contains("toolArguments"))
        XCTAssertFalse(review.compactStatus.contains("raw-token"))
        XCTAssertTrue(review.isRedacted)

        let legacyArtifact = ClawGatewayArtifact(
            kind: .auditLog,
            title: "task-replay-guard.json",
            reference: "file:///tmp/legacy-task-replay-guard.json",
            isRedacted: true
        )
        let legacyReview = try XCTUnwrap(ClawGatewayTaskReplayGuardReviewSummary.latest(from: [legacyArtifact]))
        XCTAssertFalse(legacyReview.hasMetadata)
        XCTAssertTrue(legacyReview.compactStatus.contains("metadata"))

        let unrelatedAuditArtifact = ClawGatewayArtifact(
            kind: .auditLog,
            title: "other-audit.json",
            reference: "file:///tmp/other-audit.json",
            isRedacted: true,
            metadata: ["replayGuard": "notReplayGuard"]
        )
        XCTAssertNil(ClawGatewayTaskReplayGuardReviewSummary.latest(from: [unrelatedAuditArtifact]))

        let sensitiveArtifact = ClawGatewayArtifact(
            kind: .auditLog,
            title: "task-replay-guard.json",
            reference: "file:///tmp/sensitive-task-replay-guard.json",
            isRedacted: true,
            metadata: [
                "replayGuard": "taskReplayGuard",
                "decision": "skip Authorization: Bearer raw-token",
                "originalStatus": "completed file:///tmp/private.txt",
                "actionKinds": "controlBrowser,token=raw-token",
                "safetyFlags": "headers={Authorization: Bearer raw-token},workspace=/private/tmp/claw-work"
            ]
        )
        let sensitiveReview = try XCTUnwrap(ClawGatewayTaskReplayGuardReviewSummary.latest(from: [sensitiveArtifact]))
        let visibleReplayText = [
            sensitiveReview.compactStatus,
            sensitiveReview.actionKinds.joined(separator: " "),
            sensitiveReview.safetyFlags.joined(separator: " ")
        ].joined(separator: " ")
        XCTAssertFalse(visibleReplayText.contains("Authorization"))
        XCTAssertFalse(visibleReplayText.contains("Bearer"))
        XCTAssertFalse(visibleReplayText.contains("raw-token"))
        XCTAssertFalse(visibleReplayText.contains("file://"))
        XCTAssertFalse(visibleReplayText.contains("/private"))
        XCTAssertFalse(visibleReplayText.contains("workspace=/"))
    }

    func testMissionRunSummaryDerivesGatewayTaskReplayGuardReview() throws {
        let store = ClawStore(autoScanLocalArtifacts: false)

        store.gatewayDispatchMode = .liveGateway
        store.setGateway(url: "ws://127.0.0.1:18789", token: "paired-secret")
        store.phoneAgentCommand = "打开浏览器搜索资料"
        store.generatePhoneAgentPlan()
        store.queueClawMobileTaskFromCurrentPlan()
        store.approveLatestClawMobileTask()
        store.sendLatestClawMobileTask()

        let sessionID = try XCTUnwrap(store.clawGatewaySessions.first?.id)
        let task = try XCTUnwrap(store.clawMobileTasks.first)
        let replayArtifact = ClawGatewayArtifact(
            kind: .auditLog,
            title: "task-replay-guard.json",
            reference: "file:///private/tmp/claw/session/task-replay-guard.json",
            isRedacted: true,
            metadata: [
                "replayGuard": "taskReplayGuard",
                "decision": "skip-duplicate-task",
                "taskID": task.id.uuidString,
                "replayDigest": "sha256:abcdef1234567890",
                "digestMatchesFirst": "true",
                "firstSessionID": UUID().uuidString,
                "originalStatus": "completed",
                "replayCount": "1",
                "actionCount": "\(task.actions.count)",
                "actionKinds": task.actions.map(\.kind.rawValue).joined(separator: ","),
                "safetyFlags": "process-local,actions-skipped,business-artifacts-not-written"
            ]
        )
        var replayEvents = [
            ClawGatewayEvent(
                sessionID: sessionID,
                taskID: task.id,
                sequence: 2,
                kind: .gatewayConnected,
                summary: "Gateway replay guard recognized duplicate task"
            ),
            ClawGatewayEvent(
                sessionID: sessionID,
                taskID: task.id,
                sequence: 3,
                kind: .artifactStored,
                summary: "Stored Gateway task replay guard audit artifact",
                artifacts: [replayArtifact]
            )
        ]
        replayEvents.append(contentsOf: task.actions.enumerated().map { index, action in
            ClawGatewayEvent(
                sessionID: sessionID,
                taskID: task.id,
                sequence: 4 + index,
                kind: .actionSkipped,
                actionID: action.id,
                actionKind: action.kind,
                actionTitle: action.title,
                resultStatus: .skipped,
                summary: "\(action.title) skipped by Gateway replay guard"
            )
        })
        replayEvents.append(
            ClawGatewayEvent(
                sessionID: sessionID,
                taskID: task.id,
                sequence: 4 + task.actions.count,
                kind: .sessionCompleted,
                summary: "Gateway replay guard completed without re-running actions"
            )
        )

        store.ingestGatewayEvents(replayEvents)

        let review = try XCTUnwrap(store.missionRunSummary.gatewayTaskReplayGuardReview)
        XCTAssertEqual(review.replayCount, 1)
        XCTAssertEqual(review.actionCount, task.actions.count)
        XCTAssertTrue(review.digestMatchesFirst == true)
        XCTAssertEqual(store.clawGatewaySessions[0].sessionArtifacts.first?.title, "task-replay-guard.json")
        XCTAssertTrue(store.clawGatewaySessions[0].results.allSatisfy { $0.status == .skipped })
        XCTAssertTrue(store.missionRunSummary.statusLine.contains("Replay Guard"))
        XCTAssertFalse(store.missionRunSummary.statusLine.contains("file://"))
        XCTAssertFalse(store.missionRunSummary.statusLine.contains("paired-secret"))
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

        let replayArtifact = ClawGatewayArtifact(
            kind: .auditLog,
            title: "task-replay-guard.json",
            reference: "file:///tmp/task-replay-guard.json",
            isRedacted: true,
            metadata: ["replayGuard": "taskReplayGuard"]
        )
        let replayArtifactEvent = ClawGatewayEvent(
            sessionID: sessionID,
            taskID: taskID,
            sequence: 4,
            kind: .artifactStored,
            summary: "Stored replay guard artifact",
            artifacts: [replayArtifact]
        )

        let replayReduced = ClawGatewayEventStream.apply(event: replayArtifactEvent, to: actionReduced)

        XCTAssertEqual(replayReduced.sessionArtifacts.count, 2)
        XCTAssertEqual(replayReduced.results.count, 1)
        XCTAssertNotNil(ClawGatewayTaskReplayGuardReviewSummary.latest(from: replayReduced))
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
        let fileResult = session.results.first { $0.actionKind == .manageFiles }
        XCTAssertTrue(fileResult?.artifacts.contains { $0.kind == .fileDiff } == true)
        XCTAssertEqual(ClawGatewayFileChangeSafetyReviewSummary.latest(from: fileResult?.artifacts ?? [])?.writeSucceeded, true)
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
