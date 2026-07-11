import Foundation

@main
enum LogicSmoke {
    @MainActor
    static func main() {
        var failures: [String] = []

        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            if condition() == false {
                failures.append(message)
            }
        }

        let store = ClawStore(autoScanLocalArtifacts: false)
        expect(store.model.name == "Claw Local Agent 1.5B", "default model name should match Claw local agent")
        expect(store.model.installState == .placeholder, "model should start as placeholder")
        expect(store.model.artifactManifest.allowsNetworkDownload == false, "model must not download weights")
        expect(store.validation.availability == .missing, "default artifacts should be missing")
        expect(store.skills.count >= 6, "skill library should contain computer control capabilities")
        expect(store.documents.count >= 3, "context library should contain local examples")
        expect(store.automationTargets.contains { $0.channel == .clawGateway }, "automation center should include Claw gateway")
        expect(store.phoneAgentCapabilities.contains { $0.surface == .appIntents }, "phone agent should expose App Intents")
        expect(store.phoneAgentCapabilities.contains { $0.surface == .composeController }, "phone agent should include compose UI gates")
        expect(store.phoneAgentCapabilities.contains { $0.surface == .unavailable }, "phone agent should encode blocked iOS actions")

        let staged = LocalArtifactValidator.validate(
            manifest: store.model.artifactManifest,
            presentFiles: Set(store.model.artifactManifest.requiredFiles)
        )
        expect(staged.availability == .staged, "manual files without trusted hash should be staged")
        expect(staged.canRunRealWeights == false, "staged files must not enable real runtime")

        store.stageManualImportPreview()
        expect(store.validation.availability == .staged, "preview should stage artifacts")
        expect(store.model.installState == .staged, "preview should update model state")

        store.selectedCategory = .browser
        expect(store.visibleSkills.allSatisfy { $0.category == .browser }, "category filter should only show browser skills")

        if let skill = store.visibleSkills.first {
            store.selectSkill(skill)
        }
        store.query = "打开浏览器搜索竞品价格并整理表格"
        let before = store.messages.count
        store.submitCurrentQuery()
        expect(store.messages.count == before + 2, "chat submit should append user and assistant messages")
        expect(store.messages.last?.text.contains("模拟") == true, "assistant output should be simulated")

        if let claw = store.automationTargets.first(where: { $0.channel == .clawGateway }) {
            store.setGateway(url: "ws://127.0.0.1:18789", token: "token")
            store.draftAutomationPayload(for: claw)
            expect(store.lastAutomationDraft.contains("Claw 网关"), "payload should mention Claw gateway")
            expect(store.lastAutomationDraft.contains("ws://127.0.0.1:18789"), "payload should include gateway URL")
        } else {
            failures.append("missing Claw target")
        }

        store.phoneAgentCommand = "读取微信新消息并自动回复客户"
        store.generatePhoneAgentPlan()
        expect(store.phoneAgentPlan.steps.contains { $0.runMode == .blockedByIOS }, "third-party inbox reading should be blocked")
        expect(store.phoneAgentPlan.steps.contains { $0.runMode == .gatewayOnly }, "third-party app automation should route to gateway")

        store.phoneAgentCommand = "接管我的电脑，打开浏览器搜索竞品信息，整理成表格后发到 Slack"
        store.generatePhoneAgentPlan()
        store.simulatePhoneAgentExecution()
        expect(store.phoneAgentPlan.steps.contains { $0.title == "控制桌面浏览器" }, "computer control should include browser control")
        expect(store.phoneAgentPlan.steps.contains { $0.title == "操作桌面应用" }, "computer control should include desktop app operation")
        expect(store.phoneAgentPlan.confirmationCount > 0, "computer takeover should require confirmation")
        expect(store.phoneAgentExecutionLog.contains("WAIT_CONFIRM"), "execution log should expose confirmation gates")

        store.queueClawMobileTaskFromCurrentPlan()
        expect(store.clawMobileTasks.isEmpty == false, "Claw mobile task should be queued")
        expect(store.clawMobileTasks[0].actions.contains { $0.kind == .controlBrowser }, "Claw task should include browser control")
        expect(
            store.clawMobileTasks[0].actions.contains {
                $0.kind == .controlBrowser &&
                $0.toolArguments["browserApp"] == "Safari" &&
                $0.toolArguments["openInBrowser"] == "true" &&
                $0.toolArguments["searchQuery"] == store.phoneAgentCommand
            },
            "browser control should include desktop browser app, open flag, and search query"
        )
        expect(store.clawMobileTasks[0].actions.contains { $0.kind == .operateDesktopApp }, "Claw task should include desktop app operation")
        expect(
            store.clawMobileTasks[0].actions.contains {
                $0.kind == .operateDesktopApp &&
                $0.toolArguments["draftText"]?.contains("Claw prepared result") == true &&
                $0.toolArguments["keySequence"] == "command+k,return" &&
                $0.toolArguments["finalSubmitRequiresApproval"] == "true"
            },
            "desktop app operation should include structured draft, safe keys, and final submit gate"
        )
        expect(store.clawMobileTasks[0].actions.contains { $0.kind == .composeMessage }, "Claw task should include message composition")
        expect(store.clawMobileTasks[0].approvalCount > 0, "computer takeover should include approval gates")
        expect(store.lastClawMobileEnvelope.contains("claw.computer.control.v1"), "Claw envelope should include computer-control schema version")
        expect(store.lastClawMobileEnvelope.contains("token") == false || store.lastClawMobileEnvelope.contains("tokenFingerprint"), "Claw envelope should avoid raw token fields")
        store.approveLatestClawMobileTask()
        store.simulateSendLatestClawMobileTask()
        expect(store.clawGatewaySessions.isEmpty == false, "sending should create a gateway session")
        expect(store.clawGatewaySessions[0].artifactCount > 0, "gateway session should include artifacts")
        expect(store.gatewayEvents.contains { $0.kind == .sessionCompleted }, "gateway event stream should complete")

