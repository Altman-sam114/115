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
        missionStore.phoneAgentCommand = "打开浏览器搜索资料并发到 Slack"
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
