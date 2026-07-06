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
        let idleFocusContext = missionStore.missionRunSummary.focusContextSummary
        expect(idleFocusContext.isReviewable == false, "idle focus context should not be reviewable")
        expect(idleFocusContext.canClearFocus == false, "idle focus context should not expose clear focus")
        expect(idleFocusContext.primaryReviewKind == nil, "idle focus context should not invent a primary review")
        missionStore.phoneAgentCommand = "打开浏览器搜索资料，整理结果并发到 Slack"
        missionStore.startAutonomousComputerTakeover()
        var missionSummary = missionStore.missionRunSummary
        expect(missionSummary.primaryActionKind == .approveAndContinue, "mission summary should stop at approval gate")
        expect(missionSummary.requiresUserApproval, "mission summary should surface approval requirements")
        expect(missionSummary.riskScore > 0, "mission summary should include task risk")
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
        let staleFocusContext = statusOnlySummary.focusContextSummary(focusedOn: "unknown-review-kind")
        expect(staleFocusContext.focusedReviewKind == nil, "stale focus context should not keep an unknown review kind")
        expect(staleFocusContext.canClearFocus, "stale focus context should allow clearing focus")
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
            focusedFocusContext.focusedReviewTitle ?? ""
        ]
        let queueVisibleText = (queueVisibleChunks + readinessVisibleChunks + nextActionVisibleChunks + evidenceVisibleChunks + operatorVisibleChunks + focusContextVisibleChunks).joined(separator: " ")
        for forbidden in ["Authorization", "Bearer", "toolArguments", "file://", "/private", "/Users", "/home", "C:\\", "stdout", "stderr", "diff"] {
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
            expect(browserReview.browserControlRequested == true, "browser control review should expose requested open")
            expect(browserReview.targetURLPresent == true, "browser control review should expose URL presence without value")
            expect(browserReview.searchQueryPresent == true, "browser control review should expose search presence without value")
            expect(browserReview.networkBlocked == false, "browser control review should expose network block state")
            expect(browserReview.resultStatus == "succeeded", "browser control review should expose result status")
            expect(browserReview.safetyFlags.contains("url-omitted"), "browser control review should omit URL")
            expect(browserReview.safetyFlags.contains("search-query-omitted"), "browser control review should omit search query")
            expect(browserReview.compactStatus.contains("policy dry-run"), "browser control review should summarize policy")
        } else {
            failures.append("mission summary should derive browser control review")
        }
        if let browserArtifacts = missionStore.clawGatewaySessions.first?.results.first(where: { $0.actionKind == .controlBrowser })?.artifacts,
           let browserControlReview = ClawGatewayBrowserControlReviewSummary.latest(from: browserArtifacts) {
            expect(browserControlReview.mode == "browser-control-dry-run", "browser result review should expose dry-run mode")
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
        let shellOperatorStrip = shellMissionSummary.operatorStrip(focusedOn: "shell-safety")
        expect(shellOperatorStrip.focusedReviewKind == "shell-safety", "shell operator strip should record shell focus")
        expect(
            shellOperatorStrip.lanes.contains { $0.id == "next" && $0.reviewKind == "shell-safety" && $0.isFocused },
            "shell operator strip should focus shell next lane"
        )
        let shellFocusContext = shellMissionSummary.focusContextSummary(focusedOn: "shell-safety")
        expect(shellFocusContext.focusedReviewKind == "shell-safety", "shell focus context should record shell focus")
        expect(shellFocusContext.focusedReviewTitle == "Shell 命令安全", "shell focus context should expose shell title")
        expect(shellFocusContext.canFocusDetailReview, "shell focus context should know shell has detail")
        expect(shellFocusContext.canClearFocus, "shell focus context should allow clearing")
        expect(shellFocusContext.hasEvidence, "shell focus context should mark shell evidence")
        expect(shellFocusContext.requiresHumanAction, "shell focus context should require human review")
        expect(
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
                shellOperatorStrip.status,
                shellFocusContext.title,
                shellFocusContext.status,
                shellFocusContext.guidance,
                shellFocusContext.primaryButtonTitle ?? ""
            ].joined(separator: " ").contains("stdout") == false,
            "shell readiness should not expose stdout"
        )
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
        if let sensitiveBrowserReview = ClawGatewayBrowserControlReviewSummary.latest(from: [sensitiveBrowserControl]) {
            let visibleText = [
                sensitiveBrowserReview.latestTitle,
                sensitiveBrowserReview.compactStatus,
                sensitiveBrowserReview.mode ?? "",
                sensitiveBrowserReview.actionKind ?? "",
                sensitiveBrowserReview.browserControlPolicy ?? "",
                sensitiveBrowserReview.resultStatus ?? "",
                sensitiveBrowserReview.safetyFlags.joined(separator: " ")
            ].joined(separator: " ")
            expect(sensitiveBrowserReview.hasMetadata, "browser control review should parse review metadata")
            expect(sensitiveBrowserReview.mode == nil, "browser control review should reject unsafe mode")
            expect(sensitiveBrowserReview.actionKind == nil, "browser control review should reject unsafe action kind")
            expect(sensitiveBrowserReview.browserControlPolicy == nil, "browser control review should reject unsafe policy")
            expect(sensitiveBrowserReview.resultStatus == nil, "browser control review should reject unsafe result")
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
                sensitiveDeliveryReview.safetyFlags.joined(separator: " ")
            ].joined(separator: " ")
            expect(sensitiveDeliveryReview.hasMetadata, "delivery safety review should parse review metadata")
            expect(sensitiveDeliveryReview.mode == nil, "delivery safety review should reject unsafe mode")
            expect(sensitiveDeliveryReview.actionKind == nil, "delivery safety review should reject unsafe action kind")
            expect(sensitiveDeliveryReview.targetKind == nil, "delivery safety review should reject unsafe target kind")
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
                sensitiveShellReview.resultStatus ?? "",
                sensitiveShellReview.safetyFlags.joined(separator: " ")
            ].joined(separator: " ")
            expect(sensitiveShellReview.hasMetadata, "shell safety review should parse review metadata")
            expect(sensitiveShellReview.mode == nil, "shell safety review should reject unsafe mode")
            expect(sensitiveShellReview.actionKind == nil, "shell safety review should reject unsafe action kind")
            expect(sensitiveShellReview.shellPolicy == nil, "shell safety review should reject unsafe policy")
            expect(sensitiveShellReview.resultStatus == nil, "shell safety review should reject unsafe result status")
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