        let missionStore = ClawStore(autoScanLocalArtifacts: false)
        expect(missionStore.missionRunSummary.primaryActionKind == .start, "mission summary should start with a launch action")
        expect(missionStore.missionRunSummary.reviewPriorityQueue.isEmpty, "idle mission summary should not invent review priorities")
        let idleReadiness = missionStore.missionRunSummary.reviewReadinessSummary
        expect(idleReadiness.totalPriorityCount == 0, "idle readiness should not count review priorities")
        expect(idleReadiness.actionablePriorityCount == 0, "idle readiness should not count actions")
        expect(idleReadiness.criticalOrHighCount == 0, "idle readiness should not count high priorities")
        expect(idleReadiness.metadataPendingCount == 0, "idle readiness should not count metadata gaps")
        expect(idleReadiness.topReviewKind == nil, "idle readiness should not invent a top review")
        expect(idleReadiness.isReviewable == false, "idle readiness should not be reviewable")
        expect(idleReadiness.requiresHumanAction == false, "idle readiness should not require action")
        let idleNextAction = missionStore.missionRunSummary.nextReviewAction
        expect(idleNextAction.isReviewable == false, "idle next review action should not be reviewable")
        expect(idleNextAction.requiresHumanAction == false, "idle next review action should not require action")
        expect(idleNextAction.reviewKind == nil, "idle next review action should not invent a review kind")
        let idleEvidence = missionStore.missionRunSummary.artifactEvidenceIndex
        expect(idleEvidence.artifactKindCount == 0, "idle evidence index should not count artifact kinds")
        expect(idleEvidence.metadataArtifactCount == 0, "idle evidence index should not count metadata artifacts")
        expect(idleEvidence.redactedArtifactCount == 0, "idle evidence index should not count redacted artifacts")
        expect(idleEvidence.coveredReviewCount == 0, "idle evidence index should not invent coverage")
        expect(idleEvidence.focusedHasEvidence == false, "idle evidence index should not mark focused evidence")
        let idleOperatorStrip = missionStore.missionRunSummary.operatorStrip
        expect(idleOperatorStrip.lanes.map(\.id) == ["gateway", "evidence", "review", "next"], "idle operator strip should expose stable lanes")
        expect(idleOperatorStrip.focusedReviewKind == nil, "idle operator strip should not invent focus")
        expect(idleOperatorStrip.lanes.allSatisfy { $0.canFocusReview == false }, "idle operator strip should not expose focus buttons")
        expect(
            idleOperatorStrip.lanes.contains { $0.id == "evidence" && $0.status == "0/0 类覆盖" },
            "idle operator strip should not invent evidence coverage"
        )
        let idleEvidenceTrail = missionStore.missionRunSummary.evidenceTrailSummary
        expect(idleEvidenceTrail.isReviewable == false, "idle evidence trail should not be reviewable")
        expect(idleEvidenceTrail.canFocusPrimaryReview == false, "idle evidence trail should not expose primary focus")
        expect(idleEvidenceTrail.primaryReviewKind == nil, "idle evidence trail should not invent primary review")
        expect(idleEvidenceTrail.steps.map(\.id) == ["evidence", "metadata", "priority", "next"], "idle evidence trail should expose stable steps")
        expect(idleEvidenceTrail.steps.allSatisfy { $0.canFocusReview == false }, "idle evidence trail should not expose focus buttons")
        let idleFocusContext = missionStore.missionRunSummary.focusContextSummary
        expect(idleFocusContext.isReviewable == false, "idle focus context should not be reviewable")
        expect(idleFocusContext.canClearFocus == false, "idle focus context should not expose clear focus")
        expect(idleFocusContext.primaryReviewKind == nil, "idle focus context should not invent a primary review")
        let idleDetailDock = missionStore.missionRunSummary.reviewDetailDockSummary
        expect(idleDetailDock.isReviewable == false, "idle detail dock should not be reviewable")
        expect(idleDetailDock.canClearFocus == false, "idle detail dock should not expose clear focus")
        expect(idleDetailDock.detailReviewKinds.isEmpty, "idle detail dock should not invent detail rows")
        let idleApprovalQueue = missionStore.missionRunSummary.approvalQueueSummary
        expect(idleApprovalQueue.isReviewable == false, "idle approval queue should not be reviewable")
        expect(idleApprovalQueue.totalCount == 0, "idle approval queue should not count items")
        expect(idleApprovalQueue.actionableCount == 0, "idle approval queue should not count actions")
        expect(idleApprovalQueue.criticalOrHighCount == 0, "idle approval queue should not count high priority items")
        expect(idleApprovalQueue.metadataPendingCount == 0, "idle approval queue should not count metadata gaps")
        expect(idleApprovalQueue.primaryReviewKind == nil, "idle approval queue should not invent primary focus")
        let idleApprovalFastLane = missionStore.missionRunSummary.approvalFastLane
        expect(idleApprovalFastLane.isReviewable == false, "idle approval fast lane should not be reviewable")
        expect(idleApprovalFastLane.laneState == "idle", "idle approval fast lane should expose idle")
        expect(idleApprovalFastLane.requiresHumanAction == false, "idle approval fast lane should not require human")
        expect(idleApprovalFastLane.primaryReviewKind == nil, "idle approval fast lane should not invent focus")
        let idlePayloadLedger = missionStore.missionRunSummary.payloadSafetyLedger
        expect(idlePayloadLedger.isReviewable == false, "idle payload ledger should not be reviewable")
        expect(idlePayloadLedger.totalCount == 0, "idle payload ledger should not count items")
        expect(idlePayloadLedger.payloadNotReadCount == 0, "idle payload ledger should not count payload flags")
        expect(idlePayloadLedger.metadataOnlyCount == 0, "idle payload ledger should not count metadata-only flags")
        expect(idlePayloadLedger.omissionSignalCount == 0, "idle payload ledger should not count omission signals")
        expect(idlePayloadLedger.metadataPendingCount == 0, "idle payload ledger should not count metadata gaps")
        expect(idlePayloadLedger.primaryReviewKind == nil, "idle payload ledger should not invent primary focus")
        let idleMacReadiness = missionStore.missionRunSummary.macAgentReadinessBoard
        expect(idleMacReadiness.isReviewable == false, "idle mac readiness should not be reviewable")
        expect(idleMacReadiness.items.map(\.id) == ["connection", "capability", "observation", "loop", "human-gate"], "idle mac readiness should expose stable rows")
        expect(idleMacReadiness.readyCount == 0, "idle mac readiness should not count ready rows")
        expect(idleMacReadiness.blockedCount == 0, "idle mac readiness should not count blockers")
        expect(idleMacReadiness.metadataPendingCount == 0, "idle mac readiness should not count metadata gaps")
        expect(idleMacReadiness.humanActionCount == 0, "idle mac readiness should not require human action")
        expect(idleMacReadiness.primaryReviewKind == nil, "idle mac readiness should not invent primary focus")
        let idleActionPreflight = missionStore.missionRunSummary.macGatewayActionPreflightMatrix
        expect(idleActionPreflight.isReviewable == false, "idle action preflight should not be reviewable")
        expect(idleActionPreflight.totalCount == 0, "idle action preflight should not count actions")
        expect(idleActionPreflight.readyCount == 0, "idle action preflight should not count ready actions")
        expect(idleActionPreflight.blockedCount == 0, "idle action preflight should not count blockers")
        expect(idleActionPreflight.humanActionCount == 0, "idle action preflight should not require human action")
        expect(idleActionPreflight.primaryReviewKind == nil, "idle action preflight should not invent primary focus")
        let idleEvidenceCoverage = missionStore.missionRunSummary.macAgentEvidenceCoverageMap
        expect(idleEvidenceCoverage.isReviewable == false, "idle evidence coverage should not be reviewable")
        expect(idleEvidenceCoverage.totalCount == 0, "idle evidence coverage should not count rows")
        expect(idleEvidenceCoverage.actionSupportedCount == 0, "idle evidence coverage should not count action support")
        expect(idleEvidenceCoverage.evidenceCoveredCount == 0, "idle evidence coverage should not count evidence")
        expect(idleEvidenceCoverage.metadataPendingCount == 0, "idle evidence coverage should not count metadata gaps")
        expect(idleEvidenceCoverage.primaryReviewKind == nil, "idle evidence coverage should not invent primary focus")
        let idleNextStepDeck = missionStore.missionRunSummary.macAgentNextStepDeck
        expect(idleNextStepDeck.isReviewable == false, "idle next step deck should not be reviewable")
        expect(idleNextStepDeck.totalCount == 0, "idle next step deck should not invent candidates")
        expect(idleNextStepDeck.candidates.isEmpty, "idle next step deck should have no candidate rows")
        expect(idleNextStepDeck.primaryReviewKind == nil, "idle next step deck should not invent primary focus")
        expect(idleNextStepDeck.focusedReviewKind == nil, "idle next step deck should not invent focused review")
        let idleRunTimeline = missionStore.missionRunSummary.macAgentRunTimeline
        expect(idleRunTimeline.isReviewable == false, "idle run timeline should not be reviewable")
        expect(idleRunTimeline.totalCount == 0, "idle run timeline should not count steps")
        expect(idleRunTimeline.actionStepCount == 0, "idle run timeline should not count actions")
        expect(idleRunTimeline.completedCount == 0, "idle run timeline should not count completed steps")
        expect(idleRunTimeline.metadataPendingCount == 0, "idle run timeline should not count metadata gaps")
        expect(idleRunTimeline.primaryReviewKind == nil, "idle run timeline should not invent primary focus")
        let idleContinuationGate = missionStore.missionRunSummary.macAgentContinuationGate
        expect(idleContinuationGate.isReviewable == false, "idle continuation gate should not be reviewable")
        expect(idleContinuationGate.totalCount == 0, "idle continuation gate should not count rows")
        expect(idleContinuationGate.readyCount == 0, "idle continuation gate should not count ready rows")
        expect(idleContinuationGate.blockedCount == 0, "idle continuation gate should not count blockers")
        expect(idleContinuationGate.humanActionCount == 0, "idle continuation gate should not require human action")
        expect(idleContinuationGate.primaryReviewKind == nil, "idle continuation gate should not invent primary focus")
        let idleReviewRadar = missionStore.missionRunSummary.macAgentReviewRadar
        expect(idleReviewRadar.isReviewable == false, "idle review radar should not be reviewable")
        expect(idleReviewRadar.totalCount == 0, "idle review radar should not count sectors")
        expect(idleReviewRadar.priorityCount == 0, "idle review radar should not count priority signals")
        expect(idleReviewRadar.metadataPendingCount == 0, "idle review radar should not count metadata gaps")
        expect(idleReviewRadar.primaryReviewKind == nil, "idle review radar should not invent primary focus")
        let idleHandoffBrief = missionStore.missionRunSummary.macAgentHandoffBrief
        expect(idleHandoffBrief.isReviewable == false, "idle handoff brief should not be reviewable")
        expect(idleHandoffBrief.totalCount == 0, "idle handoff brief should not count items")
        expect(idleHandoffBrief.blockedCount == 0, "idle handoff brief should not count blockers")
        expect(idleHandoffBrief.metadataPendingCount == 0, "idle handoff brief should not count metadata gaps")
        expect(idleHandoffBrief.primaryReviewKind == nil, "idle handoff brief should not invent primary focus")
        let idleControlSnapshot = missionStore.missionRunSummary.controlSnapshot
        expect(idleControlSnapshot.isReviewable == false, "idle control snapshot should not be reviewable")
        expect(idleControlSnapshot.controlState == "idle", "idle control snapshot should expose idle state")
        expect(idleControlSnapshot.canContinueLoop == false, "idle control snapshot should not continue")
        expect(idleControlSnapshot.primaryReviewKind == nil, "idle control snapshot should not invent focus")
        expect(missionStore.missionRunSummary.activeReviewFocus(from: "delivery-safety") == nil, "idle active focus should not resolve")
        missionStore.phoneAgentCommand = "打开浏览器搜索资料，整理结果并发到 Slack"
        missionStore.startAutonomousComputerTakeover()
        var missionSummary = missionStore.missionRunSummary
        expect(missionSummary.primaryActionKind == .approveAndContinue, "mission summary should stop at approval gate")
        expect(missionSummary.requiresUserApproval, "mission summary should surface approval requirements")
        expect(missionSummary.riskScore > 0, "mission summary should include task risk")
        let preSendApprovalQueue = missionSummary.approvalQueueSummary
        expect(preSendApprovalQueue.isReviewable, "pre-send approval queue should be reviewable")
        expect(preSendApprovalQueue.requiresHumanAction, "pre-send approval queue should require human action")
        expect(preSendApprovalQueue.primaryReviewKind == "approval", "pre-send approval queue should target approval")
        expect(preSendApprovalQueue.canFocusPrimaryReview, "pre-send approval queue should focus approval status")
        expect(preSendApprovalQueue.totalCount > 0, "pre-send approval queue should count approval items")
        expect(preSendApprovalQueue.actionableCount > 0, "pre-send approval queue should count actionable approvals")
        expect(
            preSendApprovalQueue.items.contains { $0.reviewKind == "approval" && $0.isActionable && $0.canFocusReview },
            "pre-send approval queue should include actionable approval rows"
        )
        let focusedPreSendApprovalQueue = missionSummary.approvalQueueSummary(focusedOn: "approval")
        expect(focusedPreSendApprovalQueue.focusedReviewKind == "approval", "approval queue should focus approval status")
        expect(
            focusedPreSendApprovalQueue.items.contains { $0.reviewKind == "approval" && $0.isFocused },
            "focused approval queue should mark approval row"
        )
        let preSendApprovalFastLane = missionSummary.approvalFastLane
        expect(preSendApprovalFastLane.isReviewable, "pre-send approval fast lane should be reviewable")
        expect(preSendApprovalFastLane.laneState == "waiting-human", "pre-send approval fast lane should wait for human")
        expect(preSendApprovalFastLane.requiresHumanAction, "pre-send approval fast lane should require human")
        expect(preSendApprovalFastLane.primaryReviewKind == "approval", "pre-send approval fast lane should target approval")
        expect(preSendApprovalFastLane.canFocusPrimaryReview, "pre-send approval fast lane should focus approval")
        expect(preSendApprovalFastLane.checklist.contains("人工确认"), "pre-send approval fast lane should include human checklist")
        let focusedPreSendApprovalFastLane = missionSummary.approvalFastLane(focusedOn: "approval")
        expect(focusedPreSendApprovalFastLane.laneState == "focused", "focused pre-send approval fast lane should show focus")
        expect(focusedPreSendApprovalFastLane.primaryReviewKind == "approval", "focused pre-send approval fast lane should keep approval")
        let preSendActionPreflight = missionSummary.macGatewayActionPreflightMatrix
        expect(preSendActionPreflight.isReviewable, "pre-send action preflight should be reviewable")
        expect(preSendActionPreflight.totalCount == missionSummary.actionPreflightItems.count, "pre-send action preflight should mirror action rows")
        expect(preSendActionPreflight.items.map(\.rank) == preSendActionPreflight.items.map(\.rank).sorted(), "pre-send action preflight should preserve action order")
        expect(preSendActionPreflight.humanActionCount > 0, "pre-send action preflight should surface human gates")
        expect(preSendActionPreflight.requiresHumanAction, "pre-send action preflight should require human action")
        expect(
            preSendActionPreflight.items.contains { $0.reviewKind == "approval" && $0.canFocusReview && $0.requiresHumanAction },
            "pre-send action preflight should expose approval focus rows"
        )
        let focusedPreSendActionPreflight = missionSummary.macGatewayActionPreflightMatrix(focusedOn: "approval")
        expect(focusedPreSendActionPreflight.focusedReviewKind == "approval", "pre-send action preflight should focus approval")
        expect(
            focusedPreSendActionPreflight.items.contains { $0.reviewKind == "approval" && $0.isFocused },
            "focused pre-send action preflight should mark approval row"
        )
        let preSendEvidenceCoverage = missionSummary.macAgentEvidenceCoverageMap
        expect(preSendEvidenceCoverage.isReviewable, "pre-send evidence coverage should be reviewable")
        expect(preSendEvidenceCoverage.actionSupportedCount > 0, "pre-send evidence coverage should count action support")
        expect(preSendEvidenceCoverage.requiresHumanAction, "pre-send evidence coverage should require human review")
        expect(preSendEvidenceCoverage.items.contains { $0.reviewKind == "approval" && $0.hasActionSupport && $0.requiresHumanAction }, "pre-send evidence coverage should expose approval support")
        let focusedPreSendEvidenceCoverage = missionSummary.macAgentEvidenceCoverageMap(focusedOn: "approval")
        expect(focusedPreSendEvidenceCoverage.focusedReviewKind == "approval", "pre-send evidence coverage should focus approval")
        expect(
            focusedPreSendEvidenceCoverage.items.contains { $0.reviewKind == "approval" && $0.isFocused },
            "focused pre-send evidence coverage should mark approval row"
        )
        let preSendNextStepDeck = missionSummary.macAgentNextStepDeck
        expect(preSendNextStepDeck.isReviewable, "pre-send next step deck should be reviewable")
        expect(preSendNextStepDeck.requiresHumanAction, "pre-send next step deck should require human action")
        expect(preSendNextStepDeck.primaryReviewKind == "approval", "pre-send next step deck should target approval")
        expect(preSendNextStepDeck.canFocusPrimaryReview, "pre-send next step deck should focus approval")
        expect(
            preSendNextStepDeck.candidates.contains { $0.id == "human-confirmation" && $0.reviewKind == "approval" && $0.requiresHumanAction },
            "pre-send next step deck should include approval candidate"
        )
        expect(
            preSendNextStepDeck.candidates.contains { $0.id == "evidence-fill" && $0.canContinueLoop == false },
            "pre-send next step deck should include evidence wait candidate"
        )
        let focusedPreSendNextStepDeck = missionSummary.macAgentNextStepDeck(focusedOn: "approval")
        expect(focusedPreSendNextStepDeck.focusedReviewKind == "approval", "pre-send next step deck should focus approval")
        expect(
            focusedPreSendNextStepDeck.candidates.contains { $0.reviewKind == "approval" && $0.isFocused },
            "focused pre-send next step deck should mark approval row"
        )
        let preSendRunTimeline = missionSummary.macAgentRunTimeline
        expect(preSendRunTimeline.isReviewable, "pre-send run timeline should be reviewable")
        expect(preSendRunTimeline.actionStepCount == missionSummary.actionPreflightItems.count, "pre-send run timeline should mirror action rows")
        expect(preSendRunTimeline.humanActionCount > 0, "pre-send run timeline should surface human gates")
        expect(preSendRunTimeline.requiresHumanAction, "pre-send run timeline should require human action")
        expect(
            preSendRunTimeline.steps.contains { $0.reviewKind == "approval" && $0.requiresHumanAction && $0.hasResult == false },
            "pre-send run timeline should include approval action step"
        )
        let focusedPreSendRunTimeline = missionSummary.macAgentRunTimeline(focusedOn: "approval")
        expect(focusedPreSendRunTimeline.focusedReviewKind == "approval", "pre-send run timeline should focus approval")
        expect(
            focusedPreSendRunTimeline.steps.contains { $0.reviewKind == "approval" && $0.isFocused },
            "focused pre-send run timeline should mark approval row"
        )
        let preSendContinuationGate = missionSummary.macAgentContinuationGate
        expect(preSendContinuationGate.isReviewable, "pre-send continuation gate should be reviewable")
        expect(preSendContinuationGate.requiresHumanAction, "pre-send continuation gate should require human action")
        expect(preSendContinuationGate.primaryReviewKind == "approval", "pre-send continuation gate should target approval")
        expect(preSendContinuationGate.canFocusPrimaryReview, "pre-send continuation gate should focus approval")
        expect(
            preSendContinuationGate.items.contains { $0.id == "human-confirmation" && $0.reviewKind == "approval" && $0.requiresHumanAction },
            "pre-send continuation gate should include approval gate"
        )
        let focusedPreSendContinuationGate = missionSummary.macAgentContinuationGate(focusedOn: "approval")
        expect(focusedPreSendContinuationGate.focusedReviewKind == "approval", "pre-send continuation gate should focus approval")
        expect(
            focusedPreSendContinuationGate.items.contains { $0.reviewKind == "approval" && $0.isFocused },
            "focused pre-send continuation gate should mark approval row"
        )
        let preSendReviewRadar = missionSummary.macAgentReviewRadar
        expect(preSendReviewRadar.isReviewable, "pre-send review radar should be reviewable")
        expect(preSendReviewRadar.totalCount == 5, "pre-send review radar should expose fixed sectors")
        expect(preSendReviewRadar.requiresHumanAction, "pre-send review radar should require human action")
        expect(preSendReviewRadar.primaryReviewKind == "approval", "pre-send review radar should target approval")
        expect(
            preSendReviewRadar.sectors.contains { $0.id == "human-handoff" && $0.reviewKind == "approval" && $0.humanActionCount > 0 },
            "pre-send review radar should include approval sector"
        )
        let focusedPreSendReviewRadar = missionSummary.macAgentReviewRadar(focusedOn: "approval")
        expect(focusedPreSendReviewRadar.focusedReviewKind == "approval", "pre-send review radar should focus approval")
        expect(
            focusedPreSendReviewRadar.sectors.contains { $0.reviewKind == "approval" && $0.isFocused },
            "focused pre-send review radar should mark approval sector"
        )
        let preSendHandoffBrief = missionSummary.macAgentHandoffBrief
        expect(preSendHandoffBrief.isReviewable, "pre-send handoff brief should be reviewable")
        expect(preSendHandoffBrief.totalCount == 5, "pre-send handoff brief should expose fixed items")
        expect(preSendHandoffBrief.requiresHumanAction, "pre-send handoff brief should require human action")
        expect(preSendHandoffBrief.primaryReviewKind == "approval", "pre-send handoff brief should target approval")
        expect(
            preSendHandoffBrief.items.contains { $0.id == "human-confirmation" && $0.reviewKind == "approval" && $0.requiresHumanAction },
            "pre-send handoff brief should include approval item"
        )
        let focusedPreSendHandoffBrief = missionSummary.macAgentHandoffBrief(focusedOn: "approval")
        expect(focusedPreSendHandoffBrief.focusedReviewKind == "approval", "pre-send handoff brief should focus approval")
        expect(
            focusedPreSendHandoffBrief.items.contains { $0.reviewKind == "approval" && $0.isFocused },
            "focused pre-send handoff brief should mark approval item"
        )
        let preSendControlSnapshot = missionSummary.controlSnapshot
        expect(preSendControlSnapshot.isReviewable, "pre-send control snapshot should be reviewable")
        expect(preSendControlSnapshot.controlState == "waiting-human", "pre-send control snapshot should wait for human")
        expect(preSendControlSnapshot.requiresHumanAction, "pre-send control snapshot should require approval")
        expect(preSendControlSnapshot.primaryReviewKind == "approval", "pre-send control snapshot should focus approval")
        expect(preSendControlSnapshot.canFocusPrimaryReview, "pre-send control snapshot should allow approval focus")
        let focusedPreSendControlSnapshot = missionSummary.controlSnapshot(focusedOn: "approval")
        expect(focusedPreSendControlSnapshot.controlState == "focused", "focused pre-send control snapshot should show focus")
        expect(focusedPreSendControlSnapshot.focusedReviewKind == "approval", "focused pre-send control snapshot should record approval")
        expect(focusedPreSendControlSnapshot.primaryReviewKind == "approval", "focused pre-send control snapshot should keep approval primary")
        missionStore.approveAndContinueAutonomousLoop()
        missionSummary = missionStore.missionRunSummary
        expect(missionSummary.primaryActionKind == .continueAfterReview, "mission summary should expose review action")
        expect(missionSummary.artifactCount > 0, "mission summary should count gateway artifacts")
        expect(missionSummary.artifactKinds.contains(.browserTrace), "mission summary should summarize artifact kinds")
        expect(missionSummary.artifactKinds.contains(.auditLog), "mission summary should include session-level audit artifacts")
        expect(missionSummary.reviewPriorityQueue.isEmpty == false, "mission summary should derive review priority queue")
        expect(
            missionSummary.reviewPriorityQueue.map(\.rank) == missionSummary.reviewPriorityQueue.map(\.rank).sorted(),
            "review priority queue should be rank sorted"
        )
        expect(
            missionSummary.reviewPriorityQueue.contains { $0.reviewKind == "delivery-safety" && ($0.severity == .high || $0.severity == .critical) },
            "review priority queue should prioritize delivery safety"
        )
        expect(
            missionSummary.reviewPriorityQueue.contains { $0.reviewKind == "file-change-safety" },
            "review priority queue should include file change safety"
        )
        let availableDetailKinds = missionSummary.availableDetailReviewKinds
        expect(availableDetailKinds.isEmpty == false, "mission summary should expose detail review kinds")
        let evidenceIndex = missionSummary.artifactEvidenceIndex
        expect(evidenceIndex.artifactKindCount == missionSummary.artifactKinds.count, "evidence index should count artifact kinds")
        expect(
            evidenceIndex.metadataArtifactCount == (missionSummary.artifactMetadataReview?.metadataArtifactCount ?? 0),
            "evidence index should reuse artifact metadata count"
        )
        expect(
            evidenceIndex.redactedArtifactCount == (missionSummary.artifactMetadataReview?.redactedArtifactCount ?? 0),
            "evidence index should reuse redacted artifact count"
        )
        expect(evidenceIndex.items.map(\.reviewKind) == availableDetailKinds, "evidence index should follow detail review order")
        expect(evidenceIndex.coveredReviewCount > 0, "evidence index should report covered review kinds")
        expect(
            evidenceIndex.items.contains { $0.reviewKind == "artifact-metadata" && $0.hasEvidence },
            "evidence index should cover artifact metadata"
        )
        expect(
            evidenceIndex.items.contains { $0.reviewKind == "browser-control" && $0.artifactKinds.contains(.browserTrace) },
            "evidence index should map browser review to browser trace"
        )
        expect(
            evidenceIndex.items.contains { $0.reviewKind == "delivery-safety" && $0.artifactKinds.contains(.messageDraft) },
            "evidence index should map delivery review to message draft"
        )
        let focusedEvidenceIndex = missionSummary.artifactEvidenceIndex(focusedOn: "delivery-safety")
        expect(focusedEvidenceIndex.focusedReviewKind == "delivery-safety", "evidence index should record focused review kind")
        expect(focusedEvidenceIndex.focusedReviewTitle == "最终提交安全", "evidence index should record focused review title")
        expect(focusedEvidenceIndex.focusedHasEvidence, "focused evidence index should mark delivery evidence")
        expect(
            focusedEvidenceIndex.items.contains { $0.reviewKind == "delivery-safety" && $0.isFocused },
            "evidence index should mark focused item"
        )
        let payloadLedger = missionSummary.payloadSafetyLedger
        expect(payloadLedger.isReviewable, "payload ledger should be reviewable once Gateway evidence exists")
        expect(payloadLedger.totalCount == availableDetailKinds.count, "payload ledger should mirror detail review count")
        expect(payloadLedger.payloadNotReadCount > 0, "payload ledger should count payload-not-read flags")
        expect(payloadLedger.metadataOnlyCount > 0, "payload ledger should count metadata-only flags")
        expect(payloadLedger.omissionSignalCount > 0, "payload ledger should count omission signals")
        expect(
            payloadLedger.metadataPendingCount == payloadLedger.items.filter { $0.hasMetadata == false }.count,
            "payload ledger should count metadata gaps"
        )
        expect(
            payloadLedger.items.contains { $0.reviewKind == "delivery-safety" && $0.payloadNotRead && $0.metadataOnly },
            "payload ledger should include delivery payload boundary"
        )
        expect(
            payloadLedger.items.contains { $0.reviewKind == "file-change-safety" && $0.safetyFlags.contains("file-content-omitted") },
            "payload ledger should include file content omission"
        )
        let focusedPayloadLedger = missionSummary.payloadSafetyLedger(focusedOn: "delivery-safety")
        expect(focusedPayloadLedger.focusedReviewKind == "delivery-safety", "payload ledger should record delivery focus")
        expect(focusedPayloadLedger.focusedReviewTitle == "最终提交安全", "payload ledger should expose delivery title")
        expect(
            focusedPayloadLedger.items.contains { $0.reviewKind == "delivery-safety" && $0.isFocused },
            "focused payload ledger should mark delivery row"
        )
        let macReadiness = missionSummary.macAgentReadinessBoard
        expect(macReadiness.isReviewable, "mac readiness should be reviewable once Gateway evidence exists")
        expect(macReadiness.items.map(\.id) == ["connection", "capability", "observation", "loop", "human-gate"], "mac readiness should expose stable rows")
        expect(macReadiness.readyCount > 0, "mac readiness should count ready rows")
        expect(macReadiness.humanActionCount > 0, "mac readiness should surface human gates")
        expect(macReadiness.requiresHumanAction, "mac readiness should require human review")
        expect(macReadiness.primaryReviewKind != nil, "mac readiness should point to a primary review")
        expect(
            macReadiness.items.contains { $0.id == "capability" && $0.reviewKind == "gateway-capability" && $0.canFocusReview },
            "mac readiness should expose gateway capability focus"
        )
        expect(
            macReadiness.items.contains { $0.id == "observation" && $0.reviewKind == "accessibility" && $0.canFocusReview },
            "mac readiness should expose accessibility focus"
        )
        expect(
            macReadiness.items.contains { $0.id == "loop" && $0.reviewKind == "agent-trace" && $0.canFocusReview },
            "mac readiness should expose agent trace focus"
        )
        let focusedMacReadiness = missionSummary.macAgentReadinessBoard(focusedOn: "delivery-safety")
        expect(focusedMacReadiness.focusedReviewKind == "delivery-safety", "mac readiness should record delivery focus")
        expect(focusedMacReadiness.focusedReviewTitle == "最终提交安全", "mac readiness should expose delivery focus title")
        expect(
            focusedMacReadiness.items.contains { $0.id == "human-gate" && $0.isFocused },
            "focused mac readiness should mark human gate row"
        )
        let actionPreflight = missionSummary.macGatewayActionPreflightMatrix
        expect(actionPreflight.isReviewable, "action preflight should be reviewable once task exists")
        expect(actionPreflight.totalCount == missionSummary.actionPreflightItems.count, "action preflight should mirror summary item count")
        expect(actionPreflight.items.map(\.rank) == actionPreflight.items.map(\.rank).sorted(), "action preflight should preserve action order")
        expect(actionPreflight.readyCount > 0, "action preflight should count ready actions")
        expect(actionPreflight.humanActionCount > 0, "action preflight should surface human gates")
        expect(actionPreflight.requiresHumanAction, "action preflight should require human review")
        expect(actionPreflight.primaryReviewKind != nil, "action preflight should point to a primary review")
        expect(
            actionPreflight.items.contains { $0.actionKindTitle == ClawMobileActionKind.controlBrowser.title && $0.reviewKind == "browser-control" },
            "action preflight should map browser action to browser review"
        )
        expect(
            actionPreflight.items.contains { $0.actionKindTitle == ClawMobileActionKind.runAgentLoop.title && $0.reviewKind == "agent-trace" },
            "action preflight should map agent loop action to trace review"
        )
        let focusedActionPreflight = missionSummary.macGatewayActionPreflightMatrix(focusedOn: "delivery-safety")
        expect(focusedActionPreflight.focusedReviewKind == "delivery-safety", "action preflight should record delivery focus")
        expect(focusedActionPreflight.focusedReviewTitle == "最终提交安全", "action preflight should expose delivery focus title")
        expect(
            focusedActionPreflight.items.contains { $0.reviewKind == "delivery-safety" && $0.isFocused },
            "focused action preflight should mark delivery row"
        )
        let evidenceCoverage = missionSummary.macAgentEvidenceCoverageMap
        expect(evidenceCoverage.isReviewable, "evidence coverage should be reviewable once task or Gateway evidence exists")
        expect(evidenceCoverage.totalCount >= availableDetailKinds.count, "evidence coverage should include detail review rows")
        expect(evidenceCoverage.actionSupportedCount > 0, "evidence coverage should count action-supported rows")
        expect(evidenceCoverage.evidenceCoveredCount == evidenceCoverage.items.filter(\.hasEvidence).count, "evidence coverage should count evidence rows")
        expect(evidenceCoverage.metadataReadyCount == evidenceCoverage.items.filter(\.hasMetadata).count, "evidence coverage should count metadata rows")
        expect(evidenceCoverage.payloadProtectedCount == evidenceCoverage.items.filter(\.payloadProtected).count, "evidence coverage should count payload-protected rows")
        expect(evidenceCoverage.requiresHumanAction, "evidence coverage should surface human review")
        expect(evidenceCoverage.primaryReviewKind != nil, "evidence coverage should point to a primary review")
        expect(
            evidenceCoverage.items.contains { $0.reviewKind == "browser-control" && $0.hasActionSupport && $0.hasEvidence },
            "evidence coverage should join browser action support with evidence"
        )
        expect(
            evidenceCoverage.items.contains { $0.reviewKind == "delivery-safety" && $0.hasEvidence && $0.payloadProtected },
            "evidence coverage should include delivery evidence and payload boundary"
        )
        let focusedEvidenceCoverage = missionSummary.macAgentEvidenceCoverageMap(focusedOn: "delivery-safety")
        expect(focusedEvidenceCoverage.focusedReviewKind == "delivery-safety", "evidence coverage should record delivery focus")
        expect(focusedEvidenceCoverage.focusedReviewTitle == "最终提交安全", "evidence coverage should expose delivery title")
        expect(
            focusedEvidenceCoverage.items.contains { $0.reviewKind == "delivery-safety" && $0.isFocused },
            "focused evidence coverage should mark delivery row"
        )
        let nextStepDeck = missionSummary.macAgentNextStepDeck
        expect(nextStepDeck.isReviewable, "next step deck should be reviewable once Gateway evidence exists")
        expect(nextStepDeck.totalCount > 0, "next step deck should expose candidates")
        expect(nextStepDeck.candidates.map(\.rank) == nextStepDeck.candidates.map(\.rank).sorted(), "next step deck should be rank sorted")
        expect(nextStepDeck.requiresHumanAction, "next step deck should surface human review")
        expect(
            nextStepDeck.candidates.contains { $0.id == "human-confirmation" && $0.requiresHumanAction },
            "next step deck should include human confirmation candidate"
        )
        expect(
            nextStepDeck.candidates.contains { $0.id == "loop-next" && $0.reviewKind == "agent-trace" },
            "next step deck should include loop candidate"
        )
        expect(nextStepDeck.primaryReviewKind != nil, "next step deck should expose a primary review")
        let focusedNextStepDeck = missionSummary.macAgentNextStepDeck(focusedOn: "delivery-safety")
        expect(focusedNextStepDeck.focusedReviewKind == "delivery-safety", "next step deck should record delivery focus")
        expect(focusedNextStepDeck.focusedReviewTitle == "最终提交安全", "next step deck should expose delivery title")
        expect(
            focusedNextStepDeck.candidates.contains { $0.reviewKind == "delivery-safety" && $0.isFocused },
            "focused next step deck should mark delivery candidate"
        )
        let runTimeline = missionSummary.macAgentRunTimeline
        expect(runTimeline.isReviewable, "run timeline should be reviewable once task or Gateway evidence exists")
        expect(runTimeline.actionStepCount == missionSummary.actionPreflightItems.count, "run timeline should mirror action rows")
        expect(runTimeline.completedCount > 0, "run timeline should count completed steps")
        expect(runTimeline.evidenceStepCount > 0, "run timeline should count evidence steps")
        expect(runTimeline.humanActionCount > 0, "run timeline should surface human gates")
        expect(runTimeline.requiresHumanAction, "run timeline should require human review")
        expect(runTimeline.steps.contains { $0.id == "evidence-sync" && $0.hasEvidence }, "run timeline should include evidence sync step")
        expect(runTimeline.steps.contains { $0.id == "human-handoff" && $0.requiresHumanAction }, "run timeline should include human handoff step")
        expect(
            runTimeline.steps.contains { $0.reviewKind == "browser-control" && $0.hasResult && $0.hasEvidence },
            "run timeline should join browser result with evidence"
        )
        let focusedRunTimeline = missionSummary.macAgentRunTimeline(focusedOn: "delivery-safety")
        expect(focusedRunTimeline.focusedReviewKind == "delivery-safety", "run timeline should record delivery focus")
        expect(focusedRunTimeline.focusedReviewTitle == "最终提交安全", "run timeline should expose delivery title")
        expect(
            focusedRunTimeline.steps.contains { $0.reviewKind == "delivery-safety" && $0.isFocused },
            "focused run timeline should mark delivery row"
        )
        let continuationGate = missionSummary.macAgentContinuationGate
        expect(continuationGate.isReviewable, "continuation gate should be reviewable once Gateway evidence exists")
        expect(continuationGate.totalCount > 0, "continuation gate should expose rows")
        expect(continuationGate.items.map(\.rank) == continuationGate.items.map(\.rank).sorted(), "continuation gate should be rank sorted")
        expect(continuationGate.requiresHumanAction, "continuation gate should surface human review")
        expect(continuationGate.humanActionCount > 0, "continuation gate should count human gates")
        expect(
            continuationGate.items.contains { $0.id == "human-confirmation" && $0.requiresHumanAction },
            "continuation gate should include human confirmation"
        )
        expect(
            continuationGate.items.contains { $0.id == "loop-continuation" && $0.reviewKind == "agent-trace" },
            "continuation gate should include loop continuation"
        )
        expect(continuationGate.primaryReviewKind != nil, "continuation gate should expose primary review")
        let focusedContinuationGate = missionSummary.macAgentContinuationGate(focusedOn: "delivery-safety")
        expect(focusedContinuationGate.focusedReviewKind == "delivery-safety", "continuation gate should record delivery focus")
        expect(focusedContinuationGate.focusedReviewTitle == "最终提交安全", "continuation gate should expose delivery title")
        expect(
            focusedContinuationGate.items.contains { $0.reviewKind == "delivery-safety" && $0.isFocused },
            "focused continuation gate should mark delivery row"
        )
        let reviewRadar = missionSummary.macAgentReviewRadar
        expect(reviewRadar.isReviewable, "review radar should be reviewable once Gateway evidence exists")
        expect(reviewRadar.totalCount == 5, "review radar should expose fixed sectors")
        expect(reviewRadar.priorityCount > 0, "review radar should count priority signals")
        expect(reviewRadar.requiresHumanAction, "review radar should surface human review")
        expect(
            reviewRadar.sectors.contains { $0.id == "safety-review" && $0.priorityCount > 0 },
            "review radar should include safety review signals"
        )
        expect(
            reviewRadar.sectors.contains { $0.id == "evidence-coverage" && $0.readyCount > 0 },
            "review radar should include evidence coverage"
        )
        expect(
            reviewRadar.sectors.contains { $0.id == "loop-continuation" && $0.reviewKind == "agent-trace" },
            "review radar should include loop sector"
        )
        expect(reviewRadar.primaryReviewKind != nil, "review radar should expose primary review")
        let focusedReviewRadar = missionSummary.macAgentReviewRadar(focusedOn: "delivery-safety")
        expect(focusedReviewRadar.focusedReviewKind == "delivery-safety", "review radar should record delivery focus")
        expect(focusedReviewRadar.focusedReviewTitle == "最终提交安全", "review radar should expose delivery title")
        expect(
            focusedReviewRadar.sectors.contains { $0.reviewKind == "delivery-safety" && $0.isFocused },
            "focused review radar should mark delivery sector"
        )
        let handoffBrief = missionSummary.macAgentHandoffBrief
        expect(handoffBrief.isReviewable, "handoff brief should be reviewable once Gateway evidence exists")
        expect(handoffBrief.totalCount == 5, "handoff brief should expose fixed items")
        expect(handoffBrief.humanActionCount > 0, "handoff brief should count human handoff")
        expect(handoffBrief.requiresHumanAction, "handoff brief should surface human review")
        expect(
            handoffBrief.items.contains { $0.id == "human-confirmation" && $0.requiresHumanAction },
            "handoff brief should include human confirmation"
        )
        expect(
            handoffBrief.items.contains { $0.id == "metadata-evidence" && $0.hasMetadataGap == handoffBrief.hasMetadataGap },
            "handoff brief should include metadata evidence item"
        )
        expect(
            handoffBrief.items.contains { $0.id == "loop-next" && $0.reviewKind == "agent-trace" },
            "handoff brief should include loop item"
        )
        expect(handoffBrief.primaryReviewKind != nil, "handoff brief should expose primary review")
        let focusedHandoffBrief = missionSummary.macAgentHandoffBrief(focusedOn: "delivery-safety")
        expect(focusedHandoffBrief.focusedReviewKind == "delivery-safety", "handoff brief should record delivery focus")
        expect(focusedHandoffBrief.focusedReviewTitle == "最终提交安全", "handoff brief should expose delivery title")
        expect(
            focusedHandoffBrief.items.contains { $0.reviewKind == "delivery-safety" && $0.isFocused },
            "focused handoff brief should mark delivery item"
        )
        let controlSnapshot = missionSummary.controlSnapshot
        expect(controlSnapshot.isReviewable, "control snapshot should be reviewable once Gateway evidence exists")
        expect(
            ["waiting-human", "metadata-pending", "ready-to-continue", "reviewable"].contains(controlSnapshot.controlState),
            "control snapshot should expose stable post-send state"
        )
        expect(
            controlSnapshot.requiresHumanAction == (handoffBrief.requiresHumanAction || missionSummary.requiresUserApproval),
            "control snapshot should mirror human action state"
        )
        expect(controlSnapshot.primaryReviewKind != nil, "control snapshot should expose primary review")
        let focusedControlSnapshot = missionSummary.controlSnapshot(focusedOn: "delivery-safety")
        expect(focusedControlSnapshot.controlState == "focused", "focused control snapshot should expose focus state")
        expect(focusedControlSnapshot.focusedReviewKind == "delivery-safety", "focused control snapshot should record delivery focus")
        expect(focusedControlSnapshot.focusedReviewTitle == "最终提交安全", "focused control snapshot should expose delivery title")
        expect(focusedControlSnapshot.primaryReviewKind == "delivery-safety", "focused control snapshot should keep delivery primary")
        let operatorStrip = missionSummary.operatorStrip
        expect(operatorStrip.lanes.map(\.id) == ["gateway", "evidence", "review", "next"], "operator strip should expose stable lanes")
        expect(operatorStrip.title == "Mission Operator", "operator strip should expose stable title")
        expect(
            operatorStrip.lanes.contains { $0.id == "gateway" && $0.status.contains(missionSummary.phaseTitle) },
            "operator strip should include gateway phase"
        )
        expect(
            operatorStrip.lanes.contains { $0.id == "evidence" && $0.status == "\(evidenceIndex.coveredReviewCount)/\(evidenceIndex.items.count) 类覆盖" },
            "operator strip should mirror evidence coverage"
        )
        expect(
            operatorStrip.lanes.contains { $0.id == "review" && $0.status == "\(missionSummary.reviewReadinessSummary.actionablePriorityCount) 可行动 · \(missionSummary.reviewReadinessSummary.criticalOrHighCount) 高优先" },
            "operator strip should mirror readiness counts"
        )
        expect(
            operatorStrip.lanes.contains { $0.id == "next" && $0.reviewKind == missionSummary.nextReviewAction.reviewKind },
            "operator strip next lane should target next review action"
        )
        let focusedOperatorStrip = missionSummary.operatorStrip(focusedOn: "delivery-safety")
        expect(focusedOperatorStrip.focusedReviewKind == "delivery-safety", "operator strip should record focused review kind")
        expect(
            focusedOperatorStrip.lanes.contains { $0.id == "next" && $0.reviewKind == "delivery-safety" && $0.isFocused },
            "operator strip should mark focused next lane"
        )
        let evidenceTrail = missionSummary.evidenceTrailSummary
        expect(evidenceTrail.isReviewable, "evidence trail should be reviewable once Gateway evidence exists")
        expect(evidenceTrail.steps.map(\.id) == ["evidence", "metadata", "priority", "next"], "evidence trail should expose stable steps")
        expect(evidenceTrail.coveredReviewCount == evidenceIndex.coveredReviewCount, "evidence trail should mirror evidence coverage")
        expect(evidenceTrail.totalReviewCount == evidenceIndex.items.count, "evidence trail should count review evidence rows")
        expect(evidenceTrail.metadataPendingCount == missionSummary.reviewReadinessSummary.metadataPendingCount, "evidence trail should mirror metadata gaps")
        expect(evidenceTrail.actionablePriorityCount == missionSummary.reviewReadinessSummary.actionablePriorityCount, "evidence trail should mirror actionable count")
        expect(evidenceTrail.primaryReviewKind == missionSummary.nextReviewAction.reviewKind, "evidence trail should point to next review kind")
        expect(evidenceTrail.primaryReviewTitle == missionSummary.nextReviewAction.reviewTitle, "evidence trail should point to next review title")
        expect(evidenceTrail.canFocusPrimaryReview, "evidence trail should allow focusing the primary review")
        expect(evidenceTrail.requiresHumanAction, "evidence trail should surface human review")
        expect(
            evidenceTrail.steps.contains { $0.id == "priority" && $0.reviewKind == missionSummary.reviewPriorityQueue.first?.reviewKind },
            "evidence trail should include top priority step"
        )
        let focusedEvidenceTrail = missionSummary.evidenceTrailSummary(focusedOn: "delivery-safety")
        expect(focusedEvidenceTrail.focusedReviewKind == "delivery-safety", "focused evidence trail should record focus")
        expect(focusedEvidenceTrail.focusedReviewTitle == "最终提交安全", "focused evidence trail should expose delivery title")
        expect(
            focusedEvidenceTrail.steps.contains { $0.reviewKind == "delivery-safety" && $0.isFocused },
            "focused evidence trail should mark focused step"
        )
        let approvalQueue = missionSummary.approvalQueueSummary
        expect(approvalQueue.isReviewable, "approval queue should be reviewable once mission has approvals or gateway review")
        expect(approvalQueue.requiresHumanAction, "approval queue should surface human action")
        expect(approvalQueue.totalCount > 0, "approval queue should count items")
        expect(approvalQueue.actionableCount > 0, "approval queue should count actionable items")
        expect(approvalQueue.criticalOrHighCount > 0, "approval queue should count high priority items")
        expect(
            approvalQueue.items.map(\.rank) == approvalQueue.items.map(\.rank).sorted(),
            "approval queue should be rank sorted"
        )
        expect(
            approvalQueue.items.contains { $0.reviewKind == "delivery-safety" && $0.isActionable && $0.hasMetadata },
            "approval queue should include delivery safety confirmation"
        )
        expect(
            approvalQueue.items.contains { $0.reviewKind == "agent-trace" && $0.isActionable && $0.hasMetadata },
            "approval queue should include agent trace handoff confirmation"
        )
        expect(
            approvalQueue.items.contains { $0.reviewKind == "approval" && $0.isActionable == false },
            "approval queue should retain sent approval rows as status-only checks"
        )
        let focusedApprovalQueue = missionSummary.approvalQueueSummary(focusedOn: "delivery-safety")
        expect(focusedApprovalQueue.focusedReviewKind == "delivery-safety", "approval queue should record delivery focus")
        expect(focusedApprovalQueue.focusedReviewTitle != nil, "approval queue should expose a focused delivery title")
        expect(
            focusedApprovalQueue.items.contains { $0.reviewKind == "delivery-safety" && $0.isFocused },
            "focused approval queue should mark delivery row"
        )
        let approvalFastLane = missionSummary.approvalFastLane
        expect(approvalFastLane.isReviewable, "approval fast lane should be reviewable")
        expect(approvalFastLane.requiresHumanAction, "approval fast lane should require human")
        expect(approvalFastLane.primaryReviewKind != nil, "approval fast lane should expose primary review")
        expect(
            ["waiting-human", "metadata-pending", "reviewable"].contains(approvalFastLane.laneState),
            "approval fast lane should expose stable post-send state"
        )
        let focusedApprovalFastLane = missionSummary.approvalFastLane(focusedOn: "delivery-safety")
        expect(focusedApprovalFastLane.laneState == "focused", "focused approval fast lane should show focus")
        expect(focusedApprovalFastLane.primaryReviewKind == "delivery-safety", "focused approval fast lane should target delivery")
        expect(focusedApprovalFastLane.primaryReviewTitle == "最终提交安全", "focused approval fast lane should expose delivery title")
        let focusContext = missionSummary.focusContextSummary
        expect(focusContext.isReviewable, "focus context should be reviewable once Gateway evidence exists")
        expect(focusContext.canClearFocus == false, "unfocused context should not expose clear focus")
        expect(focusContext.primaryReviewKind == missionSummary.nextReviewAction.reviewKind, "focus context should point to next detail review")
        let focusedFocusContext = missionSummary.focusContextSummary(focusedOn: "delivery-safety")
        expect(focusedFocusContext.focusedReviewKind == "delivery-safety", "focus context should record delivery focus")
        expect(focusedFocusContext.focusedReviewTitle == "最终提交安全", "focus context should expose delivery title")
        expect(focusedFocusContext.canFocusDetailReview, "delivery focus context should know it has detail")
        expect(focusedFocusContext.canClearFocus, "delivery focus context should allow clearing focus")
        expect(focusedFocusContext.hasEvidence, "delivery focus context should mark evidence coverage")
        expect(focusedFocusContext.requiresHumanAction, "delivery focus context should surface human review")
        let detailDock = missionSummary.reviewDetailDockSummary
        expect(detailDock.isReviewable, "detail dock should be reviewable once Gateway evidence exists")
        expect(detailDock.detailReviewKinds == availableDetailKinds, "unfocused detail dock should show all details")
        expect(detailDock.showsFocusedDetailOnly == false, "unfocused detail dock should not claim a single detail")
        expect(detailDock.canClearFocus == false, "unfocused detail dock should not expose clear focus")
        expect(detailDock.activeReviewKind == nil, "unfocused detail dock should not invent active focus")
        expect(missionSummary.activeReviewFocus(from: "delivery-safety") == "delivery-safety", "active focus should resolve delivery detail")
        let focusedDetailDock = missionSummary.reviewDetailDockSummary(focusedOn: "delivery-safety")
        expect(focusedDetailDock.activeReviewKind == "delivery-safety", "focused detail dock should record delivery focus")
        expect(focusedDetailDock.activeReviewTitle == "最终提交安全", "focused detail dock should expose delivery title")
        expect(focusedDetailDock.detailReviewKinds == ["delivery-safety"], "focused detail dock should show delivery only")
        expect(focusedDetailDock.showsFocusedDetailOnly, "focused detail dock should mark single detail mode")
        expect(focusedDetailDock.canClearFocus, "focused detail dock should allow clearing")
        expect(focusedDetailDock.hasStaleFocus == false, "focused detail dock should not mark stale focus")
        var statusOnlySummary = missionSummary
        let statusOnlyItem = ClawMissionRunReviewPriorityItem(
            id: "gateway-status",
            rank: 0,
            severity: .info,
            title: "Gateway 状态",
            status: "状态待查看",
            reason: "状态项没有详细复核 row。",
            icon: "server.rack",
            reviewKind: "gateway-status",
            actionHint: "保持全量详情",
            isActionable: false,
            hasMetadata: true
        )
        statusOnlySummary.reviewPriorityQueue.insert(statusOnlyItem, at: 0)
        let statusFocusContext = statusOnlySummary.focusContextSummary(focusedOn: statusOnlyItem.reviewKind)
        expect(statusFocusContext.focusedReviewKind == statusOnlyItem.reviewKind, "status focus context should record the status item")
        expect(statusFocusContext.canFocusDetailReview == false, "status focus context should not claim detail focus")
        expect(statusFocusContext.canClearFocus, "status focus context should allow clearing focus")
        expect(statusOnlySummary.activeReviewFocus(from: statusOnlyItem.reviewKind) == statusOnlyItem.reviewKind, "status focus should remain an active focus")
        let statusDetailDock = statusOnlySummary.reviewDetailDockSummary(focusedOn: statusOnlyItem.reviewKind)
        expect(statusDetailDock.activeReviewKind == statusOnlyItem.reviewKind, "status detail dock should record status focus")
        expect(statusDetailDock.activeReviewTitle == statusOnlyItem.title, "status detail dock should expose status title")
        expect(statusDetailDock.detailReviewKinds == availableDetailKinds, "status detail dock should keep all details visible")
        expect(statusDetailDock.showsFocusedDetailOnly == false, "status detail dock should not filter details")
        expect(statusDetailDock.canClearFocus, "status detail dock should allow clearing")
        let statusEvidenceTrail = statusOnlySummary.evidenceTrailSummary(focusedOn: statusOnlyItem.reviewKind)
        expect(statusEvidenceTrail.focusedReviewKind == statusOnlyItem.reviewKind, "status evidence trail should keep status focus")
        expect(statusEvidenceTrail.focusedReviewTitle == statusOnlyItem.title, "status evidence trail should expose status title")
        expect(
            statusEvidenceTrail.steps.contains { $0.reviewKind == statusOnlyItem.reviewKind && $0.isFocused },
            "status evidence trail should mark status focus"
        )
        statusOnlySummary.approvalQueue.insert(
            ClawMissionRunApprovalQueueItem(
                id: "gateway-status-approval",
                rank: 0,
                severity: .info,
                title: "Gateway 状态",
                status: "状态待查看",
                reason: "状态项没有详细复核 row。",
                icon: "server.rack",
                reviewKind: "gateway-status",
                actionKindTitle: nil,
                approvalTitle: nil,
                isActionable: false,
                hasMetadata: true,
                canFocusReview: true,
                isFocused: false
            ),
            at: 0
        )
        let statusApprovalQueue = statusOnlySummary.approvalQueueSummary(focusedOn: statusOnlyItem.reviewKind)
        expect(statusApprovalQueue.focusedReviewKind == statusOnlyItem.reviewKind, "status approval queue should keep status focus")
        expect(statusApprovalQueue.focusedReviewTitle == statusOnlyItem.title, "status approval queue should expose status title")
        expect(
            statusApprovalQueue.items.contains { $0.reviewKind == statusOnlyItem.reviewKind && $0.isFocused },
            "status approval queue should mark status row"
        )
        let statusApprovalFastLane = statusOnlySummary.approvalFastLane(focusedOn: statusOnlyItem.reviewKind)
        expect(statusApprovalFastLane.laneState == "focused", "status approval fast lane should show focus")
        expect(statusApprovalFastLane.primaryReviewKind == statusOnlyItem.reviewKind, "status approval fast lane should keep status")
        expect(statusApprovalFastLane.primaryReviewTitle == statusOnlyItem.title, "status approval fast lane should expose status title")
        let statusPayloadLedger = statusOnlySummary.payloadSafetyLedger(focusedOn: statusOnlyItem.reviewKind)
        expect(statusPayloadLedger.focusedReviewKind == nil, "status payload ledger should not focus status-only items")
        expect(statusPayloadLedger.items.map(\.reviewKind) == availableDetailKinds, "status payload ledger should keep all details visible")
        let statusMacReadiness = statusOnlySummary.macAgentReadinessBoard(focusedOn: statusOnlyItem.reviewKind)
        expect(statusMacReadiness.focusedReviewKind == statusOnlyItem.reviewKind, "status mac readiness should keep status focus")
        expect(statusMacReadiness.focusedReviewTitle == statusOnlyItem.title, "status mac readiness should expose status title")
        expect(
            statusMacReadiness.items.contains { $0.id == "human-gate" && $0.isFocused },
            "status mac readiness should mark human gate row"
        )
        statusOnlySummary.actionPreflightItems.insert(
            ClawMissionRunActionPreflightItem(
                id: "gateway-status-preflight",
                rank: -1,
                title: "Gateway 状态",
                actionKindTitle: "状态复核",
                approvalTitle: "人工复核",
                status: "状态待查看",
                guidance: "状态项没有单独 action 结果。",
                icon: "server.rack",
                tone: .info,
                reviewKind: statusOnlyItem.reviewKind,
                reviewTitle: statusOnlyItem.title,
                canFocusReview: true,
                isFocused: false,
                hasStructuredArguments: false,
                hasResult: false,
                hasMetadata: true,
                isReady: false,
                isBlocked: false,
                isDegraded: false,
                requiresHumanAction: false,
                isRetryable: false
            ),
            at: 0
        )
        let statusActionPreflight = statusOnlySummary.macGatewayActionPreflightMatrix(focusedOn: statusOnlyItem.reviewKind)
        expect(statusActionPreflight.focusedReviewKind == statusOnlyItem.reviewKind, "status action preflight should keep status focus")
        expect(statusActionPreflight.focusedReviewTitle == statusOnlyItem.title, "status action preflight should expose status title")
        expect(
            statusActionPreflight.items.contains { $0.reviewKind == statusOnlyItem.reviewKind && $0.isFocused },
            "status action preflight should mark status row"
        )
        let statusEvidenceCoverage = statusOnlySummary.macAgentEvidenceCoverageMap(focusedOn: statusOnlyItem.reviewKind)
        expect(statusEvidenceCoverage.focusedReviewKind == statusOnlyItem.reviewKind, "status evidence coverage should keep status focus")
        expect(statusEvidenceCoverage.focusedReviewTitle == statusOnlyItem.title, "status evidence coverage should expose status title")
        expect(
            statusEvidenceCoverage.items.contains { $0.reviewKind == statusOnlyItem.reviewKind && $0.isFocused },
            "status evidence coverage should mark status row"
        )
        let statusNextStepDeck = statusOnlySummary.macAgentNextStepDeck(focusedOn: statusOnlyItem.reviewKind)
        expect(statusNextStepDeck.focusedReviewKind == statusOnlyItem.reviewKind, "status next step deck should keep status focus")
        expect(statusNextStepDeck.focusedReviewTitle == statusOnlyItem.title, "status next step deck should expose status title")
        expect(
            statusNextStepDeck.candidates.contains { $0.reviewKind == statusOnlyItem.reviewKind && $0.isFocused },
            "status next step deck should mark status candidate"
        )
        let statusRunTimeline = statusOnlySummary.macAgentRunTimeline(focusedOn: statusOnlyItem.reviewKind)
        expect(statusRunTimeline.focusedReviewKind == statusOnlyItem.reviewKind, "status run timeline should keep status focus")
        expect(statusRunTimeline.focusedReviewTitle == statusOnlyItem.title, "status run timeline should expose status title")
        expect(
            statusRunTimeline.steps.contains { $0.reviewKind == statusOnlyItem.reviewKind && $0.isFocused },
            "status run timeline should mark status row"
        )
        let statusContinuationGate = statusOnlySummary.macAgentContinuationGate(focusedOn: statusOnlyItem.reviewKind)
        expect(statusContinuationGate.focusedReviewKind == statusOnlyItem.reviewKind, "status continuation gate should keep status focus")
        expect(statusContinuationGate.focusedReviewTitle == statusOnlyItem.title, "status continuation gate should expose status title")
        expect(
            statusContinuationGate.items.contains { $0.reviewKind == statusOnlyItem.reviewKind && $0.isFocused },
            "status continuation gate should mark status row"
        )
        let statusReviewRadar = statusOnlySummary.macAgentReviewRadar(focusedOn: statusOnlyItem.reviewKind)
        expect(statusReviewRadar.focusedReviewKind == statusOnlyItem.reviewKind, "status review radar should keep status focus")
        expect(statusReviewRadar.focusedReviewTitle == statusOnlyItem.title, "status review radar should expose status title")
        expect(
            statusReviewRadar.sectors.contains { $0.reviewKind == statusOnlyItem.reviewKind && $0.isFocused },
            "status review radar should mark status sector"
        )
        let statusHandoffBrief = statusOnlySummary.macAgentHandoffBrief(focusedOn: statusOnlyItem.reviewKind)
        expect(statusHandoffBrief.focusedReviewKind == statusOnlyItem.reviewKind, "status handoff brief should keep status focus")
        expect(statusHandoffBrief.focusedReviewTitle == statusOnlyItem.title, "status handoff brief should expose status title")
        expect(
            statusHandoffBrief.items.contains { $0.reviewKind == statusOnlyItem.reviewKind && $0.isFocused },
            "status handoff brief should mark status item"
        )
        let statusControlSnapshot = statusOnlySummary.controlSnapshot(focusedOn: statusOnlyItem.reviewKind)
        expect(statusControlSnapshot.controlState == "focused", "status control snapshot should expose focus state")
        expect(statusControlSnapshot.focusedReviewKind == statusOnlyItem.reviewKind, "status control snapshot should keep status focus")
        expect(statusControlSnapshot.focusedReviewTitle == statusOnlyItem.title, "status control snapshot should expose status title")
        expect(statusControlSnapshot.primaryReviewKind == statusOnlyItem.reviewKind, "status control snapshot should keep status primary")
        let staleFocusContext = statusOnlySummary.focusContextSummary(focusedOn: "unknown-review-kind")
        expect(staleFocusContext.focusedReviewKind == nil, "stale focus context should not keep an unknown review kind")
        expect(staleFocusContext.canClearFocus, "stale focus context should allow clearing focus")
        expect(statusOnlySummary.activeReviewFocus(from: "unknown-review-kind") == nil, "stale active focus should not resolve")
        let staleDetailDock = statusOnlySummary.reviewDetailDockSummary(focusedOn: "unknown-review-kind")
        expect(staleDetailDock.activeReviewKind == nil, "stale detail dock should not keep an unknown focus")
        expect(staleDetailDock.detailReviewKinds == availableDetailKinds, "stale detail dock should keep all details visible")
        expect(staleDetailDock.showsFocusedDetailOnly == false, "stale detail dock should not filter details")
        expect(staleDetailDock.canClearFocus, "stale detail dock should allow clearing")
        expect(staleDetailDock.hasStaleFocus, "stale detail dock should mark stale focus")
        let staleEvidenceTrail = statusOnlySummary.evidenceTrailSummary(focusedOn: "unknown-review-kind")
        expect(staleEvidenceTrail.focusedReviewKind == nil, "stale evidence trail should not keep unknown focus")
        expect(staleEvidenceTrail.primaryReviewKind == statusOnlyItem.reviewKind, "stale evidence trail should fall back to top priority")
        let stalePayloadLedger = statusOnlySummary.payloadSafetyLedger(focusedOn: "unknown-review-kind")
        expect(stalePayloadLedger.focusedReviewKind == nil, "stale payload ledger should not keep unknown focus")
        expect(stalePayloadLedger.totalCount == availableDetailKinds.count, "stale payload ledger should keep all rows")
        let staleMacReadiness = statusOnlySummary.macAgentReadinessBoard(focusedOn: "unknown-review-kind")
        expect(staleMacReadiness.focusedReviewKind == nil, "stale mac readiness should not keep unknown focus")
        expect(staleMacReadiness.items.map(\.id) == ["connection", "capability", "observation", "loop", "human-gate"], "stale mac readiness should keep stable rows")
        let staleActionPreflight = statusOnlySummary.macGatewayActionPreflightMatrix(focusedOn: "unknown-review-kind")
        expect(staleActionPreflight.focusedReviewKind == nil, "stale action preflight should not keep unknown focus")
        expect(staleActionPreflight.totalCount == statusOnlySummary.actionPreflightItems.count, "stale action preflight should keep rows")
        let staleEvidenceCoverage = statusOnlySummary.macAgentEvidenceCoverageMap(focusedOn: "unknown-review-kind")
        expect(staleEvidenceCoverage.focusedReviewKind == nil, "stale evidence coverage should not keep unknown focus")
        expect(staleEvidenceCoverage.totalCount >= availableDetailKinds.count, "stale evidence coverage should keep review rows")
        let staleNextStepDeck = statusOnlySummary.macAgentNextStepDeck(focusedOn: "unknown-review-kind")
        expect(staleNextStepDeck.focusedReviewKind == nil, "stale next step deck should not keep unknown focus")
        expect(
            staleNextStepDeck.totalCount == statusOnlySummary.macAgentNextStepDeck.totalCount,
            "stale next step deck should keep candidates"
        )
        let staleRunTimeline = statusOnlySummary.macAgentRunTimeline(focusedOn: "unknown-review-kind")
        expect(staleRunTimeline.focusedReviewKind == nil, "stale run timeline should not keep unknown focus")
        expect(staleRunTimeline.totalCount >= statusOnlySummary.actionPreflightItems.count, "stale run timeline should keep steps")
        let staleContinuationGate = statusOnlySummary.macAgentContinuationGate(focusedOn: "unknown-review-kind")
        expect(staleContinuationGate.focusedReviewKind == nil, "stale continuation gate should not keep unknown focus")
        expect(
            staleContinuationGate.totalCount == statusOnlySummary.macAgentContinuationGate.totalCount,
            "stale continuation gate should keep rows"
        )
        let staleReviewRadar = statusOnlySummary.macAgentReviewRadar(focusedOn: "unknown-review-kind")
        expect(staleReviewRadar.focusedReviewKind == nil, "stale review radar should not keep unknown focus")
        expect(
            staleReviewRadar.totalCount == statusOnlySummary.macAgentReviewRadar.totalCount,
            "stale review radar should keep sectors"
        )
        let staleHandoffBrief = statusOnlySummary.macAgentHandoffBrief(focusedOn: "unknown-review-kind")
        expect(staleHandoffBrief.focusedReviewKind == nil, "stale handoff brief should not keep unknown focus")
        expect(
            staleHandoffBrief.totalCount == statusOnlySummary.macAgentHandoffBrief.totalCount,
            "stale handoff brief should keep items"
        )
        let staleControlSnapshot = statusOnlySummary.controlSnapshot(focusedOn: "unknown-review-kind")
        expect(staleControlSnapshot.focusedReviewKind == nil, "stale control snapshot should not keep unknown focus")
        expect(
            staleControlSnapshot.controlState == statusOnlySummary.controlSnapshot.controlState,
            "stale control snapshot should fall back to default state"
        )
        let staleApprovalFastLane = statusOnlySummary.approvalFastLane(focusedOn: "unknown-review-kind")
        expect(
            staleApprovalFastLane.laneState == statusOnlySummary.approvalFastLane.laneState,
            "stale approval fast lane should fall back to default state"
        )
        expect(
            staleApprovalFastLane.primaryReviewKind == statusOnlySummary.approvalFastLane.primaryReviewKind,
            "stale approval fast lane should keep default primary"
        )
        expect(
            missionSummary.detailReviewKinds(focusedOn: nil) == availableDetailKinds,
            "nil focus should show all detail reviews"
        )
        expect(
            missionSummary.detailReviewKinds(focusedOn: "delivery-safety") == ["delivery-safety"],
            "delivery focus should show delivery detail only"
        )
        expect(
            missionSummary.detailReviewKinds(focusedOn: "gateway-status") == availableDetailKinds,
            "status focus should keep all detail reviews visible"
        )
        expect(
            missionSummary.detailReviewKinds(focusedOn: "unknown-review-kind") == availableDetailKinds,
            "stale focus should keep all detail reviews visible"
        )
        expect(
            missionSummary.shouldShowDetailReview("delivery-safety", focusedOn: "delivery-safety"),
            "focused delivery detail should remain visible"
        )
        expect(
            missionSummary.shouldShowDetailReview("artifact-metadata", focusedOn: "delivery-safety") == false,
            "delivery focus should hide unrelated detail reviews"
        )
        expect(
            missionSummary.focusUsesDetailReview("gateway-status") == false,
            "gateway status focus should be treated as a status-level focus"
        )
        expect(
            missionSummary.reviewPriorityItem(focusedOn: "delivery-safety") != nil,
            "focus should resolve a queue item"
        )
        let readiness = missionSummary.reviewReadinessSummary
        expect(readiness.totalPriorityCount == missionSummary.reviewPriorityQueue.count, "readiness should count the full priority queue")
        expect(
            readiness.actionablePriorityCount == missionSummary.reviewPriorityQueue.filter(\.isActionable).count,
            "readiness should count actionable priorities"
        )
        expect(
            readiness.criticalOrHighCount == missionSummary.reviewPriorityQueue.filter { $0.severity == .critical || $0.severity == .high }.count,
            "readiness should count critical and high priorities"
        )
        expect(
            readiness.metadataPendingCount == missionSummary.reviewPriorityQueue.filter { $0.hasMetadata == false }.count,
            "readiness should count metadata gaps"
        )
        expect(
            readiness.availableDetailReviewCount == availableDetailKinds.count,
            "readiness should count available detail reviews"
        )
        expect(readiness.topReviewKind == missionSummary.reviewPriorityQueue.first?.reviewKind, "readiness should expose the top review kind")
        expect(readiness.topReviewTitle == missionSummary.reviewPriorityQueue.first?.title, "readiness should expose the top review title")
        expect(readiness.isReviewable, "readiness should mark sent missions reviewable")
        expect(readiness.requiresHumanAction, "readiness should surface human review needs")
        let nextAction = missionSummary.nextReviewAction
        expect(nextAction.reviewKind == missionSummary.reviewPriorityQueue.first?.reviewKind, "next review action should target top priority")
        expect(nextAction.reviewTitle == missionSummary.reviewPriorityQueue.first?.title, "next review action should expose top priority title")
        expect(nextAction.actionHint == missionSummary.reviewPriorityQueue.first?.actionHint, "next review action should reuse top action hint")
        expect(nextAction.isReviewable, "next review action should mark sent missions reviewable")
        expect(nextAction.requiresHumanAction, "next review action should surface human review needs")
        let focusedReadiness = missionSummary.reviewReadinessSummary(focusedOn: "delivery-safety")
        expect(focusedReadiness.focusedReviewKind == "delivery-safety", "readiness should record focused review kind")
        expect(focusedReadiness.focusedReviewTitle == "最终提交安全", "readiness should record focused review title")
        expect(focusedReadiness.focusedHasDetailReview, "readiness should know focused review has a detail row")
        let focusedNextAction = missionSummary.nextReviewAction(focusedOn: "delivery-safety")
        expect(focusedNextAction.reviewKind == "delivery-safety", "focused next action should target delivery safety")
        expect(focusedNextAction.reviewTitle == "最终提交安全", "focused next action should expose delivery title")
        expect(focusedNextAction.canFocusDetailReview, "focused next action should know delivery has a detail row")
        let staleFocusNextAction = missionSummary.nextReviewAction(focusedOn: "gateway-status")
        expect(
            staleFocusNextAction.reviewKind == missionSummary.reviewPriorityQueue.first?.reviewKind,
            "stale status focus should fall back to the top priority"
        )
        let queueVisibleChunks = missionSummary.reviewPriorityQueue.map {
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
        let evidenceTrailVisibleChunks = evidenceTrail.steps.flatMap {
            [
                $0.id,
                $0.title,
                $0.status,
                $0.guidance,
                $0.reviewKind ?? "",
                $0.reviewTitle ?? ""
            ]
        } + [
            evidenceTrail.title,
            evidenceTrail.status,
            evidenceTrail.guidance,
            evidenceTrail.primaryReviewKind ?? "",
            evidenceTrail.primaryReviewTitle ?? "",
            focusedEvidenceTrail.title,
            focusedEvidenceTrail.status,
            focusedEvidenceTrail.guidance,
            focusedEvidenceTrail.focusedReviewKind ?? "",
            focusedEvidenceTrail.focusedReviewTitle ?? "",
            statusEvidenceTrail.title,
            statusEvidenceTrail.status,
            statusEvidenceTrail.guidance,
            staleEvidenceTrail.title,
            staleEvidenceTrail.status,
            staleEvidenceTrail.guidance
        ]
        let approvalQueueItemChunks: [String] = approvalQueue.items.flatMap { item in
            [
                item.title,
                item.status,
                item.reason,
                item.reviewKind,
                item.actionKindTitle ?? "",
                item.approvalTitle ?? ""
            ]
        }
        let approvalQueueSummaryChunks: [String] = [
            preSendApprovalQueue.title,
            preSendApprovalQueue.status,
            preSendApprovalQueue.guidance,
            focusedPreSendApprovalQueue.focusedReviewKind ?? "",
            focusedPreSendApprovalQueue.focusedReviewTitle ?? "",
            approvalQueue.title,
            approvalQueue.status,
            approvalQueue.guidance,
            approvalQueue.primaryReviewKind ?? "",
            approvalQueue.primaryReviewTitle ?? "",
            focusedApprovalQueue.title,
            focusedApprovalQueue.status,
            focusedApprovalQueue.guidance,
            focusedApprovalQueue.focusedReviewKind ?? "",
            focusedApprovalQueue.focusedReviewTitle ?? "",
            statusApprovalQueue.title,
            statusApprovalQueue.status,
            statusApprovalQueue.guidance,
            statusApprovalQueue.focusedReviewKind ?? "",
            statusApprovalQueue.focusedReviewTitle ?? "",
            idleApprovalFastLane.title,
            idleApprovalFastLane.status,
            idleApprovalFastLane.guidance,
            preSendApprovalFastLane.title,
            preSendApprovalFastLane.status,
            preSendApprovalFastLane.guidance,
            focusedPreSendApprovalFastLane.title,
            focusedPreSendApprovalFastLane.status,
            focusedPreSendApprovalFastLane.guidance,
            approvalFastLane.title,
            approvalFastLane.status,
            approvalFastLane.guidance,
            approvalFastLane.primaryReviewKind ?? "",
            approvalFastLane.primaryReviewTitle ?? "",
            focusedApprovalFastLane.title,
            focusedApprovalFastLane.status,
            focusedApprovalFastLane.guidance,
            statusApprovalFastLane.title,
            statusApprovalFastLane.status,
            statusApprovalFastLane.guidance,
            staleApprovalFastLane.title,
            staleApprovalFastLane.status,
            staleApprovalFastLane.guidance
        ]
        let approvalQueueVisibleChunks = approvalQueueItemChunks + approvalQueueSummaryChunks
        let payloadLedgerItemChunks: [String] = payloadLedger.items.flatMap { item in
            [
                item.reviewKind,
                item.reviewTitle,
                item.status,
                item.guidance
            ]
        }
        let payloadLedgerSummaryChunks: [String] = [
            payloadLedger.title,
            payloadLedger.status,
            payloadLedger.guidance,
            payloadLedger.primaryReviewKind ?? "",
            payloadLedger.primaryReviewTitle ?? "",
            focusedPayloadLedger.title,
            focusedPayloadLedger.status,
            focusedPayloadLedger.guidance,
            focusedPayloadLedger.focusedReviewKind ?? "",
            focusedPayloadLedger.focusedReviewTitle ?? "",
            statusPayloadLedger.title,
            statusPayloadLedger.status,
            statusPayloadLedger.guidance,
            stalePayloadLedger.title,
            stalePayloadLedger.status,
            stalePayloadLedger.guidance
        ]
        let payloadLedgerVisibleChunks = payloadLedgerItemChunks + payloadLedgerSummaryChunks
        let focusContextVisibleChunks = [
            focusContext.title,
            focusContext.status,
            focusContext.guidance,
            focusContext.primaryReviewKind ?? "",
            focusContext.primaryButtonTitle ?? "",
            focusedFocusContext.title,
            focusedFocusContext.status,
            focusedFocusContext.guidance,
            focusedFocusContext.focusedReviewKind ?? "",
            focusedFocusContext.focusedReviewTitle ?? "",
            detailDock.title,
            detailDock.status,
            detailDock.guidance,
            focusedDetailDock.title,
            focusedDetailDock.status,
            focusedDetailDock.guidance,
            focusedDetailDock.activeReviewKind ?? "",
            focusedDetailDock.activeReviewTitle ?? "",
            statusDetailDock.title,
            statusDetailDock.status,
            statusDetailDock.guidance,
            statusDetailDock.activeReviewKind ?? "",
            statusDetailDock.activeReviewTitle ?? "",
            staleDetailDock.title,
            staleDetailDock.status,
            staleDetailDock.guidance
        ]
        let macReadinessItemChunks: [String] = macReadiness.items.flatMap { item in
            [
                item.title,
                item.status,
                item.guidance,
                item.reviewKind ?? "",
                item.reviewTitle ?? ""
            ]
        }
        let macReadinessSummaryChunks: [String] = [
            idleMacReadiness.title,
            idleMacReadiness.status,
            idleMacReadiness.guidance,
            macReadiness.title,
            macReadiness.status,
            macReadiness.guidance,
            macReadiness.primaryReviewKind ?? "",
            macReadiness.primaryReviewTitle ?? "",
            focusedMacReadiness.title,
            focusedMacReadiness.status,
            focusedMacReadiness.guidance,
            focusedMacReadiness.focusedReviewKind ?? "",
            focusedMacReadiness.focusedReviewTitle ?? "",
            statusMacReadiness.title,
            statusMacReadiness.status,
            statusMacReadiness.guidance,
            statusMacReadiness.focusedReviewKind ?? "",
            statusMacReadiness.focusedReviewTitle ?? "",
            staleMacReadiness.title,
            staleMacReadiness.status,
            staleMacReadiness.guidance
        ]
        let macReadinessVisibleChunks = macReadinessItemChunks + macReadinessSummaryChunks
        let actionPreflightItemChunks: [String] = actionPreflight.items.flatMap { item in
            [
                item.title,
                item.actionKindTitle,
                item.approvalTitle,
                item.status,
                item.guidance,
                item.reviewKind ?? "",
                item.reviewTitle ?? ""
            ]
        }
        let actionPreflightSummaryChunks: [String] = [
            idleActionPreflight.title,
            idleActionPreflight.status,
            idleActionPreflight.guidance,
            preSendActionPreflight.title,
            preSendActionPreflight.status,
            preSendActionPreflight.guidance,
            focusedPreSendActionPreflight.title,
            focusedPreSendActionPreflight.status,
            focusedPreSendActionPreflight.guidance,
            actionPreflight.title,
            actionPreflight.status,
            actionPreflight.guidance,
            actionPreflight.primaryReviewKind ?? "",
            actionPreflight.primaryReviewTitle ?? "",
            focusedActionPreflight.title,
            focusedActionPreflight.status,
            focusedActionPreflight.guidance,
            focusedActionPreflight.focusedReviewKind ?? "",
            focusedActionPreflight.focusedReviewTitle ?? "",
            statusActionPreflight.title,
            statusActionPreflight.status,
            statusActionPreflight.guidance,
            statusActionPreflight.focusedReviewKind ?? "",
            statusActionPreflight.focusedReviewTitle ?? "",
            staleActionPreflight.title,
            staleActionPreflight.status,
            staleActionPreflight.guidance
        ]
        let actionPreflightVisibleChunks = actionPreflightItemChunks + actionPreflightSummaryChunks
        let evidenceCoverageItemChunks: [String] = evidenceCoverage.items.flatMap { item in
            [
                item.reviewTitle,
                item.status,
                item.guidance,
                item.reviewKind
            ]
        }
        let evidenceCoverageSummaryChunks: [String] = [
            idleEvidenceCoverage.title,
            idleEvidenceCoverage.status,
            idleEvidenceCoverage.guidance,
            preSendEvidenceCoverage.title,
            preSendEvidenceCoverage.status,
            preSendEvidenceCoverage.guidance,
            focusedPreSendEvidenceCoverage.title,
            focusedPreSendEvidenceCoverage.status,
            focusedPreSendEvidenceCoverage.guidance,
            evidenceCoverage.title,
            evidenceCoverage.status,
            evidenceCoverage.guidance,
            evidenceCoverage.primaryReviewKind ?? "",
            evidenceCoverage.primaryReviewTitle ?? "",
            focusedEvidenceCoverage.title,
            focusedEvidenceCoverage.status,
            focusedEvidenceCoverage.guidance,
            focusedEvidenceCoverage.focusedReviewKind ?? "",
            focusedEvidenceCoverage.focusedReviewTitle ?? "",
            statusEvidenceCoverage.title,
            statusEvidenceCoverage.status,
            statusEvidenceCoverage.guidance,
            statusEvidenceCoverage.focusedReviewKind ?? "",
            statusEvidenceCoverage.focusedReviewTitle ?? "",
            staleEvidenceCoverage.title,
            staleEvidenceCoverage.status,
            staleEvidenceCoverage.guidance
        ]
        let evidenceCoverageVisibleChunks = evidenceCoverageItemChunks + evidenceCoverageSummaryChunks
        let nextStepDeckItemChunks: [String] = nextStepDeck.candidates.flatMap { item in
            [
                item.title,
                item.status,
                item.guidance,
                item.reviewKind ?? "",
                item.reviewTitle ?? ""
            ]
        }
        let nextStepDeckSummaryChunks: [String] = [
            idleNextStepDeck.title,
            idleNextStepDeck.status,
            idleNextStepDeck.guidance,
            preSendNextStepDeck.title,
            preSendNextStepDeck.status,
            preSendNextStepDeck.guidance,
            focusedPreSendNextStepDeck.title,
            focusedPreSendNextStepDeck.status,
            focusedPreSendNextStepDeck.guidance,
            nextStepDeck.title,
            nextStepDeck.status,
            nextStepDeck.guidance,
            nextStepDeck.primaryReviewKind ?? "",
            nextStepDeck.primaryReviewTitle ?? "",
            focusedNextStepDeck.title,
            focusedNextStepDeck.status,
            focusedNextStepDeck.guidance,
            focusedNextStepDeck.focusedReviewKind ?? "",
            focusedNextStepDeck.focusedReviewTitle ?? "",
            statusNextStepDeck.title,
            statusNextStepDeck.status,
            statusNextStepDeck.guidance,
            statusNextStepDeck.focusedReviewKind ?? "",
            statusNextStepDeck.focusedReviewTitle ?? "",
            staleNextStepDeck.title,
            staleNextStepDeck.status,
            staleNextStepDeck.guidance
        ]
        let nextStepDeckVisibleChunks = nextStepDeckItemChunks + nextStepDeckSummaryChunks
        let runTimelineItemChunks: [String] = runTimeline.steps.flatMap { step in
            [
                step.title,
                step.status,
                step.guidance,
                step.reviewKind ?? "",
                step.reviewTitle ?? ""
            ]
        }
        let runTimelineSummaryChunks: [String] = [
            idleRunTimeline.title,
            idleRunTimeline.status,
            idleRunTimeline.guidance,
            preSendRunTimeline.title,
            preSendRunTimeline.status,
            preSendRunTimeline.guidance,
            focusedPreSendRunTimeline.title,
            focusedPreSendRunTimeline.status,
            focusedPreSendRunTimeline.guidance,
            runTimeline.title,
            runTimeline.status,
            runTimeline.guidance,
            runTimeline.primaryReviewKind ?? "",
            runTimeline.primaryReviewTitle ?? "",
            focusedRunTimeline.title,
            focusedRunTimeline.status,
            focusedRunTimeline.guidance,
            focusedRunTimeline.focusedReviewKind ?? "",
            focusedRunTimeline.focusedReviewTitle ?? "",
            statusRunTimeline.title,
            statusRunTimeline.status,
            statusRunTimeline.guidance,
            statusRunTimeline.focusedReviewKind ?? "",
            statusRunTimeline.focusedReviewTitle ?? "",
            staleRunTimeline.title,
            staleRunTimeline.status,
            staleRunTimeline.guidance
        ]
        let runTimelineVisibleChunks = runTimelineItemChunks + runTimelineSummaryChunks
        let continuationGateItemChunks: [String] = continuationGate.items.flatMap { item in
            [
                item.title,
                item.status,
                item.guidance,
                item.reviewKind ?? "",
                item.reviewTitle ?? ""
            ]
        }
        let continuationGateSummaryChunks: [String] = [
            idleContinuationGate.title,
            idleContinuationGate.status,
            idleContinuationGate.guidance,
            preSendContinuationGate.title,
            preSendContinuationGate.status,
            preSendContinuationGate.guidance,
            focusedPreSendContinuationGate.title,
            focusedPreSendContinuationGate.status,
            focusedPreSendContinuationGate.guidance,
            continuationGate.title,
            continuationGate.status,
            continuationGate.guidance,
            continuationGate.primaryReviewKind ?? "",
            continuationGate.primaryReviewTitle ?? "",
            focusedContinuationGate.title,
            focusedContinuationGate.status,
            focusedContinuationGate.guidance,
            focusedContinuationGate.focusedReviewKind ?? "",
            focusedContinuationGate.focusedReviewTitle ?? "",
            statusContinuationGate.title,
            statusContinuationGate.status,
            statusContinuationGate.guidance,
            statusContinuationGate.focusedReviewKind ?? "",
            statusContinuationGate.focusedReviewTitle ?? "",
            staleContinuationGate.title,
            staleContinuationGate.status,
            staleContinuationGate.guidance
        ]
        let continuationGateVisibleChunks = continuationGateItemChunks + continuationGateSummaryChunks
        let reviewRadarItemChunks: [String] = reviewRadar.sectors.flatMap { sector in
            [
                sector.title,
                sector.status,
                sector.guidance,
                sector.reviewKind ?? "",
                sector.reviewTitle ?? ""
            ]
        }
        let reviewRadarSummaryChunks: [String] = [
            idleReviewRadar.title,
            idleReviewRadar.status,
            idleReviewRadar.guidance,
            preSendReviewRadar.title,
            preSendReviewRadar.status,
            preSendReviewRadar.guidance,
            focusedPreSendReviewRadar.title,
            focusedPreSendReviewRadar.status,
            focusedPreSendReviewRadar.guidance,
            reviewRadar.title,
            reviewRadar.status,
            reviewRadar.guidance,
            reviewRadar.primaryReviewKind ?? "",
            reviewRadar.primaryReviewTitle ?? "",
            focusedReviewRadar.title,
            focusedReviewRadar.status,
            focusedReviewRadar.guidance,
            focusedReviewRadar.focusedReviewKind ?? "",
            focusedReviewRadar.focusedReviewTitle ?? "",
            statusReviewRadar.title,
            statusReviewRadar.status,
            statusReviewRadar.guidance,
            statusReviewRadar.focusedReviewKind ?? "",
            statusReviewRadar.focusedReviewTitle ?? "",
            staleReviewRadar.title,
            staleReviewRadar.status,
            staleReviewRadar.guidance
        ]
        let reviewRadarVisibleChunks = reviewRadarItemChunks + reviewRadarSummaryChunks
        let handoffBriefItemChunks: [String] = handoffBrief.items.flatMap { item in
            [
                item.title,
                item.status,
                item.guidance,
                item.reviewKind ?? "",
                item.reviewTitle ?? ""
            ]
        }
        let handoffBriefSummaryChunks: [String] = [
            idleHandoffBrief.title,
            idleHandoffBrief.status,
            idleHandoffBrief.guidance,
            preSendHandoffBrief.title,
            preSendHandoffBrief.status,
            preSendHandoffBrief.guidance,
            focusedPreSendHandoffBrief.title,
            focusedPreSendHandoffBrief.status,
            focusedPreSendHandoffBrief.guidance,
            handoffBrief.title,
            handoffBrief.status,
            handoffBrief.guidance,
            handoffBrief.primaryReviewKind ?? "",
            handoffBrief.primaryReviewTitle ?? "",
            focusedHandoffBrief.title,
            focusedHandoffBrief.status,
            focusedHandoffBrief.guidance,
            focusedHandoffBrief.focusedReviewKind ?? "",
            focusedHandoffBrief.focusedReviewTitle ?? "",
            statusHandoffBrief.title,
            statusHandoffBrief.status,
            statusHandoffBrief.guidance,
            statusHandoffBrief.focusedReviewKind ?? "",
            statusHandoffBrief.focusedReviewTitle ?? "",
            staleHandoffBrief.title,
            staleHandoffBrief.status,
            staleHandoffBrief.guidance
        ]
        let handoffBriefVisibleChunks = handoffBriefItemChunks + handoffBriefSummaryChunks
        let controlSnapshotVisibleChunks: [String] = [
            idleControlSnapshot.title,
            idleControlSnapshot.status,
            idleControlSnapshot.guidance,
            preSendControlSnapshot.title,
            preSendControlSnapshot.status,
            preSendControlSnapshot.guidance,
            focusedPreSendControlSnapshot.title,
            focusedPreSendControlSnapshot.status,
            focusedPreSendControlSnapshot.guidance,
            controlSnapshot.title,
            controlSnapshot.status,
            controlSnapshot.guidance,
            controlSnapshot.primaryReviewKind ?? "",
            controlSnapshot.primaryReviewTitle ?? "",
            focusedControlSnapshot.title,
            focusedControlSnapshot.status,
            focusedControlSnapshot.guidance,
            focusedControlSnapshot.focusedReviewKind ?? "",
            focusedControlSnapshot.focusedReviewTitle ?? "",
            statusControlSnapshot.title,
            statusControlSnapshot.status,
            statusControlSnapshot.guidance,
            staleControlSnapshot.title,
            staleControlSnapshot.status,
            staleControlSnapshot.guidance
        ]
        let queueVisibleText = (
            queueVisibleChunks +
                readinessVisibleChunks +
                nextActionVisibleChunks +
                evidenceVisibleChunks +
                operatorVisibleChunks +
                evidenceTrailVisibleChunks +
                approvalQueueVisibleChunks +
                payloadLedgerVisibleChunks +
                focusContextVisibleChunks +
                macReadinessVisibleChunks +
                actionPreflightVisibleChunks +
                evidenceCoverageVisibleChunks +
                nextStepDeckVisibleChunks +
                runTimelineVisibleChunks +
                continuationGateVisibleChunks +
                reviewRadarVisibleChunks +
                handoffBriefVisibleChunks +
                controlSnapshotVisibleChunks
        ).joined(separator: " ")
        for forbidden in ["Authorization", "Bearer", "toolArguments", "file://", "/private", "/Users", "/home", "C:\\", "stdout", "stderr", "diff", "raw-token", "header", "cookie", "secret"] {
            expect(queueVisibleText.contains(forbidden) == false, "review priority queue should not expose \(forbidden)")
        }
        if let metadataReview = missionSummary.artifactMetadataReview {
            expect(metadataReview.artifactCount > 0, "mission summary should derive artifact metadata review")
            expect(metadataReview.metadataArtifactCount > 0, "artifact metadata review should count metadata artifacts")
            expect(metadataReview.redactedArtifactCount > 0, "artifact metadata review should count redacted artifacts")
            expect(metadataReview.hasMetadata, "artifact metadata review should expose metadata")
            expect(metadataReview.safeMetadataPairs.isEmpty == false, "artifact metadata review should expose safe metadata pairs")
        } else {
            failures.append("mission summary should derive artifact metadata review")
        }
        if let extractionReview = missionSummary.gatewayExtractionCompletenessReview {
            expect(extractionReview.extractionCount == 1, "mission summary should count extraction artifacts")
            expect(extractionReview.hasMetadata, "extraction review should include metadata")
            expect(extractionReview.mode == "artifact-grounded-extraction", "extraction review should expose extraction mode")
            expect(extractionReview.validateCompleteness == true, "extraction review should expose completeness validation")
            expect(extractionReview.rowCount == 4, "extraction review should expose row count")
            expect(extractionReview.completenessStatus == "complete", "extraction review should expose complete status")
            expect(extractionReview.browserTraceCount == 1, "extraction review should expose browser trace count")
            expect(extractionReview.fileDiffCount == 1, "extraction review should expose file diff count")
            expect(extractionReview.commandOutputCount == 1, "extraction review should expose command output count")
            expect(extractionReview.sourceArtifactKinds.contains("browserTrace"), "extraction review should expose source kinds")
            expect(extractionReview.safetyFlags.contains("row-content-omitted"), "extraction review should expose safety flags")
        } else {
            failures.append("mission summary should derive extraction completeness review")
        }
        if let browserReview = missionSummary.gatewayBrowserControlReview {
            expect(browserReview.reviewCount >= 2, "mission summary should count browser control artifacts")
            expect(browserReview.hasMetadata, "browser control review should include metadata")
            expect(browserReview.mode == "browser-control-dry-run", "browser control review should expose dry-run mode")
            expect(browserReview.actionKind == "controlBrowser", "browser control review should expose action kind")
            expect(browserReview.browserControlPolicy == "dry-run", "browser control review should expose browser policy")
            expect(browserReview.policyDiagnostic == "dry-run", "browser control review should expose policy diagnostic")
            expect(browserReview.retryableReason == "enable-browser-control", "browser control review should expose retryable reason")
            expect(browserReview.browserControlRequested == true, "browser control review should expose requested open")
            expect(browserReview.targetURLPresent == true, "browser control review should expose URL presence without value")
            expect(browserReview.searchQueryPresent == true, "browser control review should expose search presence without value")
            expect(browserReview.openAttempted == false, "browser control review should expose open attempt state")
            expect(browserReview.appPolicyChecked == false, "browser control review should expose app policy checked state")
            expect(browserReview.hostPolicyChecked == false, "browser control review should expose host policy checked state")
            expect(browserReview.networkBlocked == false, "browser control review should expose network block state")
            expect(browserReview.resultStatus == "succeeded", "browser control review should expose result status")
            expect(browserReview.requiresPolicyReview == false, "browser control review should not require review for dry-run metadata")
            expect(browserReview.safetyFlags.contains("url-omitted"), "browser control review should omit URL")
            expect(browserReview.safetyFlags.contains("search-query-omitted"), "browser control review should omit search query")
            expect(browserReview.compactStatus.contains("policy dry-run"), "browser control review should summarize policy")
            expect(browserReview.compactStatus.contains("diagnostic dry-run"), "browser control review should summarize diagnostic")
        } else {
            failures.append("mission summary should derive browser control review")
        }
        if let browserArtifacts = missionStore.clawGatewaySessions.first?.results.first(where: { $0.actionKind == .controlBrowser })?.artifacts,
           let browserControlReview = ClawGatewayBrowserControlReviewSummary.latest(from: browserArtifacts) {
            expect(browserControlReview.mode == "browser-control-dry-run", "browser result review should expose dry-run mode")
            expect(browserControlReview.policyDiagnostic == "dry-run", "browser result review should expose policy diagnostic")
            expect(browserControlReview.retryableReason == "enable-browser-control", "browser result review should expose retryable reason")
            expect(browserControlReview.executed == false, "browser result review should expose execution state")
            expect(browserControlReview.timedOut == false, "browser result review should expose timeout state")
            expect(browserControlReview.safetyFlags.contains("candidate-labels-omitted"), "browser result review should omit candidate labels")
        } else {
            failures.append("browser result should derive browser control review")
        }
        if let deliveryReview = missionSummary.gatewayDeliverySafetyReview {
            expect(deliveryReview.reviewCount >= 2, "mission summary should count delivery safety artifacts")
            expect(deliveryReview.hasMetadata, "delivery safety review should include metadata")
            expect(deliveryReview.finalSubmitRequiresApproval == true, "delivery safety review should expose final submit gate")
            expect(deliveryReview.userApprovalRequired == true, "delivery safety review should expose approval requirement")
            expect(deliveryReview.draftBodyOmitted == true, "delivery safety review should omit draft body")
            expect(deliveryReview.submitBlocked == true, "delivery safety review should expose submit block")
            expect(deliveryReview.safetyFlags.contains("metadata-only"), "delivery safety review should expose metadata-only flag")
            expect(deliveryReview.safetyFlags.contains("final-submit-gated"), "delivery safety review should expose final submit flag")
            expect(deliveryReview.compactStatus.contains("最终提交"), "delivery safety review should summarize final submit gate")
        } else {
            failures.append("mission summary should derive delivery safety review")
        }
        if let desktopArtifacts = missionStore.clawGatewaySessions.first?.results.first(where: { $0.actionKind == .operateDesktopApp })?.artifacts,
           let desktopDeliveryReview = ClawGatewayDeliverySafetyReviewSummary.latest(from: desktopArtifacts) {
            expect(desktopDeliveryReview.mode == "desktop-control-dry-run", "desktop delivery review should expose dry-run mode")
            expect(desktopDeliveryReview.actionKind == "operateDesktopApp", "desktop delivery review should expose action kind")
            expect(desktopDeliveryReview.targetKind == "desktopApp", "desktop delivery review should expose target kind")
            expect(desktopDeliveryReview.desktopPolicyDiagnostic == "dry-run", "desktop delivery review should expose policy diagnostic")
            expect(desktopDeliveryReview.desktopRetryableReason == "enable-desktop-control", "desktop delivery review should expose retryable reason")
            expect(desktopDeliveryReview.automationAttempted == false, "desktop delivery review should expose automation attempt state")
            expect(desktopDeliveryReview.appPolicyChecked == false, "desktop delivery review should expose app policy state")
            expect(desktopDeliveryReview.keyPolicyChecked == true, "desktop delivery review should expose key policy state")
            expect(desktopDeliveryReview.requiresDesktopPolicyReview, "desktop delivery review should require policy review")
            expect(desktopDeliveryReview.compactStatus.contains("policy dry-run"), "desktop delivery review should summarize policy diagnostic")
            expect(desktopDeliveryReview.pasteTextOmitted == true, "desktop delivery review should omit paste text")
            expect(desktopDeliveryReview.blockedSubmitKeyCount == 1, "desktop delivery review should count blocked submit key")
            expect(desktopDeliveryReview.safetyFlags.contains("paste-text-omitted"), "desktop delivery review should expose paste omission flag")
        } else {
            failures.append("desktop result should derive delivery safety review")
        }
        if let fileChangeReview = missionSummary.gatewayFileChangeSafetyReview {
            expect(fileChangeReview.reviewCount == 1, "mission summary should count file change artifacts")
            expect(fileChangeReview.hasMetadata, "file change review should include metadata")
            expect(fileChangeReview.mode == "workspace-write", "file change review should expose workspace-write mode")
            expect(fileChangeReview.actionKind == "manageFiles", "file change review should expose manageFiles action")
            expect(fileChangeReview.workspacePolicy == "session-workspace-only", "file change review should expose workspace policy")
            expect(fileChangeReview.workspaceScoped == true, "file change review should expose workspace scope")
            expect(fileChangeReview.writeAttempted == true, "file change review should expose write attempt")
            expect(fileChangeReview.writeSucceeded == true, "file change review should expose write success")
            expect(fileChangeReview.createdFileCount == 1, "file change review should count created files")
            expect(fileChangeReview.rawPathOmitted == true, "file change review should omit raw path")
            expect(fileChangeReview.contentOmitted == true, "file change review should omit file content")
            expect(fileChangeReview.diffOmitted == true, "file change review should omit diff content")
            expect(fileChangeReview.safetyFlags.contains("raw-path-omitted"), "file change review should expose raw path omission flag")
            expect(fileChangeReview.safetyFlags.contains("session-workspace-only"), "file change review should expose session workspace flag")
        } else {
            failures.append("mission summary should derive file change safety review")
        }
        if let fileArtifacts = missionStore.clawGatewaySessions.first?.results.first(where: { $0.actionKind == .manageFiles })?.artifacts,
           let fileReview = ClawGatewayFileChangeSafetyReviewSummary.latest(from: fileArtifacts) {
            expect(fileReview.mode == "workspace-write", "file result review should expose workspace-write mode")
            expect(fileReview.writeSucceeded == true, "file result review should expose write success")
            expect(fileReview.safetyFlags.contains("file-content-omitted"), "file result review should omit file content")
        } else {
            failures.append("file result should derive file change safety review")
        }
        let shellReviewStore = ClawStore(autoScanLocalArtifacts: false)
        shellReviewStore.phoneAgentCommand = "在项目目录运行测试，失败时导出日志文件"
        shellReviewStore.startAutonomousComputerTakeover()
        shellReviewStore.approveAndContinueAutonomousLoop()
        let shellMissionSummary = shellReviewStore.missionRunSummary
        if let shellReview = shellMissionSummary.gatewayShellCommandSafetyReview {
            expect(shellReview.reviewCount == 1, "mission summary should count shell command artifacts")
            expect(shellReview.hasMetadata, "shell safety review should include metadata")
            expect(shellReview.mode == "shell-policy-blocked", "shell safety review should expose policy blocked mode")
            expect(shellReview.actionKind == "runShellCommand", "shell safety review should expose action kind")
            expect(shellReview.shellPolicy == "dry-run", "shell safety review should expose dry-run policy")
            expect(shellReview.shellPolicyDiagnostic == "dry-run", "shell safety review should expose policy diagnostic")
            expect(shellReview.shellRetryableReason == "enable-shell", "shell safety review should expose retryable reason")
            expect(shellReview.policyChecked == true, "shell safety review should expose policy checked")
            expect(shellReview.binaryAllowlistChecked == true, "shell safety review should expose binary allowlist checked")
            expect(shellReview.structuredCommandChecked == true, "shell safety review should expose structured command checked")
            expect(shellReview.requiresShellPolicyReview, "shell safety review should require policy review")
            expect(shellReview.structuredCommandPresent == true, "shell safety review should expose structured command presence")
            expect(shellReview.commandParsed == true, "shell safety review should expose parse success")
            expect(shellReview.allowlistMatched == false, "shell safety review should expose allowlist block")
            expect(shellReview.executionAttempted == false, "shell safety review should expose no execution")
            expect(shellReview.executed == false, "shell safety review should expose blocked execution")
            expect(shellReview.commandOmitted == true, "shell safety review should omit command")
            expect(shellReview.stdoutOmitted == true, "shell safety review should omit stdout")
            expect(shellReview.stderrOmitted == true, "shell safety review should omit stderr")
            expect(shellReview.cwdOmitted == true, "shell safety review should omit cwd")
            expect(shellReview.safetyFlags.contains("shell-allowlist-enforced"), "shell safety review should expose allowlist flag")
            expect(shellReview.safetyFlags.contains("command-omitted"), "shell safety review should expose command omission")
        } else {
            failures.append("mission summary should derive shell command safety review")
        }
        expect(
            shellMissionSummary.reviewPriorityQueue.contains { $0.reviewKind == "shell-safety" && $0.severity == .high },
            "review priority queue should prioritize shell safety when shell policy blocks execution"
        )
        expect(
            shellMissionSummary.detailReviewKinds(focusedOn: "shell-safety") == ["shell-safety"],
            "shell focus should show shell detail only"
        )
        let shellReadiness = shellMissionSummary.reviewReadinessSummary
        expect(shellReadiness.criticalOrHighCount >= 1, "shell readiness should count high priority shell review")
        expect(shellReadiness.actionablePriorityCount >= 1, "shell readiness should count actionable shell review")
        let shellNextAction = shellMissionSummary.nextReviewAction(focusedOn: "shell-safety")
        expect(shellNextAction.reviewKind == "shell-safety", "shell next action should focus shell safety")
        expect(shellNextAction.reviewTitle == "Shell 命令安全", "shell next action should expose safe shell title")
        expect(shellNextAction.requiresHumanAction, "shell next action should require human review")
        expect(shellNextAction.canFocusDetailReview, "shell next action should focus shell detail")
        let shellEvidence = shellMissionSummary.artifactEvidenceIndex(focusedOn: "shell-safety")
        if let shellEvidenceItem = shellEvidence.items.first(where: { $0.reviewKind == "shell-safety" }) {
            expect(shellEvidenceItem.hasEvidence, "shell evidence index should mark shell evidence")
            expect(shellEvidenceItem.metadataReady, "shell evidence index should mark metadata ready")
            expect(shellEvidenceItem.artifactKinds.contains(.commandOutput), "shell evidence index should map to command output")
            expect(shellEvidenceItem.isFocused, "shell evidence index should mark focused shell item")
        } else {
            failures.append("shell evidence index should include shell safety")
        }
        let shellPayloadLedger = shellMissionSummary.payloadSafetyLedger(focusedOn: "shell-safety")
        expect(shellPayloadLedger.focusedReviewKind == "shell-safety", "shell payload ledger should record shell focus")
        expect(
            shellPayloadLedger.items.contains { $0.reviewKind == "shell-safety" && $0.isFocused && $0.payloadNotRead },
            "shell payload ledger should mark focused shell payload boundary"
        )
        expect(
            shellPayloadLedger.items.contains { $0.reviewKind == "shell-safety" && $0.safetyFlags.contains("stdout-omitted") },
            "shell payload ledger should retain stdout omission as non-visible safety metadata"
        )
        let shellOperatorStrip = shellMissionSummary.operatorStrip(focusedOn: "shell-safety")
        expect(shellOperatorStrip.focusedReviewKind == "shell-safety", "shell operator strip should record shell focus")
        expect(
            shellOperatorStrip.lanes.contains { $0.id == "next" && $0.reviewKind == "shell-safety" && $0.isFocused },
            "shell operator strip should focus shell next lane"
        )
        let shellEvidenceTrail = shellMissionSummary.evidenceTrailSummary(focusedOn: "shell-safety")
        expect(shellEvidenceTrail.focusedReviewKind == "shell-safety", "shell evidence trail should record shell focus")
        expect(shellEvidenceTrail.focusedReviewTitle == "Shell 命令安全", "shell evidence trail should expose shell title")
        expect(
            shellEvidenceTrail.steps.contains { $0.reviewKind == "shell-safety" && $0.isFocused },
            "shell evidence trail should mark shell focus"
        )
        expect(shellEvidenceTrail.requiresHumanAction, "shell evidence trail should require human review")
        let shellApprovalQueue = shellMissionSummary.approvalQueueSummary(focusedOn: "shell-safety")
        expect(shellApprovalQueue.focusedReviewKind == "shell-safety", "shell approval queue should record shell focus")
        expect(shellApprovalQueue.requiresHumanAction, "shell approval queue should require human review")
        expect(
            shellApprovalQueue.items.contains { $0.reviewKind == "shell-safety" && $0.isFocused },
            "shell approval queue should mark focused shell item"
        )
        expect(
            shellApprovalQueue.items.contains { $0.reviewKind == "shell-safety" && $0.hasMetadata },
            "shell approval queue should mark shell metadata ready"
        )
        let shellApprovalFastLane = shellMissionSummary.approvalFastLane(focusedOn: "shell-safety")
        expect(shellApprovalFastLane.isReviewable, "shell approval fast lane should be reviewable")
        expect(shellApprovalFastLane.laneState == "focused", "shell approval fast lane should expose focus")
        expect(shellApprovalFastLane.primaryReviewKind == "shell-safety", "shell approval fast lane should keep shell focus")
        expect(shellApprovalFastLane.primaryReviewTitle == "Shell 命令安全", "shell approval fast lane should expose shell title")
        expect(shellApprovalFastLane.requiresHumanAction, "shell approval fast lane should require human")
        let shellMacReadiness = shellMissionSummary.macAgentReadinessBoard(focusedOn: "shell-safety")
        expect(shellMacReadiness.isReviewable, "shell mac readiness should be reviewable")
        expect(shellMacReadiness.requiresHumanAction, "shell mac readiness should require human review")
        expect(shellMacReadiness.focusedReviewKind == "shell-safety", "shell mac readiness should record shell focus")
        expect(shellMacReadiness.focusedReviewTitle == "Shell 命令安全", "shell mac readiness should expose shell title")
        expect(
            shellMacReadiness.items.contains { $0.id == "human-gate" && $0.isFocused },
            "shell mac readiness should mark shell human gate"
        )
        let shellActionPreflight = shellMissionSummary.macGatewayActionPreflightMatrix(focusedOn: "shell-safety")
        expect(shellActionPreflight.isReviewable, "shell action preflight should be reviewable")
        expect(shellActionPreflight.requiresHumanAction, "shell action preflight should require human review")
        expect(shellActionPreflight.focusedReviewKind == "shell-safety", "shell action preflight should record shell focus")
        expect(shellActionPreflight.focusedReviewTitle == "Shell 命令安全", "shell action preflight should expose shell title")
        expect(
            shellActionPreflight.items.contains { $0.reviewKind == "shell-safety" && $0.isFocused },
            "shell action preflight should mark shell row"
        )
        expect(
            shellActionPreflight.items.contains { $0.actionKindTitle == ClawMobileActionKind.runShellCommand.title && $0.isRetryable },
            "shell action preflight should expose retryable shell result"
        )
        let shellEvidenceCoverage = shellMissionSummary.macAgentEvidenceCoverageMap(focusedOn: "shell-safety")
        expect(shellEvidenceCoverage.isReviewable, "shell evidence coverage should be reviewable")
        expect(shellEvidenceCoverage.requiresHumanAction, "shell evidence coverage should require human review")
        expect(shellEvidenceCoverage.focusedReviewKind == "shell-safety", "shell evidence coverage should record shell focus")
        expect(shellEvidenceCoverage.focusedReviewTitle == "Shell 命令安全", "shell evidence coverage should expose shell title")
        expect(
            shellEvidenceCoverage.items.contains { $0.reviewKind == "shell-safety" && $0.isFocused && $0.hasEvidence },
            "shell evidence coverage should mark focused shell evidence"
        )
        expect(
            shellEvidenceCoverage.items.contains { $0.reviewKind == "shell-safety" && $0.payloadProtected },
            "shell evidence coverage should carry shell payload boundary"
        )
        let shellFocusContext = shellMissionSummary.focusContextSummary(focusedOn: "shell-safety")
        expect(shellFocusContext.focusedReviewKind == "shell-safety", "shell focus context should record shell focus")
        expect(shellFocusContext.focusedReviewTitle == "Shell 命令安全", "shell focus context should expose shell title")
        expect(shellFocusContext.canFocusDetailReview, "shell focus context should know shell has detail")
        expect(shellFocusContext.canClearFocus, "shell focus context should allow clearing")
        expect(shellFocusContext.hasEvidence, "shell focus context should mark shell evidence")
        expect(shellFocusContext.requiresHumanAction, "shell focus context should require human review")
        let shellDetailDock = shellMissionSummary.reviewDetailDockSummary(focusedOn: "shell-safety")
        expect(shellDetailDock.activeReviewKind == "shell-safety", "shell detail dock should record shell focus")
        expect(shellDetailDock.activeReviewTitle == "Shell 命令安全", "shell detail dock should expose shell title")
        expect(shellDetailDock.detailReviewKinds == ["shell-safety"], "shell detail dock should show shell only")
        expect(shellDetailDock.showsFocusedDetailOnly, "shell detail dock should mark single detail mode")
        expect(shellDetailDock.canClearFocus, "shell detail dock should allow clearing")
        let shellNextStepDeck = shellMissionSummary.macAgentNextStepDeck(focusedOn: "shell-safety")
        expect(shellNextStepDeck.isReviewable, "shell next step deck should be reviewable")
        expect(shellNextStepDeck.requiresHumanAction, "shell next step deck should require human review")
        expect(shellNextStepDeck.isRetryable, "shell next step deck should surface retryable failure")
        expect(shellNextStepDeck.focusedReviewKind == "shell-safety", "shell next step deck should record shell focus")
        expect(shellNextStepDeck.focusedReviewTitle == "Shell 命令安全", "shell next step deck should expose shell title")
        expect(
            shellNextStepDeck.candidates.contains { $0.id == "failure-review" && $0.reviewKind == "shell-safety" && $0.isRetryable },
            "shell next step deck should point retryable failure at shell safety"
        )
        expect(
            shellNextStepDeck.candidates.contains { $0.reviewKind == "shell-safety" && $0.isFocused },
            "shell next step deck should mark shell candidate"
        )
        let shellRunTimeline = shellMissionSummary.macAgentRunTimeline(focusedOn: "shell-safety")
        expect(shellRunTimeline.isReviewable, "shell run timeline should be reviewable")
        expect(shellRunTimeline.requiresHumanAction, "shell run timeline should require human review")
        expect(shellRunTimeline.focusedReviewKind == "shell-safety", "shell run timeline should record shell focus")
        expect(shellRunTimeline.focusedReviewTitle == "Shell 命令安全", "shell run timeline should expose shell title")
        expect(
            shellRunTimeline.steps.contains { $0.reviewKind == "shell-safety" && $0.isFocused && $0.hasEvidence },
            "shell run timeline should mark focused shell evidence"
        )
        expect(
            shellRunTimeline.steps.contains { $0.reviewKind == "shell-safety" && $0.isRetryable },
            "shell run timeline should carry retryable shell state"
        )
        let shellContinuationGate = shellMissionSummary.macAgentContinuationGate(focusedOn: "shell-safety")
        expect(shellContinuationGate.isReviewable, "shell continuation gate should be reviewable")
        expect(shellContinuationGate.requiresHumanAction, "shell continuation gate should require human review")
        expect(shellContinuationGate.isRetryable, "shell continuation gate should surface retryable failure")
        expect(shellContinuationGate.focusedReviewKind == "shell-safety", "shell continuation gate should record shell focus")
        expect(shellContinuationGate.focusedReviewTitle == "Shell 命令安全", "shell continuation gate should expose shell title")
        expect(
            shellContinuationGate.items.contains { $0.id == "review-blockers" && $0.reviewKind == "shell-safety" && $0.isRetryable },
            "shell continuation gate should point retryable blocker at shell safety"
        )
        expect(
            shellContinuationGate.items.contains { $0.reviewKind == "shell-safety" && $0.isFocused },
            "shell continuation gate should mark shell row"
        )
        let shellReviewRadar = shellMissionSummary.macAgentReviewRadar(focusedOn: "shell-safety")
        expect(shellReviewRadar.isReviewable, "shell review radar should be reviewable")
        expect(shellReviewRadar.requiresHumanAction, "shell review radar should require human review")
        expect(shellReviewRadar.focusedReviewKind == "shell-safety", "shell review radar should record shell focus")
        expect(shellReviewRadar.focusedReviewTitle == "Shell 命令安全", "shell review radar should expose shell title")
        expect(
            shellReviewRadar.sectors.contains { $0.reviewKind == "shell-safety" && $0.isFocused },
            "shell review radar should mark shell sector"
        )
        expect(
            shellReviewRadar.sectors.contains { $0.id == "execution-state" && $0.blockedCount > 0 },
            "shell review radar should surface execution blocker"
        )
        let shellHandoffBrief = shellMissionSummary.macAgentHandoffBrief(focusedOn: "shell-safety")
        expect(shellHandoffBrief.isReviewable, "shell handoff brief should be reviewable")
        expect(shellHandoffBrief.requiresHumanAction, "shell handoff brief should require human review")
        expect(shellHandoffBrief.focusedReviewKind == "shell-safety", "shell handoff brief should record shell focus")
        expect(shellHandoffBrief.focusedReviewTitle == "Shell 命令安全", "shell handoff brief should expose shell title")
        expect(
            shellHandoffBrief.items.contains { $0.reviewKind == "shell-safety" && $0.isFocused },
            "shell handoff brief should mark shell item"
        )
        expect(
            shellHandoffBrief.items.contains { $0.id == "blockers" && $0.isBlocked },
            "shell handoff brief should surface blocker"
        )
        let shellControlSnapshot = shellMissionSummary.controlSnapshot(focusedOn: "shell-safety")
        expect(shellControlSnapshot.isReviewable, "shell control snapshot should be reviewable")
        expect(shellControlSnapshot.controlState == "focused", "shell control snapshot should expose focus state")
        expect(shellControlSnapshot.focusedReviewKind == "shell-safety", "shell control snapshot should record shell focus")
        expect(shellControlSnapshot.focusedReviewTitle == "Shell 命令安全", "shell control snapshot should expose shell title")
        expect(shellControlSnapshot.primaryReviewKind == "shell-safety", "shell control snapshot should keep shell primary")
        expect(shellControlSnapshot.requiresHumanAction, "shell control snapshot should require human review")
        let shellPayloadLedgerRows = shellPayloadLedger.items.map { item in
            "\(item.reviewTitle) \(item.status) \(item.guidance)"
        }.joined(separator: " ")
        let shellEvidenceTrailRows = shellEvidenceTrail.steps.map { step in
            "\(step.title) \(step.status) \(step.guidance)"
        }.joined(separator: " ")
        let shellApprovalQueueRows = shellApprovalQueue.items.map { item in
            "\(item.title) \(item.status) \(item.reason)"
        }.joined(separator: " ")
        let shellMacReadinessRows = shellMacReadiness.items.map { item in
            "\(item.title) \(item.status) \(item.guidance)"
        }.joined(separator: " ")
        let shellActionPreflightRows = shellActionPreflight.items.map { item in
            "\(item.title) \(item.actionKindTitle) \(item.status) \(item.guidance)"
        }.joined(separator: " ")
        let shellEvidenceCoverageRows = shellEvidenceCoverage.items.map { item in
            "\(item.reviewTitle) \(item.status) \(item.guidance)"
        }.joined(separator: " ")
        let shellNextStepDeckRows = shellNextStepDeck.candidates.map { item in
            "\(item.title) \(item.status) \(item.guidance)"
        }.joined(separator: " ")
        let shellContinuationGateRows = shellContinuationGate.items.map { item in
            "\(item.title) \(item.status) \(item.guidance)"
        }.joined(separator: " ")
        let shellReviewRadarRows = shellReviewRadar.sectors.map { sector in
            "\(sector.title) \(sector.status) \(sector.guidance)"
        }.joined(separator: " ")
        let shellHandoffBriefRows = shellHandoffBrief.items.map { item in
            "\(item.title) \(item.status) \(item.guidance)"
        }.joined(separator: " ")
        let shellVisibleChunks: [String] = [
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
            shellPayloadLedger.title,
            shellPayloadLedger.status,
            shellPayloadLedger.guidance,
            shellPayloadLedgerRows,
            shellOperatorStrip.status,
            shellEvidenceTrail.title,
            shellEvidenceTrail.status,
            shellEvidenceTrail.guidance,
            shellEvidenceTrailRows,
            shellApprovalQueue.title,
            shellApprovalQueue.status,
            shellApprovalQueue.guidance,
            shellApprovalQueueRows,
            shellApprovalFastLane.title,
            shellApprovalFastLane.status,
            shellApprovalFastLane.guidance,
            shellApprovalFastLane.primaryReviewTitle ?? "",
            shellMacReadiness.title,
            shellMacReadiness.status,
            shellMacReadiness.guidance,
            shellMacReadinessRows,
            shellActionPreflight.title,
            shellActionPreflight.status,
            shellActionPreflight.guidance,
            shellActionPreflightRows,
            shellEvidenceCoverage.title,
            shellEvidenceCoverage.status,
            shellEvidenceCoverage.guidance,
            shellEvidenceCoverageRows,
            shellFocusContext.title,
            shellFocusContext.status,
            shellFocusContext.guidance,
            shellFocusContext.primaryButtonTitle ?? "",
            shellDetailDock.title,
            shellDetailDock.status,
            shellDetailDock.guidance,
            shellDetailDock.activeReviewKind ?? "",
            shellDetailDock.activeReviewTitle ?? "",
            shellNextStepDeck.title,
            shellNextStepDeck.status,
            shellNextStepDeck.guidance,
            shellNextStepDeckRows,
            shellRunTimeline.title,
            shellRunTimeline.status,
            shellRunTimeline.guidance,
            shellRunTimeline.steps.map { "\($0.title) \($0.status) \($0.guidance)" }.joined(separator: " "),
            shellContinuationGate.title,
            shellContinuationGate.status,
            shellContinuationGate.guidance,
            shellContinuationGateRows,
            shellReviewRadar.title,
            shellReviewRadar.status,
            shellReviewRadar.guidance,
            shellReviewRadarRows,
            shellHandoffBrief.title,
            shellHandoffBrief.status,
            shellHandoffBrief.guidance,
            shellHandoffBriefRows,
            shellControlSnapshot.title,
            shellControlSnapshot.status,
            shellControlSnapshot.guidance,
            shellControlSnapshot.primaryReviewTitle ?? ""
        ]
        let shellVisibleText = shellVisibleChunks.joined(separator: " ")
        expect(shellVisibleText.contains("stdout") == false, "shell readiness should not expose stdout")
        if let shellArtifacts = shellReviewStore.clawGatewaySessions.first?.results.first(where: { $0.actionKind == .runShellCommand })?.artifacts,
           let shellReview = ClawGatewayShellCommandSafetyReviewSummary.latest(from: shellArtifacts) {
            expect(shellReview.mode == "shell-policy-blocked", "shell result review should expose policy blocked mode")
            expect(shellReview.executed == false, "shell result review should expose blocked execution")
            expect(shellReview.safetyFlags.contains("stdout-omitted"), "shell result review should omit stdout")
        } else {
            failures.append("shell result should derive shell command safety review")
        }
        if let capabilityReview = missionSummary.gatewayCapabilityReview {
            expect(capabilityReview.snapshotCount == 1, "mission summary should count capability snapshots")
            expect(capabilityReview.hasMetadata, "capability review should include metadata")
            expect(capabilityReview.workspaceState == "workspace-only", "capability review should expose workspace state")
            expect(capabilityReview.shellState == "dry-run", "capability review should expose shell state")
            expect(capabilityReview.browserControlState == "dry-run", "capability review should expose browser state")
            expect(capabilityReview.browserNetworkState == "disabled", "capability review should expose browser network state")
            expect(capabilityReview.accessibilityTreeState == "dry-run", "capability review should expose accessibility tree state")
            expect(capabilityReview.desktopControlState == "dry-run", "capability review should expose desktop state")
            expect(capabilityReview.safetyFlags.contains("raw-token-omitted"), "capability review should expose safety flags")
            expect(capabilityReview.compactStatus.contains("Gateway simulated"), "capability review should summarize gateway platform")
        } else {
            failures.append("mission summary should derive gateway capability review")
        }
        if let accessibilityReview = missionSummary.gatewayAccessibilityReview {
            expect(accessibilityReview.treeCount == 1, "mission summary should count accessibility tree artifacts")
            expect(accessibilityReview.hasMetadata, "accessibility review should include metadata")
            expect(accessibilityReview.mode == "dry-run", "accessibility review should expose dry-run mode")
            expect(accessibilityReview.candidateControlCount == 2, "accessibility review should expose candidate controls")
            expect(accessibilityReview.maxCandidateControls == 20, "accessibility review should expose max controls")
            expect(accessibilityReview.signalQuality == "dry-run", "accessibility review should expose signal quality")
            expect(accessibilityReview.evidenceTier == "degraded", "accessibility review should expose evidence tier")
            expect(accessibilityReview.controlCoverage == "candidate-controls", "accessibility review should expose control coverage")
            expect(accessibilityReview.valuesOmitted == true, "accessibility review should expose value omission")
            expect(accessibilityReview.passwordFieldsOmitted == true, "accessibility review should expose password omission")
            expect(accessibilityReview.rawTextOmitted == true, "accessibility review should expose raw text omission")
            expect(accessibilityReview.actionExecutionSupported == false, "accessibility review should expose observe-only action state")
            expect(accessibilityReview.requiresSignalReview, "dry-run accessibility review should require signal review")
            expect(accessibilityReview.compactStatus.contains("signal dry-run"), "accessibility review should summarize signal quality")
            expect(accessibilityReview.safetyFlags.contains("action-execution-not-supported"), "accessibility review should expose safety flags")
        } else {
            failures.append("mission summary should derive accessibility review")
        }
        if let agentTraceReview = missionSummary.agentTraceReview {
            expect(agentTraceReview.traceCount > 0, "mission summary should count agent traces")
            expect(agentTraceReview.hasMetadata, "agent trace review should include metadata")
            expect(agentTraceReview.readinessScore == 50, "agent trace review should expose readiness score")
            expect(agentTraceReview.satisfiedSignals == ["browserTrace", "fileDiff", "commandOutput"], "agent trace review should expose satisfied signals")
            expect(agentTraceReview.degradedSignals == ["screenObservation", "accessibilityTree"], "agent trace review should expose degraded signals")
            expect(agentTraceReview.missingSignals.contains("messageDraft"), "agent trace review should expose missing signals")
            expect(agentTraceReview.selectedNextActionKind == "composeMessage", "agent trace review should expose selected action")
            expect(agentTraceReview.selectedNextActionRequiresApproval == true, "agent trace review should expose approval requirement")
            expect(agentTraceReview.riskTags.contains("degraded-screen-observation"), "agent trace review should expose degraded risk tags")
            expect(agentTraceReview.riskTags.contains("final-submit-gate"), "agent trace review should expose risk tags")
            expect(agentTraceReview.stopReason == "final-submit", "agent trace review should expose stop reason")
            expect(agentTraceReview.handoffStatus == "final-submit-review", "agent trace review should expose handoff status")
            expect(agentTraceReview.needsHandoffReview, "agent trace review should mark final submit handoff actionable")
            expect(agentTraceReview.isRedacted, "agent trace review should preserve redacted status")
        } else {
            failures.append("mission summary should derive agent trace review")
        }
        let loopContinuation = missionSummary.loopContinuationSummary
        expect(loopContinuation.title == "Loop 最终提交复核", "loop continuation should expose final submit review")
        expect(loopContinuation.handoffStatus == "final-submit-review", "loop continuation should expose handoff status")
        expect(loopContinuation.readinessScore == 50, "loop continuation should expose readiness score")
        expect(loopContinuation.satisfiedSignalCount == 3, "loop continuation should count satisfied signals")
        expect(loopContinuation.degradedSignalCount == 2, "loop continuation should count degraded signals")
        expect(loopContinuation.missingSignalCount == 1, "loop continuation should count missing signals")
        expect(loopContinuation.selectedNextActionKind == "composeMessage", "loop continuation should expose next action")
        expect(loopContinuation.canContinueLoop == false, "loop continuation should not auto-continue final submit")
        expect(loopContinuation.requiresHumanAction, "loop continuation should require human review")
        expect(loopContinuation.canFocusAgentTrace, "loop continuation should focus AgentTrace detail")
        let readyLoopTrace = ClawGatewayArtifact(
            kind: .agentTrace,
            title: "agent-loop-ready",
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
                "handoffSummary": "Evidence score 100/100. Selected next action: extractData."
            ]
        )
        if let readyLoopReview = ClawAgentTraceReviewSummary.latest(from: [readyLoopTrace]) {
            let readyLoopSummary = ClawMissionRunSummary(
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
                agentTraceReview: readyLoopReview,
                gatewayAccessibilityReview: nil,
                gatewayCapabilityReview: nil,
                gatewayTaskReplayGuardReview: nil,
                reviewPriorityQueue: [],
                approvalQueue: [],
                actionPreflightItems: [],
                primaryActionTitle: "继续",
                primaryActionIcon: "arrow.forward.circle.fill",
                primaryActionKind: .continueAfterReview,
                isPrimaryActionEnabled: true,
                requiresUserApproval: false,
                statusLine: "ready",
                stageTrack: []
            )
            let readyLoopContinuation = readyLoopSummary.loopContinuationSummary
            expect(readyLoopContinuation.canContinueLoop, "ready loop continuation should be user-continuable")
            expect(readyLoopContinuation.requiresHumanAction == false, "ready loop continuation should not require approval")
            let readyLoopDeck = readyLoopSummary.macAgentNextStepDeck(focusedOn: "agent-trace")
            expect(readyLoopDeck.isReviewable, "ready loop next step deck should be reviewable")
            expect(readyLoopDeck.canContinueLoop, "ready loop next step deck should surface loop candidate")
            expect(readyLoopDeck.requiresHumanAction == false, "ready loop next step deck should not require human action")
            expect(readyLoopDeck.primaryReviewKind == "agent-trace", "ready loop next step deck should target AgentTrace")
            expect(readyLoopDeck.focusedReviewKind == "agent-trace", "ready loop next step deck should record AgentTrace focus")
            expect(
                readyLoopDeck.candidates.contains { $0.id == "loop-next" && $0.canContinueLoop && $0.reviewKind == "agent-trace" && $0.isFocused },
                "ready loop next step deck should mark the loop candidate"
            )
            expect(
                readyLoopDeck.candidates.contains { $0.guidance.contains("用户显式触发下一轮") },
                "ready loop next step deck should require explicit user continuation"
            )
        } else {
            failures.append("ready loop agent trace review should be derived")
        }
        let sensitiveAgentTrace = ClawGatewayArtifact(
            kind: .agentTrace,
            title: "agent-loop file:///private/tmp/trace.json",
            reference: "file:///tmp/trace.json",
            isRedacted: true,
            metadata: [
                "readinessScore": "51",
                "selectedNextActionKind": "composeMessage token=raw-token",
                "degradedSignals": "accessibilityTree,Authorization: Bearer raw-token,file:///private/tmp/accessibility.json,/Users/alice/window.json",
                "riskTags": "headers={Authorization: Bearer raw-token},C:\\Users\\alice\\secret.txt",
                "stopReason": "final-submit file:///private/tmp/secret.txt /home/alice/secret.txt",
                "handoffStatus": "blocked Authorization: Bearer raw-token /private/tmp/secret.txt",
                "handoffSummary": "Do not expose toolArguments or Authorization: Bearer raw-token from ~/Library/Claw or \\\\server\\share\\claw"
            ]
        )
        if let sensitiveAgentTraceReview = ClawAgentTraceReviewSummary.latest(from: [sensitiveAgentTrace]) {
            let visibleText = [
                sensitiveAgentTraceReview.latestTitle,
                sensitiveAgentTraceReview.compactStatus,
                sensitiveAgentTraceReview.degradedSignals.joined(separator: " "),
                sensitiveAgentTraceReview.riskTags.joined(separator: " "),
                sensitiveAgentTraceReview.stopReason ?? "",
                sensitiveAgentTraceReview.handoffStatus ?? "",
                sensitiveAgentTraceReview.handoffSummary ?? ""
            ].joined(separator: " ")
            expect(sensitiveAgentTraceReview.degradedSignals == ["accessibilityTree"], "agent trace review should keep only safe degraded signals")
            expect(sensitiveAgentTraceReview.handoffStatus == nil, "agent trace review should reject unsafe handoff status")
            expect(visibleText.contains("Authorization") == false, "agent trace review should redact Authorization")
            expect(visibleText.contains("Bearer") == false, "agent trace review should redact bearer token")
            expect(visibleText.contains("raw-token") == false, "agent trace review should redact raw token")
            expect(visibleText.contains("file://") == false, "agent trace review should redact file URLs")
            expect(visibleText.contains("/private") == false, "agent trace review should redact local paths")
            expect(visibleText.contains("/home") == false, "agent trace review should redact Linux home paths")
            expect(visibleText.contains("~/") == false, "agent trace review should redact tilde paths")
            expect(visibleText.contains("C:\\") == false, "agent trace review should redact Windows drive paths")
            expect(visibleText.contains("\\\\server") == false, "agent trace review should redact UNC paths")
            expect(visibleText.contains("toolArguments") == false, "agent trace review should redact toolArguments")
        } else {
            failures.append("sensitive agent trace review should be derived")
        }
        let sensitiveCapability = ClawGatewayArtifact(
            kind: .auditLog,
            title: "gateway-capability file:///private/tmp/snapshot.json",
            reference: "file:///tmp/snapshot.json",
            isRedacted: true,
            metadata: [
                "snapshotKind": "gatewayCapability",
                "tokenFingerprint": "Authorization: Bearer raw-token",
                "allowedActionKinds": "controlBrowser,toolArguments,token=raw-token,C:\\Users\\alice\\secret.txt",
                "workspaceState": "workspace=/private/tmp/claw-work",
                "browserNetworkState": "headers={Authorization: Bearer raw-token}",
                "safetyFlags": "file:///private/tmp/private.txt,headers={Authorization: Bearer raw-token},/home/alice/private.txt",
                "platform": "darwin /private/tmp/claw-work ~/Library/Claw \\\\server\\share\\claw"
            ]
        )
        if let sensitiveCapabilityReview = ClawGatewayCapabilityReviewSummary.latest(from: [sensitiveCapability]) {
            let visibleText = [
                sensitiveCapabilityReview.latestTitle,
                sensitiveCapabilityReview.compactStatus,
                sensitiveCapabilityReview.tokenFingerprint ?? "",
                sensitiveCapabilityReview.allowedActionKinds.joined(separator: " "),
                sensitiveCapabilityReview.workspaceState ?? "",
                sensitiveCapabilityReview.browserNetworkState ?? "",
                sensitiveCapabilityReview.safetyFlags.joined(separator: " "),
                sensitiveCapabilityReview.platform ?? ""
            ].joined(separator: " ")
            expect(visibleText.contains("Authorization") == false, "capability review should redact Authorization")
            expect(visibleText.contains("Bearer") == false, "capability review should redact bearer token")
            expect(visibleText.contains("raw-token") == false, "capability review should redact raw token")
            expect(visibleText.contains("file://") == false, "capability review should redact file URLs")
            expect(visibleText.contains("/private") == false, "capability review should redact local paths")
            expect(visibleText.contains("/home") == false, "capability review should redact Linux home paths")
            expect(visibleText.contains("~/") == false, "capability review should redact tilde paths")
            expect(visibleText.contains("C:\\") == false, "capability review should redact Windows drive paths")
            expect(visibleText.contains("\\\\server") == false, "capability review should redact UNC paths")
            expect(visibleText.contains("toolArguments") == false, "capability review should redact toolArguments")
        } else {
            failures.append("sensitive capability review should be derived")
        }
        let sensitiveExtraction = ClawGatewayArtifact(
            kind: .browserTrace,
            title: "extracted-data file:///private/tmp/extracted.json https://example.com/private-row.json",
            reference: "file:///tmp/extracted.json",
            isRedacted: true,
            metadata: [
                "extractionReview": "artifactGrounded",
                "mode": "artifact-grounded-extraction Authorization: Bearer raw-token",
                "validateCompleteness": "true",
                "rowCount": "2",
                "completenessStatus": "complete file:///private/tmp/secret.json",
                "browserTraceCount": "1",
                "fileDiffCount": "1",
                "commandOutputCount": "1",
                "sourceArtifactKinds": "browserTrace,toolArguments,/home/alice/private.txt,https://example.com/row",
                "safetyFlags": "metadata-only,headers={Authorization: Bearer raw-token},~/Library/Claw/private.txt,https://example.com/row"
            ]
        )
        if let sensitiveExtractionReview = ClawGatewayExtractionCompletenessReviewSummary.latest(from: [sensitiveExtraction]) {
            let visibleText = [
                sensitiveExtractionReview.latestTitle,
                sensitiveExtractionReview.compactStatus,
                sensitiveExtractionReview.mode ?? "",
                sensitiveExtractionReview.completenessStatus ?? "",
                sensitiveExtractionReview.sourceArtifactKinds.joined(separator: " "),
                sensitiveExtractionReview.safetyFlags.joined(separator: " ")
            ].joined(separator: " ")
            expect(visibleText.contains("Authorization") == false, "extraction review should redact Authorization")
            expect(visibleText.contains("Bearer") == false, "extraction review should redact bearer token")
            expect(visibleText.contains("raw-token") == false, "extraction review should redact raw token")
            expect(visibleText.contains("https://") == false, "extraction review should redact web URLs")
            expect(visibleText.contains("file://") == false, "extraction review should redact file URLs")
            expect(visibleText.contains("/private") == false, "extraction review should redact local paths")
            expect(visibleText.contains("/home") == false, "extraction review should redact Linux home paths")
            expect(visibleText.contains("~/") == false, "extraction review should redact tilde paths")
            expect(visibleText.contains("toolArguments") == false, "extraction review should redact toolArguments")
        } else {
            failures.append("sensitive extraction review should be derived")
        }

        let sensitiveBrowserControl = ClawGatewayArtifact(
            kind: .screenshot,
            title: "browser-control file:///private/tmp/browser.json https://example.com/private?q=secret",
            reference: "file:///tmp/browser-control.json",
            isRedacted: true,
            metadata: [
                "browserReview": "controlPlan",
                "mode": "browser-control-dry-run Authorization: Bearer raw-token",
                "actionKind": "controlBrowser token=raw-token",
                "browserControlPolicy": "enabled https://example.com/private",
                "policyDiagnostic": "host-blocked https://example.com/private",
                "retryableReason": "allow-browser-host file:///tmp/log.txt",
                "browserControlRequested": "true",
                "openInBrowser": "true",
                "openAttempted": "false",
                "targetURLPresent": "true",
                "searchQueryPresent": "true",
                "localHTMLInput": "true",
                "networkFetchAttempted": "true",
                "networkBlocked": "true",
                "appAllowlistEnforced": "true",
                "hostAllowlistEnforced": "true",
                "appPolicyChecked": "true",
                "hostPolicyChecked": "true",
                "executed": "false",
                "timedOut": "false",
                "resultStatus": "failed file:///private/tmp/log.txt",
                "safetyFlags": "metadata-only,url-omitted,search-query-omitted,page-content-omitted,form-fields-omitted,candidate-labels-omitted,headers={Authorization: Bearer raw-token},searchQuery=secret,html=<input name=password>,candidateLabel=Submit,toolArguments=/private/tmp/input.json",
                "toolArguments": "{\"url\":\"https://example.com/private\",\"searchQuery\":\"secret\"}"
            ]
        )
        if let sensitiveBrowserReview = ClawGatewayBrowserControlReviewSummary.latest(from: [sensitiveBrowserControl]) {
            let visibleText = [
                sensitiveBrowserReview.latestTitle,
                sensitiveBrowserReview.compactStatus,
                sensitiveBrowserReview.mode ?? "",
                sensitiveBrowserReview.actionKind ?? "",
                sensitiveBrowserReview.browserControlPolicy ?? "",
                sensitiveBrowserReview.policyDiagnostic ?? "",
                sensitiveBrowserReview.retryableReason ?? "",
                sensitiveBrowserReview.resultStatus ?? "",
                sensitiveBrowserReview.safetyFlags.joined(separator: " ")
            ].joined(separator: " ")
            expect(sensitiveBrowserReview.hasMetadata, "browser control review should parse review metadata")
            expect(sensitiveBrowserReview.mode == nil, "browser control review should reject unsafe mode")
            expect(sensitiveBrowserReview.actionKind == nil, "browser control review should reject unsafe action kind")
            expect(sensitiveBrowserReview.browserControlPolicy == nil, "browser control review should reject unsafe policy")
            expect(sensitiveBrowserReview.policyDiagnostic == nil, "browser control review should reject unsafe diagnostic")
            expect(sensitiveBrowserReview.retryableReason == nil, "browser control review should reject unsafe retry reason")
            expect(sensitiveBrowserReview.resultStatus == nil, "browser control review should reject unsafe result")
            expect(sensitiveBrowserReview.openAttempted == false, "browser control review should keep open attempt boolean")
            expect(sensitiveBrowserReview.appPolicyChecked == true, "browser control review should keep app policy boolean")
            expect(sensitiveBrowserReview.hostPolicyChecked == true, "browser control review should keep host policy boolean")
            expect(sensitiveBrowserReview.targetURLPresent == true, "browser control review should keep URL presence boolean")
            expect(sensitiveBrowserReview.searchQueryPresent == true, "browser control review should keep search presence boolean")
            expect(sensitiveBrowserReview.safetyFlags.contains("url-omitted"), "browser control review should expose URL omission flag")
            expect(visibleText.contains("Authorization") == false, "browser control review should redact Authorization")
            expect(visibleText.contains("Bearer") == false, "browser control review should redact bearer token")
            expect(visibleText.contains("raw-token") == false, "browser control review should redact raw token")
            expect(visibleText.contains("https://") == false, "browser control review should redact web URLs")
            expect(visibleText.contains("file://") == false, "browser control review should redact file URLs")
            expect(visibleText.contains("/private") == false, "browser control review should redact local paths")
            expect(visibleText.contains("toolArguments") == false, "browser control review should redact toolArguments")
            expect(visibleText.contains("searchQuery") == false, "browser control review should redact raw search key")
            expect(visibleText.contains("<input") == false, "browser control review should redact HTML")
            expect(visibleText.contains("candidateLabel") == false, "browser control review should redact candidate labels")
        } else {
            failures.append("sensitive browser control review should be derived")
        }

        let sensitiveDelivery = ClawGatewayArtifact(
            kind: .messageDraft,
            title: "draft file:///private/tmp/draft.txt https://example.com/private",
            reference: "file:///tmp/draft.txt",
            isRedacted: true,
            metadata: [
                "deliveryReview": "finalSubmitGate",
                "mode": "message-draft-pending-approval Authorization: Bearer raw-token",
                "actionKind": "composeMessage token=raw-token",
                "targetKind": "message file:///private/tmp/message.txt",
                "desktopPolicyDiagnostic": "app-blocked file:///private/tmp/app",
                "desktopRetryableReason": "allow-desktop-app Authorization: Bearer raw-token",
                "automationAttempted": "true",
                "appPolicyChecked": "true",
                "keyPolicyChecked": "false",
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
        if let sensitiveDeliveryReview = ClawGatewayDeliverySafetyReviewSummary.latest(from: [sensitiveDelivery]) {
            let visibleText = [
                sensitiveDeliveryReview.latestTitle,
                sensitiveDeliveryReview.compactStatus,
                sensitiveDeliveryReview.mode ?? "",
                sensitiveDeliveryReview.actionKind ?? "",
                sensitiveDeliveryReview.targetKind ?? "",
                sensitiveDeliveryReview.desktopPolicyDiagnostic ?? "",
                sensitiveDeliveryReview.desktopRetryableReason ?? "",
                sensitiveDeliveryReview.safetyFlags.joined(separator: " ")
            ].joined(separator: " ")
            expect(sensitiveDeliveryReview.hasMetadata, "delivery safety review should parse review metadata")
            expect(sensitiveDeliveryReview.mode == nil, "delivery safety review should reject unsafe mode")
            expect(sensitiveDeliveryReview.actionKind == nil, "delivery safety review should reject unsafe action kind")
            expect(sensitiveDeliveryReview.targetKind == nil, "delivery safety review should reject unsafe target kind")
            expect(sensitiveDeliveryReview.desktopPolicyDiagnostic == nil, "delivery safety review should reject unsafe desktop diagnostic")
            expect(sensitiveDeliveryReview.desktopRetryableReason == nil, "delivery safety review should reject unsafe desktop retry reason")
            expect(sensitiveDeliveryReview.automationAttempted == true, "delivery safety review should parse automation attempted boolean")
            expect(sensitiveDeliveryReview.appPolicyChecked == true, "delivery safety review should parse app policy boolean")
            expect(sensitiveDeliveryReview.keyPolicyChecked == false, "delivery safety review should parse key policy boolean")
            expect(sensitiveDeliveryReview.finalSubmitRequiresApproval == true, "delivery safety review should parse final submit boolean")
            expect(visibleText.contains("Authorization") == false, "delivery safety review should redact Authorization")
            expect(visibleText.contains("Bearer") == false, "delivery safety review should redact bearer token")
            expect(visibleText.contains("raw-token") == false, "delivery safety review should redact raw token")
            expect(visibleText.contains("draftText") == false, "delivery safety review should redact draftText")
            expect(visibleText.contains("pasteText") == false, "delivery safety review should redact pasteText")
            expect(visibleText.contains("keySequence") == false, "delivery safety review should redact keySequence")
            expect(visibleText.contains("private body") == false, "delivery safety review should redact draft body")
            expect(visibleText.contains("file://") == false, "delivery safety review should redact file URLs")
            expect(visibleText.contains("https://") == false, "delivery safety review should redact web URLs")
            expect(visibleText.contains("/private") == false, "delivery safety review should redact local paths")
            expect(visibleText.contains("toolArguments") == false, "delivery safety review should redact toolArguments")
        } else {
            failures.append("sensitive delivery safety review should be derived")
        }

        let sensitiveFileChange = ClawGatewayArtifact(
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
        if let sensitiveFileReview = ClawGatewayFileChangeSafetyReviewSummary.latest(from: [sensitiveFileChange]) {
            let visibleText = [
                sensitiveFileReview.latestTitle,
                sensitiveFileReview.compactStatus,
                sensitiveFileReview.mode ?? "",
                sensitiveFileReview.actionKind ?? "",
                sensitiveFileReview.workspacePolicy ?? "",
                sensitiveFileReview.resultStatus ?? "",
                sensitiveFileReview.safetyFlags.joined(separator: " ")
            ].joined(separator: " ")
            expect(sensitiveFileReview.hasMetadata, "file change review should parse review metadata")
            expect(sensitiveFileReview.mode == nil, "file change review should reject unsafe mode")
            expect(sensitiveFileReview.actionKind == nil, "file change review should reject unsafe action kind")
            expect(sensitiveFileReview.workspacePolicy == nil, "file change review should reject unsafe workspace policy")
            expect(sensitiveFileReview.resultStatus == nil, "file change review should reject unsafe result status")
            expect(sensitiveFileReview.writeSucceeded == true, "file change review should keep write success boolean")
            expect(sensitiveFileReview.createdFileCount == 1, "file change review should keep safe counts")
            expect(sensitiveFileReview.safetyFlags.contains("raw-path-omitted"), "file change review should expose raw path omission flag")
            expect(visibleText.contains("Authorization") == false, "file change review should redact Authorization")
            expect(visibleText.contains("Bearer") == false, "file change review should redact bearer token")
            expect(visibleText.contains("raw-token") == false, "file change review should redact raw token")
            expect(visibleText.contains("writePath") == false, "file change review should redact writePath")
            expect(visibleText.contains("notes/result.txt") == false, "file change review should redact requested path")
            expect(visibleText.contains("patch") == false, "file change review should redact patch key")
            expect(visibleText.contains("@@") == false, "file change review should redact diff hunks")
            expect(visibleText.contains("private body") == false, "file change review should redact file content")
            expect(visibleText.contains("file://") == false, "file change review should redact file URLs")
            expect(visibleText.contains("/private") == false, "file change review should redact local paths")
            expect(visibleText.contains("/Users") == false, "file change review should redact user paths")
            expect(visibleText.contains("toolArguments") == false, "file change review should redact toolArguments")
        } else {
            failures.append("sensitive file change review should be derived")
        }

        let sensitiveShell = ClawGatewayArtifact(
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
        if let sensitiveShellReview = ClawGatewayShellCommandSafetyReviewSummary.latest(from: [sensitiveShell]) {
            let visibleText = [
                sensitiveShellReview.latestTitle,
                sensitiveShellReview.compactStatus,
                sensitiveShellReview.mode ?? "",
                sensitiveShellReview.actionKind ?? "",
                sensitiveShellReview.shellPolicy ?? "",
                sensitiveShellReview.shellPolicyDiagnostic ?? "",
                sensitiveShellReview.shellRetryableReason ?? "",
                sensitiveShellReview.resultStatus ?? "",
                sensitiveShellReview.safetyFlags.joined(separator: " ")
            ].joined(separator: " ")
            expect(sensitiveShellReview.hasMetadata, "shell safety review should parse review metadata")
            expect(sensitiveShellReview.mode == nil, "shell safety review should reject unsafe mode")
            expect(sensitiveShellReview.actionKind == nil, "shell safety review should reject unsafe action kind")
            expect(sensitiveShellReview.shellPolicy == nil, "shell safety review should reject unsafe policy")
            expect(sensitiveShellReview.shellPolicyDiagnostic == nil, "shell safety review should reject unsafe diagnostic")
            expect(sensitiveShellReview.shellRetryableReason == nil, "shell safety review should reject unsafe retry reason")
            expect(sensitiveShellReview.resultStatus == nil, "shell safety review should reject unsafe result status")
            expect(sensitiveShellReview.policyChecked == true, "shell safety review should keep policy checked boolean")
            expect(sensitiveShellReview.binaryAllowlistChecked == true, "shell safety review should keep binary allowlist boolean")
            expect(sensitiveShellReview.structuredCommandChecked == true, "shell safety review should keep structured checked boolean")
            expect(sensitiveShellReview.requiresShellPolicyReview, "shell safety review should require review when diagnostic rejected")
            expect(sensitiveShellReview.executed == true, "shell safety review should keep execution boolean")
            expect(sensitiveShellReview.exitCodeZero == true, "shell safety review should keep exit code boolean")
            expect(sensitiveShellReview.commandOmitted == true, "shell safety review should keep command omission")
            expect(sensitiveShellReview.safetyFlags.contains("command-omitted"), "shell safety review should expose command omission flag")
            expect(visibleText.contains("Authorization") == false, "shell safety review should redact Authorization")
            expect(visibleText.contains("Bearer") == false, "shell safety review should redact bearer token")
            expect(visibleText.contains("raw-token") == false, "shell safety review should redact raw token")
            expect(visibleText.contains("shellCommand") == false, "shell safety review should redact shellCommand")
            expect(visibleText.contains("pwd") == false, "shell safety review should redact raw command")
            expect(visibleText.contains("stdout") == false || visibleText.contains("stdout-omitted"), "shell safety review should only expose stdout omission flag")
            expect(visibleText.contains("secret stderr") == false, "shell safety review should redact stderr content")
            expect(visibleText.contains("file://") == false, "shell safety review should redact file URLs")
            expect(visibleText.contains("/private") == false, "shell safety review should redact local paths")
            expect(visibleText.contains("/Users") == false, "shell safety review should redact user paths")
            expect(visibleText.contains("toolArguments") == false, "shell safety review should redact toolArguments")
        } else {
            failures.append("sensitive shell command review should be derived")
        }

        let retryMissionStore = ClawStore(autoScanLocalArtifacts: false)
        retryMissionStore.phoneAgentCommand = "在项目目录运行测试，失败时导出日志文件"
        retryMissionStore.startAutonomousComputerTakeover()
        retryMissionStore.approveAndContinueAutonomousLoop()
        expect(retryMissionStore.missionRunSummary.retryableCount > 0, "mission summary should expose retryable failures")
        retryMissionStore.continueAutonomousLoopAfterReview()
        expect(retryMissionStore.missionRunSummary.phaseTitle == ClawAutonomousLoopPhase.completed.title, "mission summary should complete after retry")

        store.setGateway(url: "ws://127.0.0.1:18789", token: "")
        store.gatewayDispatchMode = .liveGateway
        store.queueClawMobileTaskFromCurrentPlan()
        store.approveLatestClawMobileTask()
        store.sendLatestClawMobileTask()
        expect(store.lastGatewayLiveRequest?.canAttemptLive == false, "live gateway should require a paired token")
        expect(store.gatewayEvents.contains { $0.kind == .fallbackUsed }, "live gateway preflight should fallback when not paired")
        expect(store.gatewayLiveHealthSummary.hasFallback, "live health should mark fallback")
        expect(store.gatewayLiveHealthSummary.canAttemptLive == false, "live health should preserve preflight status")
        expect(store.gatewayLiveHealthSummary.detailLine.contains("Authorization") == false, "live health should not expose headers")

        let liveProgressStore = ClawStore(autoScanLocalArtifacts: false)
        liveProgressStore.gatewayDispatchMode = .liveGateway
        liveProgressStore.setGateway(url: "ws://127.0.0.1:18789", token: "paired-secret")
        liveProgressStore.phoneAgentCommand = "打开浏览器搜索资料"
        liveProgressStore.generatePhoneAgentPlan()
        liveProgressStore.queueClawMobileTaskFromCurrentPlan()
        liveProgressStore.approveLatestClawMobileTask()
        liveProgressStore.sendLatestClawMobileTask()
        let liveSession = liveProgressStore.clawGatewaySessions[0]
        liveProgressStore.ingestGatewayEvents([
            ClawGatewayEvent(
                sessionID: liveSession.id,
                taskID: liveSession.taskID,
                sequence: 2,
                kind: .gatewayConnected,
                summary: "Gateway accepted task from Claw Controller"
            ),
            ClawGatewayEvent(
                sessionID: liveSession.id,
                taskID: liveSession.taskID,
                sequence: 3,
                kind: .gatewayConnected,
                summary: "Live Gateway WebSocket 已重连 attempt=2 reconnect=1 ping=ok transportError=network_lost"
            )
        ])
        expect(liveProgressStore.gatewayConnectionState == .streaming, "live progress should keep streaming state")
        expect(liveProgressStore.gatewayLiveHealthSummary.hasGatewayAck, "live health should mark gateway ack")
        expect(liveProgressStore.gatewayLiveHealthSummary.eventCount >= 3, "live health should count session events")
        expect(liveProgressStore.gatewayLiveHealthSummary.transportAttemptCount == 2, "live health should parse transport attempts")
        expect(liveProgressStore.gatewayLiveHealthSummary.reconnectCount == 1, "live health should parse reconnect count")
        expect(liveProgressStore.gatewayLiveHealthSummary.lastPingSucceeded == true, "live health should parse ping status")
        expect(liveProgressStore.gatewayLiveHealthSummary.lastTransportErrorSummary == "network_lost", "live health should parse safe transport error")

        let sensitiveTaskID = UUID()
        let sensitiveSessionID = UUID()
        let sensitiveEndpoint = "ws://user:secret@127.0.0.1:18789/live?token=raw"
        let sensitiveLiveSummary = ClawGatewayLiveHealthSummary.make(
            request: ClawGatewayLiveRequest(
                endpoint: sensitiveEndpoint,
                tokenFingerprint: "sha256:abc123",
                headers: ["Authorization": "Bearer paired-secret"],
                bodyBytes: 128,
                taskID: sensitiveTaskID,
                command: "打开浏览器搜索资料",
                actionCount: 1,
                canAttemptLive: true,
                preflightMessage: "Live Gateway request ready"
            ),
            connectionState: .streaming,
            events: [
                ClawGatewayEvent(
                    sessionID: sensitiveSessionID,
                    taskID: sensitiveTaskID,
                    sequence: 2,
                    kind: .gatewayConnected,
                    summary: "Live Gateway WebSocket 将重连。 attempt=2 reconnect=1 ping=failed transportError=headers={Authorization: Bearer paired-secret} password:open-sesame secret=raw-secret token=raw-token file:///Users/a114514/private.txt workspace=/private/tmp/claw-work"
                )
            ],
            latestSession: nil
        )
        for sensitiveFragment in [
            "paired-secret",
            "Authorization: Bearer",
            "open-sesame",
            "raw-secret",
            "raw-token",
            "/Users/a114514",
            "/private/tmp"
        ] {
            expect(sensitiveLiveSummary.detailLine.contains(sensitiveFragment) == false, "live health detail should redact \(sensitiveFragment)")
            expect(sensitiveLiveSummary.latestEventSummary?.contains(sensitiveFragment) == false, "live health latest event should redact \(sensitiveFragment)")
            expect(sensitiveLiveSummary.lastTransportErrorSummary?.contains(sensitiveFragment) == false, "live health transport error should redact \(sensitiveFragment)")
        }

        let shellPlan = PhoneAgentPlanner.makePlan(
            command: "在项目目录运行测试，失败时导出日志文件",
            capabilities: ClawStore.defaultPhoneAgentCapabilities
        )
        let shellTask = ClawMobileBridge.makeTask(
            from: shellPlan,
            profile: ClawStore.defaultClawGatewayProfile,
            selectedSkill: store.selectedSkill,
            documents: store.documents
        )
        expect(shellTask.actions.contains { $0.kind == .runShellCommand }, "Claw task should include controlled shell")
        expect(shellTask.actions.contains { $0.kind == .manageFiles }, "Claw task should include file management")

        let shellSession = ClawGatewaySimulator.makeSession(
            task: shellTask,
            profile: ClawStore.defaultClawGatewayProfile
        )
        expect(shellSession.results.contains { $0.actionKind == .runShellCommand && $0.isRetryable }, "shell failure should be retryable")
        let retriedSession = ClawGatewaySimulator.retryFailures(in: shellSession)
        expect(retriedSession.retryableCount == 0, "retry should clear retryable failures")

        let fixtureSession = ClawGatewayEventStream.makePreparedSession(
            task: shellTask,
            profile: ClawStore.defaultClawGatewayProfile,
            mode: .liveGateway
        )
        let fixtureEvents = ClawGatewayEventStream.simulatedEvents(
            task: shellTask,
            profile: ClawStore.defaultClawGatewayProfile,
            sessionID: fixtureSession.id,
            startingSequence: 1
        )
        let reducedFixture = fixtureEvents.reduce(fixtureSession) { partial, event in
            ClawGatewayEventStream.apply(event: event, to: partial)
        }
        expect(reducedFixture.results.isEmpty == false, "gateway event reducer should build action results")
        expect(reducedFixture.artifactCount > 0, "gateway event reducer should merge artifacts")
        expect(reducedFixture.sessionArtifacts.contains { $0.kind == .auditLog && $0.title == "gateway-capability-snapshot.json" }, "gateway event reducer should merge session-level artifacts")
        expect(reducedFixture.artifactCount == reducedFixture.allArtifacts.count, "gateway session artifact count should include all artifacts")
        expect(reducedFixture.auditTrail.contains { $0.contains("artifactStored session-level") }, "gateway event reducer should audit session-level artifacts")
        if let reducedCapabilityReview = ClawGatewayCapabilityReviewSummary.latest(from: reducedFixture) {
            expect(reducedCapabilityReview.hasMetadata, "reduced fixture should derive capability metadata")
            expect(reducedCapabilityReview.allowedActionKinds.contains("controlBrowser"), "capability review should expose action allowlist")
        } else {
            failures.append("reduced fixture should derive gateway capability review")
        }
        if let reducedFileChangeReview = ClawGatewayFileChangeSafetyReviewSummary.latest(from: reducedFixture) {
            expect(reducedFileChangeReview.hasMetadata, "reduced fixture should derive file change metadata")
            expect(reducedFileChangeReview.writeSucceeded == true, "fixture file change review should expose write success")
        } else {
            failures.append("reduced fixture should derive file change safety review")
        }
        if let reducedShellReview = ClawGatewayShellCommandSafetyReviewSummary.latest(from: reducedFixture) {
            expect(reducedShellReview.hasMetadata, "reduced fixture should derive shell command metadata")
            expect(reducedShellReview.executed == false, "fixture shell review should expose blocked execution")
        } else {
            failures.append("reduced fixture should derive shell command safety review")
        }

        let replayArtifact = ClawGatewayArtifact(
            kind: .auditLog,
            title: "task-replay-guard.json",
            reference: "file:///private/tmp/claw/session/task-replay-guard.json",
            isRedacted: true,
            metadata: [
                "replayGuard": "taskReplayGuard",
                "decision": "skip-duplicate-task",
                "taskID": shellTask.id.uuidString,
                "replayDigest": "sha256:abcdef1234567890",
                "digestMatchesFirst": "true",
                "firstSessionID": fixtureSession.id.uuidString,
                "originalStatus": "completed",
                "replayCount": "1",
                "actionCount": "\(shellTask.actions.count)",
                "actionKinds": shellTask.actions.map(\.kind.rawValue).joined(separator: ","),
                "safetyFlags": "process-local,actions-skipped,business-artifacts-not-written",
                "toolArguments": "should-not-be-read"
            ]
        )
        let replayEvent = ClawGatewayEvent(
            sessionID: fixtureSession.id,
            taskID: shellTask.id,
            sequence: 99,
            kind: .artifactStored,
            summary: "Stored replay guard artifact",
            artifacts: [replayArtifact]
        )
        let replayReducedFixture = ClawGatewayEventStream.apply(event: replayEvent, to: reducedFixture)
        expect(replayReducedFixture.sessionArtifacts.contains { $0.title == "task-replay-guard.json" }, "replay guard artifact should remain session-level")
        if let replayReview = ClawGatewayTaskReplayGuardReviewSummary.latest(from: replayReducedFixture) {
            expect(replayReview.hasMetadata, "replay guard review should include metadata")
            expect(replayReview.replayCount == 1, "replay guard review should parse replay count")
            expect(replayReview.actionCount == shellTask.actions.count, "replay guard review should parse action count")
            expect(replayReview.digestMatchesFirst == true, "replay guard review should parse digest match")
            expect(replayReview.compactStatus.contains("toolArguments") == false, "replay guard status should ignore unknown sensitive metadata")
            expect(replayReview.compactStatus.contains("file://") == false, "replay guard status should not expose artifact reference")
        } else {
            failures.append("reduced fixture should derive replay guard review")
        }

        var restrictedProfile = ClawStore.defaultClawGatewayProfile
        restrictedProfile.allowedActionKinds.removeAll { $0 == .composeMessage }
        let restrictedTask = ClawMobileBridge.makeTask(
            from: store.phoneAgentPlan,
            profile: restrictedProfile,
            selectedSkill: store.selectedSkill,
            documents: store.documents
        )
        expect(restrictedTask.status == .blocked, "gateway whitelist should block disallowed message actions")

        store.phoneAgentCommand = "读取微信新消息并自动回复客户"
        store.generatePhoneAgentPlan()
        store.queueClawMobileTaskFromCurrentPlan()
        expect(store.clawMobileTasks[0].status == .blocked, "unsupported iOS action should keep Claw task blocked")

        if failures.isEmpty {
            print("Claw logic smoke passed")
        } else {
            print("Claw logic smoke failed:")
            for failure in failures {
                print("- \(failure)")
            }
            Foundation.exit(1)
        }
    }
}
