import CryptoKit
import Foundation

@MainActor
final class ClawStore: ObservableObject {
    @Published private(set) var model: LocalClawModel
    @Published private(set) var validation: ArtifactValidationResult
    @Published var selectedCategory: ClawCapabilityCategory?
    @Published var selectedSkill: ClawSkill?
    @Published var query: String
    @Published private(set) var messages: [ChatMessage]
    @Published private(set) var documents: [WorkspaceContext]
    @Published private(set) var skills: [ClawSkill]
    @Published private(set) var automationTargets: [AutomationTarget]
    @Published var gatewayURL: String
    @Published var gatewayToken: String
    @Published private(set) var lastAutomationDraft: String
    @Published private(set) var phoneAgentCapabilities: [PhoneAgentCapability]
    @Published var phoneAgentCommand: String
    @Published private(set) var phoneAgentPlan: PhoneAgentPlan
    @Published private(set) var phoneAgentExecutionLog: String
    @Published private(set) var clawGatewayProfile: ClawGatewayProfile
    @Published private(set) var clawMobileTasks: [ClawMobileTask]
    @Published private(set) var lastClawMobileEnvelope: String
    @Published private(set) var clawGatewaySessions: [ClawGatewaySession]
    @Published private(set) var lastGatewayEvent: String
    @Published var gatewayDispatchMode: ClawGatewayDispatchMode
    @Published private(set) var gatewayConnectionState: ClawGatewayConnectionState
    @Published private(set) var lastGatewayLiveRequest: ClawGatewayLiveRequest?
    @Published private(set) var gatewayEvents: [ClawGatewayEvent]
    @Published private(set) var autonomousLoop: ClawAutonomousLoopState

    private let artifactDirectoryURL: URL

    init(
        model: LocalClawModel? = nil,
        artifactDirectoryURL: URL = ModelArtifactStore.defaultDirectoryURL(),
        autoScanLocalArtifacts: Bool = true
    ) {
        let resolvedModel = model ?? ClawStore.defaultModel
        let capabilities = ClawStore.defaultPhoneAgentCapabilities
        let starterCommand = "接管我的电脑，打开浏览器搜索竞品信息，整理成表格后发到 Slack"
        self.model = resolvedModel
        self.artifactDirectoryURL = artifactDirectoryURL
        self.validation = LocalArtifactValidator.validate(
            manifest: resolvedModel.artifactManifest,
            presentFiles: []
        )
        self.selectedCategory = nil
        self.selectedSkill = ClawStore.defaultSkills.first
        self.query = ""
        self.messages = ClawStore.initialMessages
        self.documents = ClawStore.defaultDocuments
        self.skills = ClawStore.defaultSkills
        self.automationTargets = ClawStore.defaultAutomationTargets
        self.gatewayURL = "ws://192.168.1.12:18789"
        self.gatewayToken = ""
        self.lastAutomationDraft = "尚未生成自动化 payload。"
        self.phoneAgentCapabilities = capabilities
        self.phoneAgentCommand = starterCommand
        self.phoneAgentPlan = PhoneAgentPlanner.makePlan(
            command: starterCommand,
            capabilities: capabilities
        )
        self.phoneAgentExecutionLog = "尚未执行 Claw 电脑接管计划。"
        self.clawGatewayProfile = ClawStore.defaultClawGatewayProfile
        self.clawMobileTasks = []
        self.lastClawMobileEnvelope = "尚未生成 Claw computer-control envelope。"
        self.clawGatewaySessions = []
        self.lastGatewayEvent = "尚未创建 Claw Gateway session。"
        self.gatewayDispatchMode = .simulatedEventStream
        self.gatewayConnectionState = .idle
        self.lastGatewayLiveRequest = nil
        self.gatewayEvents = []
        self.autonomousLoop = ClawAutonomousLoopState(
            phase: .idle,
            runMode: .simulatedEventStream,
            iteration: 0,
            maxIterations: 3,
            command: starterCommand,
            statusLine: "自治循环空闲。输入任务后可一键生成计划、排队任务并等待审批。",
            lastDecision: "尚未启动。",
            requiresUserApproval: false
        )

        if autoScanLocalArtifacts {
            scanLocalArtifacts()
        }
    }

    var visibleSkills: [ClawSkill] {
        guard let selectedCategory else {
            return skills
        }
        return skills.filter { $0.category == selectedCategory }
    }

    var rankedSkills: [ClawSkill] {
        skills.sorted {
            if $0.popularity == $1.popularity {
                return $0.runCount > $1.runCount
            }
            return $0.popularity > $1.popularity
        }
    }

    var installedStatusText: String {
        "\(model.installState.title) / \(validation.availability.title)"
    }

    var phoneAgentBoundaryText: String {
        "这个原型把 iPhone 当作 Claw 控制台：手机负责下达任务、审批高风险动作和查看审计；真正的电脑接管由用户自托管的 Claw Gateway 在桌面端执行。"
    }

    var clawMobileStatusText: String {
        "\(clawGatewayProfile.securityMode.title) / \(clawMobileTasks.count) 个任务 / \(clawGatewaySessions.count) 个会话"
    }

    var gatewayConnectionText: String {
        "\(gatewayDispatchMode.title) / \(gatewayConnectionState.title)"
    }

    var gatewayLiveHealthSummary: ClawGatewayLiveHealthSummary {
        let latestSession = clawGatewaySessions.first
        let sessionEvents: [ClawGatewayEvent]
        if let latestSession {
            sessionEvents = gatewayEvents.filter { $0.sessionID == latestSession.id }
        } else {
            sessionEvents = []
        }
        return ClawGatewayLiveHealthSummary.make(
            request: lastGatewayLiveRequest,
            connectionState: gatewayConnectionState,
            events: sessionEvents,
            latestSession: latestSession
        )
    }

    var autonomousLoopStatusText: String {
        "\(autonomousLoop.phase.title) / \(autonomousLoop.iteration)-\(autonomousLoop.maxIterations) / \(autonomousLoop.runMode.title)"
    }

    var missionRunSummary: ClawMissionRunSummary {
        let task = clawMobileTasks.first
        let session = clawGatewaySessions.first
        let phase = missionRunPhase(task: task, session: session)
        let primaryAction = missionRunPrimaryAction(for: phase, session: session)
        let command = missionRunCommand(task: task, session: session)
        let progressTotal = max(autonomousLoop.maxIterations, 1)
        let progressCurrent = phase == .idle ? 0 : min(max(autonomousLoop.iteration, 1), progressTotal)
        let artifactKinds = missionRunArtifactKinds(from: session)
        let artifactMetadataReview = missionRunArtifactMetadataReview(from: session)
        let gatewayExtractionCompletenessReview = missionRunGatewayExtractionCompletenessReview(from: session)
        let gatewayBrowserControlReview = missionRunGatewayBrowserControlReview(from: session)
        let gatewayDeliverySafetyReview = missionRunGatewayDeliverySafetyReview(from: session)
        let gatewayFileChangeSafetyReview = missionRunGatewayFileChangeSafetyReview(from: session)
        let gatewayShellCommandSafetyReview = missionRunGatewayShellCommandSafetyReview(from: session)
        let agentTraceReview = missionRunAgentTraceReview(from: session)
        let gatewayAccessibilityReview = missionRunGatewayAccessibilityReview(from: session)
        let gatewayCapabilityReview = missionRunGatewayCapabilityReview(from: session)
        let gatewayTaskReplayGuardReview = missionRunGatewayTaskReplayGuardReview(from: session)
        let requiresUserApproval = autonomousLoop.requiresUserApproval || task?.status == .waitingForApproval || session?.status == .needsAttention

        return ClawMissionRunSummary(
            command: command,
            phaseTitle: phase.title,
            phaseIcon: phase.icon,
            progressCurrent: progressCurrent,
            progressTotal: progressTotal,
            riskScore: task?.riskScore ?? 0,
            approvalCount: task?.approvalCount ?? phoneAgentPlan.confirmationCount,
            blockedCount: task?.blockedCount ?? phoneAgentPlan.blockedCount,
            succeededCount: session?.succeededCount ?? 0,
            failedCount: session?.failedCount ?? 0,
            retryableCount: session?.retryableCount ?? 0,
            artifactCount: session?.artifactCount ?? 0,
            artifactKinds: artifactKinds,
            artifactMetadataReview: artifactMetadataReview,
            gatewayExtractionCompletenessReview: gatewayExtractionCompletenessReview,
            gatewayBrowserControlReview: gatewayBrowserControlReview,
            gatewayDeliverySafetyReview: gatewayDeliverySafetyReview,
            gatewayFileChangeSafetyReview: gatewayFileChangeSafetyReview,
            gatewayShellCommandSafetyReview: gatewayShellCommandSafetyReview,
            agentTraceReview: agentTraceReview,
            gatewayAccessibilityReview: gatewayAccessibilityReview,
            gatewayCapabilityReview: gatewayCapabilityReview,
            gatewayTaskReplayGuardReview: gatewayTaskReplayGuardReview,
            reviewPriorityQueue: missionRunReviewPriorityQueue(
                phase: phase,
                task: task,
                session: session,
                requiresUserApproval: requiresUserApproval,
                artifactMetadataReview: artifactMetadataReview,
                gatewayExtractionCompletenessReview: gatewayExtractionCompletenessReview,
                gatewayBrowserControlReview: gatewayBrowserControlReview,
                gatewayDeliverySafetyReview: gatewayDeliverySafetyReview,
                gatewayFileChangeSafetyReview: gatewayFileChangeSafetyReview,
                gatewayShellCommandSafetyReview: gatewayShellCommandSafetyReview,
                agentTraceReview: agentTraceReview,
                gatewayAccessibilityReview: gatewayAccessibilityReview,
                gatewayCapabilityReview: gatewayCapabilityReview,
                gatewayTaskReplayGuardReview: gatewayTaskReplayGuardReview
            ),
            primaryActionTitle: primaryAction.title,
            primaryActionIcon: primaryAction.icon,
            primaryActionKind: primaryAction.kind,
            isPrimaryActionEnabled: primaryAction.isEnabled,
            requiresUserApproval: requiresUserApproval,
            statusLine: missionRunStatusLine(phase: phase, task: task, session: session),
            stageTrack: missionRunStageTrack(phase: phase, session: session)
        )
    }

    private func missionRunCommand(task: ClawMobileTask?, session: ClawGatewaySession?) -> String {
        let candidates = [
            session?.command,
            task?.command,
            autonomousLoop.command,
            phoneAgentCommand
        ]
        for candidate in candidates {
            let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmed.isEmpty == false {
                return trimmed
            }
        }
        return "描述要让桌面 Gateway 完成的电脑任务"
    }

    private func missionRunPhase(task: ClawMobileTask?, session: ClawGatewaySession?) -> ClawAutonomousLoopPhase {
        if autonomousLoop.phase != .idle {
            return autonomousLoop.phase
        }
        if let session {
            switch session.status {
            case .prepared, .running:
                return .observingGateway
            case .completed:
                return .completed
            case .needsAttention:
                return .needsAttention
            case .blocked:
                return .blocked
            }
        }
        if let task {
            switch task.status {
            case .queued:
                return .planning
            case .waitingForApproval:
                return .waitingForUserApproval
            case .readyToSend:
                return .dispatching
            case .sent:
                return .observingGateway
            case .blocked:
                return .blocked
            }
        }
        return .idle
    }

    private func missionRunPrimaryAction(
        for phase: ClawAutonomousLoopPhase,
        session: ClawGatewaySession?
    ) -> (title: String, icon: String, kind: ClawMissionRunPrimaryActionKind, isEnabled: Bool) {
        switch phase {
        case .idle:
            return ("启动任务回合", "play.fill", .start, true)
        case .planning:
            return ("生成计划中", "list.bullet.rectangle.portrait.fill", .waitForGateway, false)
        case .waitingForUserApproval:
            return ("审批并继续", "checkmark.seal.fill", .approveAndContinue, true)
        case .dispatching, .observingGateway:
            return ("等待桌面 Gateway 事件", "hourglass", .waitForGateway, false)
        case .needsAttention:
            if (session?.retryableCount ?? 0) > 0 {
                return ("复核后重试", "arrow.clockwise.circle.fill", .continueAfterReview, true)
            }
            return ("查看处理要求", "exclamationmark.magnifyingglass", .continueAfterReview, true)
        case .completed:
            return ("重新启动当前任务", "play.circle.fill", .start, true)
        case .blocked:
            return ("修改任务或白名单", "lock.trianglebadge.exclamationmark.fill", .inspectBlocked, false)
        }
    }

    private func missionRunStatusLine(
        phase: ClawAutonomousLoopPhase,
        task: ClawMobileTask?,
        session: ClawGatewaySession?
    ) -> String {
        switch phase {
        case .idle:
            return "手机端只负责计划、审批和查看证据；真实电脑动作由用户授权的桌面 Gateway 执行。"
        case .waitingForUserApproval:
            return "计划已生成，\(task?.approvalCount ?? phoneAgentPlan.confirmationCount) 个审批点需要手机端确认后才会发送。"
        case .needsAttention:
            let waiting = session?.results.filter { $0.status == .waitingForApproval }.count ?? 0
            return "Gateway 需要复核：失败 \(session?.failedCount ?? 0) 个，可重试 \(session?.retryableCount ?? 0) 个，待确认 \(waiting) 个。"
        case .completed:
            return "任务回合完成：成功 \(session?.succeededCount ?? 0) 个动作，收集 \(session?.artifactCount ?? 0) 个 artifact。"
        case .blocked:
            if let replayReview = missionRunGatewayTaskReplayGuardReview(from: session) {
                let replayCount = replayReview.replayCount.map { "重复 \($0) 次" } ?? "重复任务"
                let actionCount = replayReview.actionCount.map { "跳过 \($0) 个动作" } ?? "已跳过动作"
                return "Gateway Replay Guard 已识别\(replayCount)，\(actionCount)，未重新执行桌面 handler。"
            }
            return "任务被安全策略阻断：\(task?.blockedCount ?? phoneAgentPlan.blockedCount) 个动作不能自动发送，请修改任务或网关白名单。"
        default:
            return autonomousLoop.statusLine
        }
    }

    private func missionRunArtifactKinds(from session: ClawGatewaySession?) -> [ClawGatewayArtifactKind] {
        guard let session else {
            return []
        }
        var seen: Set<ClawGatewayArtifactKind> = []
        var kinds: [ClawGatewayArtifactKind] = []
        for artifact in session.allArtifacts {
            if seen.insert(artifact.kind).inserted {
                kinds.append(artifact.kind)
            }
        }
        return kinds
    }

    private func missionRunAgentTraceReview(from session: ClawGatewaySession?) -> ClawAgentTraceReviewSummary? {
        ClawAgentTraceReviewSummary.latest(from: session)
    }

    private func missionRunArtifactMetadataReview(from session: ClawGatewaySession?) -> ClawGatewayArtifactMetadataReviewSummary? {
        ClawGatewayArtifactMetadataReviewSummary.latest(from: session)
    }

    private func missionRunGatewayExtractionCompletenessReview(from session: ClawGatewaySession?) -> ClawGatewayExtractionCompletenessReviewSummary? {
        ClawGatewayExtractionCompletenessReviewSummary.latest(from: session)
    }

    private func missionRunGatewayBrowserControlReview(from session: ClawGatewaySession?) -> ClawGatewayBrowserControlReviewSummary? {
        ClawGatewayBrowserControlReviewSummary.latest(from: session)
    }

    private func missionRunGatewayDeliverySafetyReview(from session: ClawGatewaySession?) -> ClawGatewayDeliverySafetyReviewSummary? {
        ClawGatewayDeliverySafetyReviewSummary.latest(from: session)
    }

    private func missionRunGatewayFileChangeSafetyReview(from session: ClawGatewaySession?) -> ClawGatewayFileChangeSafetyReviewSummary? {
        ClawGatewayFileChangeSafetyReviewSummary.latest(from: session)
    }

    private func missionRunGatewayShellCommandSafetyReview(from session: ClawGatewaySession?) -> ClawGatewayShellCommandSafetyReviewSummary? {
        ClawGatewayShellCommandSafetyReviewSummary.latest(from: session)
    }

    private func missionRunGatewayAccessibilityReview(from session: ClawGatewaySession?) -> ClawGatewayAccessibilityReviewSummary? {
        ClawGatewayAccessibilityReviewSummary.latest(from: session)
    }

    private func missionRunGatewayCapabilityReview(from session: ClawGatewaySession?) -> ClawGatewayCapabilityReviewSummary? {
        ClawGatewayCapabilityReviewSummary.latest(from: session)
    }

    private func missionRunGatewayTaskReplayGuardReview(from session: ClawGatewaySession?) -> ClawGatewayTaskReplayGuardReviewSummary? {
        ClawGatewayTaskReplayGuardReviewSummary.latest(from: session)
    }

    private func missionRunReviewPriorityQueue(
        phase: ClawAutonomousLoopPhase,
        task: ClawMobileTask?,
        session: ClawGatewaySession?,
        requiresUserApproval: Bool,
        artifactMetadataReview: ClawGatewayArtifactMetadataReviewSummary?,
        gatewayExtractionCompletenessReview: ClawGatewayExtractionCompletenessReviewSummary?,
        gatewayBrowserControlReview: ClawGatewayBrowserControlReviewSummary?,
        gatewayDeliverySafetyReview: ClawGatewayDeliverySafetyReviewSummary?,
        gatewayFileChangeSafetyReview: ClawGatewayFileChangeSafetyReviewSummary?,
        gatewayShellCommandSafetyReview: ClawGatewayShellCommandSafetyReviewSummary?,
        agentTraceReview: ClawAgentTraceReviewSummary?,
        gatewayAccessibilityReview: ClawGatewayAccessibilityReviewSummary?,
        gatewayCapabilityReview: ClawGatewayCapabilityReviewSummary?,
        gatewayTaskReplayGuardReview: ClawGatewayTaskReplayGuardReviewSummary?
    ) -> [ClawMissionRunReviewPriorityItem] {
        var items: [ClawMissionRunReviewPriorityItem] = []

        func add(
            id: String,
            rank: Int,
            severity: ClawMissionRunReviewPrioritySeverity,
            title: String,
            status: String,
            reason: String,
            icon: String,
            reviewKind: String,
            actionHint: String,
            isActionable: Bool,
            hasMetadata: Bool
        ) {
            items.append(
                ClawMissionRunReviewPriorityItem(
                    id: id,
                    rank: rank,
                    severity: severity,
                    title: title,
                    status: status,
                    reason: reason,
                    icon: icon,
                    reviewKind: reviewKind,
                    actionHint: actionHint,
                    isActionable: isActionable,
                    hasMetadata: hasMetadata
                )
            )
        }

        if phase == .waitingForUserApproval || (requiresUserApproval && session == nil) {
            let count = task?.approvalCount ?? phoneAgentPlan.confirmationCount
            add(
                id: "approval",
                rank: 10,
                severity: .critical,
                title: "手机审批",
                status: "\(count) 个审批点待确认",
                reason: "任务尚未发送到桌面 Gateway。",
                icon: "checkmark.seal.fill",
                reviewKind: "approval",
                actionHint: "审批计划后继续",
                isActionable: true,
                hasMetadata: true
            )
        }

        if let session {
            if session.status == .blocked {
                add(
                    id: "gateway-status-blocked",
                    rank: 12,
                    severity: .critical,
                    title: "Gateway 阻断",
                    status: session.status.title,
                    reason: "安全策略阻断任务或重复提交。",
                    icon: "lock.trianglebadge.exclamationmark.fill",
                    reviewKind: "gateway-status",
                    actionHint: "检查白名单或任务约束",
                    isActionable: true,
                    hasMetadata: true
                )
            } else if session.failedCount > 0 || session.retryableCount > 0 {
                add(
                    id: "gateway-status-needs-attention",
                    rank: 18,
                    severity: .high,
                    title: "Gateway 结果",
                    status: "失败 \(session.failedCount) · 可重试 \(session.retryableCount)",
                    reason: "至少一个动作需要人工复核。",
                    icon: "exclamationmark.arrow.triangle.2.circlepath",
                    reviewKind: "gateway-status",
                    actionHint: "查看失败动作和重试条件",
                    isActionable: true,
                    hasMetadata: true
                )
            }
        } else if task?.status == .blocked || phase == .blocked {
            add(
                id: "gateway-status-task-blocked",
                rank: 18,
                severity: .critical,
                title: "任务阻断",
                status: "\(task?.blockedCount ?? phoneAgentPlan.blockedCount) 个动作不可发送",
                reason: "任务需要修改或 Gateway allowlist 未覆盖。",
                icon: "nosign",
                reviewKind: "gateway-status",
                actionHint: "修改任务或白名单",
                isActionable: true,
                hasMetadata: true
            )
        }

        if let review = gatewayTaskReplayGuardReview {
            add(
                id: "replay-guard",
                rank: 20,
                severity: review.hasMetadata ? .critical : .high,
                title: "Replay Guard",
                status: review.compactStatus,
                reason: review.hasMetadata ? "重复任务已由 Gateway 跳过。" : "Replay Guard metadata 待同步。",
                icon: "rectangle.stack.badge.person.crop.fill",
                reviewKind: "replay-guard",
                actionHint: "确认是否需要新 task id",
                isActionable: true,
                hasMetadata: review.hasMetadata
            )
        }

        if let review = gatewayDeliverySafetyReview {
            let blocked = review.finalSubmitRequiresApproval == true || review.submitBlocked == true || review.userApprovalRequired == true
            add(
                id: "delivery-safety",
                rank: blocked ? 30 : 82,
                severity: review.hasMetadata == false ? .high : (blocked ? .high : .info),
                title: "最终提交安全",
                status: review.compactStatus,
                reason: review.hasMetadata ? "草稿或桌面提交需要人工复核。" : "草稿/提交 metadata 待同步。",
                icon: "hand.raised.fill",
                reviewKind: "delivery-safety",
                actionHint: blocked ? "确认草稿和提交闸门" : "抽查提交策略",
                isActionable: blocked || review.hasMetadata == false,
                hasMetadata: review.hasMetadata
            )
        }

        if let review = gatewayShellCommandSafetyReview {
            let needsReview = review.hasMetadata == false || review.resultStatus == "failed" || review.executed == true || review.executionAttempted == true
            add(
                id: "shell-safety",
                rank: needsReview ? 34 : 84,
                severity: review.hasMetadata == false ? .high : (needsReview ? .high : .info),
                title: "Shell 命令安全",
                status: review.compactStatus,
                reason: review.hasMetadata ? "只展示结构化命令安全状态。" : "Shell metadata 待同步。",
                icon: "terminal.fill",
                reviewKind: "shell-safety",
                actionHint: needsReview ? "确认 policy、allowlist 和执行状态" : "抽查 Shell 复核",
                isActionable: needsReview,
                hasMetadata: review.hasMetadata
            )
        }

        if let review = gatewayFileChangeSafetyReview {
            let needsReview = review.hasMetadata == false || review.pathEscapeBlocked == true || review.writeSucceeded == false || review.resultStatus == "failed"
            add(
                id: "file-change-safety",
                rank: needsReview ? 38 : 86,
                severity: review.hasMetadata == false ? .high : (needsReview ? .high : .info),
                title: "文件变更安全",
                status: review.compactStatus,
                reason: review.hasMetadata ? "只展示 workspace 写入复核状态。" : "文件变更 metadata 待同步。",
                icon: "folder.badge.gearshape.fill",
                reviewKind: "file-change-safety",
                actionHint: needsReview ? "确认 workspace policy 和写入结果" : "抽查文件变更",
                isActionable: needsReview,
                hasMetadata: review.hasMetadata
            )
        }

        if let review = gatewayBrowserControlReview {
            let needsReview = review.hasMetadata == false || review.networkBlocked == true || review.resultStatus == "failed"
            add(
                id: "browser-control",
                rank: needsReview ? 48 : 88,
                severity: review.hasMetadata == false ? .medium : (needsReview ? .medium : .low),
                title: "浏览器控制",
                status: review.compactStatus,
                reason: review.hasMetadata ? "浏览器动作按策略和 presence 复核。" : "浏览器 metadata 待同步。",
                icon: "safari.fill",
                reviewKind: "browser-control",
                actionHint: needsReview ? "确认浏览器策略和网络状态" : "抽查浏览器计划",
                isActionable: needsReview,
                hasMetadata: review.hasMetadata
            )
        }

        if let review = gatewayExtractionCompletenessReview {
            let incomplete = review.hasMetadata == false || review.completenessStatus != "complete"
            add(
                id: "extraction-completeness",
                rank: incomplete ? 52 : 90,
                severity: review.hasMetadata == false ? .medium : (incomplete ? .medium : .low),
                title: "提取完整性",
                status: review.compactStatus,
                reason: review.hasMetadata ? "结构化结果有来源和完整性状态。" : "提取 metadata 待同步。",
                icon: "tablecells.fill",
                reviewKind: "extraction-completeness",
                actionHint: incomplete ? "确认来源 artifact 和行数" : "抽查提取摘要",
                isActionable: incomplete,
                hasMetadata: review.hasMetadata
            )
        }

        if let review = gatewayAccessibilityReview {
            let unavailable = review.hasMetadata == false || review.accessibilityPolicy?.contains("unavailable") == true || review.mode?.contains("unavailable") == true
            add(
                id: "accessibility",
                rank: unavailable ? 58 : 92,
                severity: review.hasMetadata == false ? .medium : (unavailable ? .medium : .low),
                title: "Accessibility 观察",
                status: review.compactStatus,
                reason: review.hasMetadata ? "只读观察摘要可用于复核屏幕依据。" : "Accessibility metadata 待同步。",
                icon: "accessibility.fill",
                reviewKind: "accessibility",
                actionHint: unavailable ? "检查观察权限和候选控件" : "抽查观察摘要",
                isActionable: unavailable,
                hasMetadata: review.hasMetadata
            )
        }

        if let review = gatewayCapabilityReview {
            let unavailable = review.hasMetadata == false ||
                [review.workspaceState, review.shellState, review.browserControlState, review.desktopControlState, review.accessibilityTreeState]
                .compactMap { $0 }
                .contains { $0.contains("unavailable") || $0.contains("disabled") }
            add(
                id: "gateway-capability",
                rank: unavailable ? 62 : 94,
                severity: review.hasMetadata == false ? .medium : (unavailable ? .medium : .low),
                title: "Gateway 能力",
                status: review.compactStatus,
                reason: review.hasMetadata ? "能力快照决定后续动作可用性。" : "能力 metadata 待同步。",
                icon: "server.rack",
                reviewKind: "gateway-capability",
                actionHint: unavailable ? "检查 Gateway 配置" : "抽查能力快照",
                isActionable: unavailable,
                hasMetadata: review.hasMetadata
            )
        }

        if let review = artifactMetadataReview {
            let coverageGap = review.hasMetadata == false || review.metadataArtifactCount < review.artifactCount
            add(
                id: "artifact-metadata",
                rank: coverageGap ? 66 : 96,
                severity: review.hasMetadata == false ? .medium : (coverageGap ? .low : .info),
                title: "Artifact metadata",
                status: review.compactStatus,
                reason: review.hasMetadata ? "复核 metadata 覆盖和脱敏状态。" : "artifact metadata 待同步。",
                icon: "paperclip.badge.ellipsis",
                reviewKind: "artifact-metadata",
                actionHint: coverageGap ? "确认缺失 metadata 的 artifact" : "抽查 metadata 覆盖",
                isActionable: coverageGap,
                hasMetadata: review.hasMetadata
            )
        }

        if let review = agentTraceReview {
            let needsReview = review.needsHandoffReview || review.readinessCanContinue == false || review.missingSignals.isEmpty == false || review.selectedNextActionRequiresApproval == true
            add(
                id: "agent-trace",
                rank: needsReview ? 70 : 98,
                severity: review.hasMetadata == false ? .medium : (needsReview ? .low : .info),
                title: "AgentTrace",
                status: review.compactStatus,
                reason: review.hasMetadata ? "智能体下一步和证据缺口需要复核。" : "AgentTrace metadata 待同步。",
                icon: "point.topleft.down.curvedto.point.bottomright.up",
                reviewKind: "agent-trace",
                actionHint: needsReview ? "确认下一步、缺口和停止原因" : "抽查 handoff 摘要",
                isActionable: needsReview,
                hasMetadata: review.hasMetadata
            )
        }

        return items.sorted {
            if $0.rank != $1.rank {
                return $0.rank < $1.rank
            }
            return $0.reviewKind < $1.reviewKind
        }
    }

    private func missionRunStageTrack(
        phase: ClawAutonomousLoopPhase,
        session: ClawGatewaySession?
    ) -> [ClawMissionRunStage] {
        let activeIndex: Int
        switch phase {
        case .idle, .planning:
            activeIndex = 0
        case .waitingForUserApproval:
            activeIndex = 1
        case .dispatching:
            activeIndex = 2
        case .observingGateway, .needsAttention:
            activeIndex = 3
        case .completed:
            activeIndex = 4
        case .blocked:
            activeIndex = session == nil ? 1 : 3
        }

        let stages: [(title: String, icon: String)] = [
            ("计划", "list.bullet.rectangle.portrait.fill"),
            ("审批", "checkmark.seal.fill"),
            ("发送", "paperplane.fill"),
            ("观察", "waveform.path.ecg.rectangle.fill"),
            ("交付", "shippingbox.fill")
        ]

        return stages.enumerated().map { index, stage in
            ClawMissionRunStage(
                title: stage.title,
                icon: stage.icon,
                isComplete: phase == .completed || index < activeIndex,
                isActive: index == activeIndex,
                isBlocked: phase == .blocked && index == activeIndex
            )
        }
    }

    func selectSkill(_ skill: ClawSkill) {
        selectedSkill = skill
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query = skill.recommendedInputs.first ?? ""
        }
    }

    func submitCurrentQuery() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return
        }

        let skill = selectedSkill
        messages.append(ChatMessage(role: .user, text: trimmed, skillTitle: skill?.title))
        let response = LocalClawAgentRuntime().generate(
            prompt: trimmed,
            skill: skill,
            model: model,
            validation: validation
        )
        messages.append(ChatMessage(role: .assistant, text: response, skillTitle: skill?.title))
        query = ""
    }

    func scanLocalArtifacts() {
        let result = ModelArtifactStore.validate(
            manifest: model.artifactManifest,
            directoryURL: artifactDirectoryURL
        )
        applyValidation(result)
    }

    func stageManualImportPreview() {
        let result = LocalArtifactValidator.validate(
            manifest: model.artifactManifest,
            presentFiles: Set(model.artifactManifest.requiredFiles)
        )
        applyValidation(result)
    }

    func importArtifacts(from urls: [URL]) throws {
        let result = try ModelArtifactStore.importArtifacts(
            manifest: model.artifactManifest,
            sourceURLs: urls,
            destinationDirectoryURL: artifactDirectoryURL
        )
        applyValidation(result)
    }

    func draftAutomationPayload(for target: AutomationTarget) {
        let prompt = selectedSkill?.promptTemplate ?? "请根据当前任务生成 Claw 电脑接管计划。"
        let cleanGatewayURL = gatewayURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let destination = target.channel == .clawGateway ? cleanGatewayURL : target.endpoint
        lastAutomationDraft = """
        channel: \(target.channel.title)
        destination: \(destination.isEmpty ? "待配置" : destination)
        action: \(target.actionTitle)
        confirmationRequired: \(target.requiresUserConfirmation ? "true" : "false")
        payload:
          capability: \(selectedSkill?.title ?? "未选择")
          model: \(model.name)
          prompt: \(prompt)
          context: \(documents.first?.title ?? "未选择")
        """
    }

    func setGateway(url: String, token: String) {
        gatewayURL = url
        gatewayToken = token
        clawGatewayProfile.endpoint = url.trimmingCharacters(in: .whitespacesAndNewlines)
        clawGatewayProfile.tokenFingerprint = ClawMobileBridge.tokenFingerprint(for: token)
        automationTargets = automationTargets.map { target in
            var updated = target
            if updated.channel == .clawGateway {
                updated.isConfigured = url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            }
            return updated
        }
    }

    func generatePhoneAgentPlan() {
        let trimmed = phoneAgentCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        let command = trimmed.isEmpty ? "接管电脑，打开浏览器完成资料收集并整理结果" : trimmed
        phoneAgentCommand = command
        phoneAgentPlan = PhoneAgentPlanner.makePlan(
            command: command,
            capabilities: phoneAgentCapabilities
        )
        phoneAgentExecutionLog = "已生成计划，等待用户确认执行。"
        lastClawMobileEnvelope = "Claw 电脑接管计划已更新，可生成 computer-control envelope。"
    }

    func startAutonomousComputerTakeover(maxIterations: Int = 3) {
        let trimmed = phoneAgentCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        let command = trimmed.isEmpty ? "接管电脑，打开浏览器完成资料收集并整理结果" : trimmed
        phoneAgentCommand = command
        setAutonomousLoop(
            phase: .planning,
            iteration: 1,
            maxIterations: maxIterations,
            command: command,
            statusLine: "正在把自然语言任务拆成可审批的电脑接管计划。",
            lastDecision: "启动自治循环，先生成计划和 Claw computer-control envelope。",
            requiresUserApproval: false,
            taskID: nil,
            sessionID: nil,
            clearReferences: true,
            appendCheckpoint: "loop.start command=\(command)"
        )

        generatePhoneAgentPlan()
        queueClawMobileTaskFromCurrentPlan()
        updateAutonomousLoopAfterTaskQueued()
    }

    func approveAndContinueAutonomousLoop() {
        guard autonomousLoop.phase == .waitingForUserApproval else {
            return
        }
        approveLatestClawMobileTask()
        guard let task = clawMobileTasks.first else {
            setAutonomousLoop(
                phase: .blocked,
                statusLine: "没有可审批的 Claw 电脑任务。",
                lastDecision: "审批继续失败：任务队列为空。",
                requiresUserApproval: false,
                appendCheckpoint: "loop.approval missing_task"
            )
            return
        }
        guard task.status != .blocked else {
            setAutonomousLoop(
                phase: .blocked,
                statusLine: "任务包含平台或策略阻断动作，不能发送到网关。",
                lastDecision: "审批后仍有 \(task.blockedCount) 个阻断动作。",
                requiresUserApproval: false,
                taskID: task.id,
                appendCheckpoint: "loop.blocked approvals=\(task.approvalCount) blocked=\(task.blockedCount)"
            )
            return
        }
        dispatchAutonomousLoopTask(task)
    }

    func continueAutonomousLoopAfterReview() {
        guard autonomousLoop.phase == .needsAttention else {
            return
        }
        guard let latestSession = clawGatewaySessions.first else {
            setAutonomousLoop(
                phase: .blocked,
                statusLine: "没有可继续观察的 Gateway 会话。",
                lastDecision: "继续失败：会话队列为空。",
                requiresUserApproval: false,
                appendCheckpoint: "loop.continue missing_session"
            )
            return
        }
        guard latestSession.retryableCount > 0 else {
            setAutonomousLoop(
                phase: .blocked,
                statusLine: "当前会话需要人工处理，且没有可自动重试的动作。",
                lastDecision: "停止循环：Gateway 返回待确认或不可重试结果。",
                requiresUserApproval: true,
                sessionID: latestSession.id,
                appendCheckpoint: "loop.needs_manual_attention retryable=0"
            )
            return
        }
        guard autonomousLoop.iteration < autonomousLoop.maxIterations else {
            setAutonomousLoop(
                phase: .blocked,
                statusLine: "已达到最大循环次数，停止自动重试。",
                lastDecision: "停止循环：iteration=\(autonomousLoop.iteration)，max=\(autonomousLoop.maxIterations)。",
                requiresUserApproval: true,
                sessionID: latestSession.id,
                appendCheckpoint: "loop.max_iterations"
            )
            return
        }

        let nextIteration = autonomousLoop.iteration + 1
        setAutonomousLoop(
            phase: .observingGateway,
            iteration: nextIteration,
            statusLine: "正在根据 Gateway 失败结果执行一次受控重试。",
            lastDecision: "发现 \(latestSession.retryableCount) 个可重试动作，进入第 \(nextIteration) 轮。",
            requiresUserApproval: false,
            sessionID: latestSession.id,
            appendCheckpoint: "loop.retry iteration=\(nextIteration) retryable=\(latestSession.retryableCount)"
        )
        retryLatestGatewayFailures()
        updateAutonomousLoopFromLatestGatewaySession()
    }

    func usePhoneAgentExample(_ command: String) {
        phoneAgentCommand = command
        generatePhoneAgentPlan()
    }

    func simulatePhoneAgentExecution() {
        let lines = phoneAgentPlan.steps.enumerated().map { index, step in
            let status: String
            if step.isAllowedOnIOS == false {
                status = "BLOCKED"
            } else if step.requiresUserConfirmation {
                status = "WAIT_CONFIRM"
            } else {
                status = "READY"
            }
            return "\(index + 1). [\(status)] \(step.title) -> \(step.surface.title)"
        }
        phoneAgentExecutionLog = """
        command: \(phoneAgentPlan.command)
        executableSteps: \(phoneAgentPlan.executableStepCount)
        confirmationRequired: \(phoneAgentPlan.confirmationCount)
        blockedOrGateway: \(phoneAgentPlan.blockedCount)
        steps:
        \(lines.joined(separator: "\n"))
        """
    }

    func queueClawMobileTaskFromCurrentPlan() {
        let task = ClawMobileBridge.makeTask(
            from: phoneAgentPlan,
            profile: clawGatewayProfile,
            selectedSkill: selectedSkill,
            documents: documents
        )
        clawMobileTasks.insert(task, at: 0)
        lastClawMobileEnvelope = ClawMobileBridge.makeEnvelopeString(task: task, profile: clawGatewayProfile)
    }

    func approveLatestClawMobileTask() {
        guard clawMobileTasks.isEmpty == false else {
            return
        }
        if clawMobileTasks[0].blockedCount > 0 {
            clawMobileTasks[0].status = .blocked
        } else {
            clawMobileTasks[0].status = .readyToSend
        }
        lastClawMobileEnvelope = ClawMobileBridge.makeEnvelopeString(task: clawMobileTasks[0], profile: clawGatewayProfile)
    }

    func simulateSendLatestClawMobileTask() {
        let previousMode = gatewayDispatchMode
        gatewayDispatchMode = .simulatedEventStream
        sendLatestClawMobileTask()
        gatewayDispatchMode = previousMode
    }

    func sendLatestClawMobileTask() {
        guard let dispatch = beginLatestGatewaySession(mode: gatewayDispatchMode) else {
            return
        }

        switch dispatch.mode {
        case .simulatedEventStream:
            gatewayConnectionState = .simulated
            let events = ClawGatewayEventStream.simulatedEvents(
                task: dispatch.task,
                profile: clawGatewayProfile,
                sessionID: dispatch.sessionID,
                startingSequence: 1
            )
            ingestGatewayEvents(events)
        case .liveGateway:
            prepareLiveGatewayRequest(
                task: dispatch.task,
                sessionID: dispatch.sessionID,
                fallbackToSimulation: true
            )
        }
    }

    func sendLatestClawMobileTaskOverLiveGateway<T: ClawGatewayTransport>(
        transport: T = URLSessionClawGatewayTransport()
    ) async {
        let previousMode = gatewayDispatchMode
        gatewayDispatchMode = .liveGateway
        guard let dispatch = beginLatestGatewaySession(mode: .liveGateway) else {
            gatewayDispatchMode = previousMode
            return
        }

        guard let request = prepareLiveGatewayRequest(
            task: dispatch.task,
            sessionID: dispatch.sessionID,
            fallbackToSimulation: false
        ) else {
            gatewayDispatchMode = previousMode
            return
        }

        guard request.canAttemptLive else {
            fallbackLatestSessionToSimulatedEvents(
                task: dispatch.task,
                sessionID: dispatch.sessionID,
                reason: request.preflightMessage,
                startingSequence: 2
            )
            gatewayDispatchMode = previousMode
            return
        }

        do {
            gatewayConnectionState = .streaming
            let stream = transport.streamEvents(
                request: request,
                envelopeJSON: lastClawMobileEnvelope,
                sessionID: dispatch.sessionID,
                taskID: dispatch.task.id
            )
            for try await event in stream {
                ingestGatewayEvents([event])
            }
        } catch {
            gatewayConnectionState = .failed
            let safeError = ClawGatewayLiveClient.safeTransportErrorSummary(
                error.localizedDescription,
                request: request
            )
            fallbackLatestSessionToSimulatedEvents(
                task: dispatch.task,
                sessionID: dispatch.sessionID,
                reason: error.localizedDescription,
                startingSequence: gatewayEvents.map(\.sequence).max().map { $0 + 1 } ?? 2,
                transportErrorSummary: safeError
            )
        }

        gatewayDispatchMode = previousMode
    }

    private func beginLatestGatewaySession(
        mode: ClawGatewayDispatchMode
    ) -> (task: ClawMobileTask, sessionID: UUID, mode: ClawGatewayDispatchMode)? {
        guard clawMobileTasks.isEmpty == false else {
            return nil
        }
        if clawMobileTasks[0].status == .readyToSend || clawMobileTasks[0].status == .queued {
            clawMobileTasks[0].status = .sent
            let task = clawMobileTasks[0]
            let session = ClawGatewayEventStream.makePreparedSession(
                task: task,
                profile: clawGatewayProfile,
                mode: mode
            )
            let preparedEvent = ClawGatewayEventStream.sessionPreparedEvent(
                task: task,
                sessionID: session.id,
                mode: mode
            )
            clawGatewaySessions.insert(session, at: 0)
            ingestGatewayEvents([preparedEvent])
            lastClawMobileEnvelope = ClawMobileBridge.makeEnvelopeString(task: task, profile: clawGatewayProfile)
            return (task, session.id, mode)
        }
        lastClawMobileEnvelope = ClawMobileBridge.makeEnvelopeString(task: clawMobileTasks[0], profile: clawGatewayProfile)
        return nil
    }

    @discardableResult
    private func prepareLiveGatewayRequest(
        task: ClawMobileTask,
        sessionID: UUID,
        fallbackToSimulation: Bool
    ) -> ClawGatewayLiveRequest? {
        let envelope = ClawMobileBridge.makeEnvelopeString(task: task, profile: clawGatewayProfile)
        lastClawMobileEnvelope = envelope
        let request = ClawGatewayLiveClient.makeRequest(
            task: task,
            profile: clawGatewayProfile,
            envelopeJSON: envelope,
            rawToken: gatewayToken
        )
        lastGatewayLiveRequest = request
        gatewayConnectionState = request.canAttemptLive ? .awaitingGateway : .notConfigured
        let liveEvent = ClawGatewayLiveClient.liveRequestPreparedEvent(
            task: task,
            sessionID: sessionID,
            request: request,
            sequence: 1
        )
        ingestGatewayEvents([liveEvent])

        if request.canAttemptLive == false, fallbackToSimulation {
            fallbackLatestSessionToSimulatedEvents(
                task: task,
                sessionID: sessionID,
                reason: request.preflightMessage,
                startingSequence: 2
            )
        } else if let latest = clawGatewaySessions.first {
            lastGatewayEvent = ClawGatewayLiveClient.requestSummary(request, session: latest)
        }

        return request
    }

    private func fallbackLatestSessionToSimulatedEvents(
        task: ClawMobileTask,
        sessionID: UUID,
        reason: String,
        startingSequence: Int,
        transportErrorSummary: String? = nil
    ) {
        gatewayConnectionState = .fallbackSimulated
        let fallbackEvent = ClawGatewayLiveClient.fallbackEvent(
            task: task,
            sessionID: sessionID,
            reason: reason,
            sequence: startingSequence,
            transportErrorSummary: transportErrorSummary
        )
        let events = ClawGatewayEventStream.simulatedEvents(
            task: task,
            profile: clawGatewayProfile,
            sessionID: sessionID,
            startingSequence: startingSequence + 1
        )
        ingestGatewayEvents([fallbackEvent] + events)
    }

    func ingestGatewayEvents(_ events: [ClawGatewayEvent]) {
        let orderedEvents = events.sorted {
            if $0.sequence == $1.sequence {
                return $0.createdAt < $1.createdAt
            }
            return $0.sequence < $1.sequence
        }
        var acceptedEvents: [ClawGatewayEvent] = []

        for event in orderedEvents {
            guard let sessionIndex = clawGatewaySessions.firstIndex(where: { $0.id == event.sessionID }) else {
                continue
            }
            clawGatewaySessions[sessionIndex] = ClawGatewayEventStream.apply(
                event: event,
                to: clawGatewaySessions[sessionIndex]
            )
            acceptedEvents.append(event)
        }

        guard acceptedEvents.isEmpty == false else {
            return
        }

        gatewayEvents.append(contentsOf: acceptedEvents)
        gatewayEvents.sort {
            if $0.createdAt == $1.createdAt {
                return $0.sequence < $1.sequence
            }
            return $0.createdAt < $1.createdAt
        }

        if let latest = clawGatewaySessions.first {
            let event = acceptedEvents.last
            if event?.kind == .sessionCompleted {
                gatewayConnectionState = latest.status == .blocked ? .failed : .completed
            } else if event?.kind == .fallbackUsed {
                gatewayConnectionState = .fallbackSimulated
            } else if gatewayDispatchMode == .liveGateway,
                      let event,
                      isLiveGatewayProgressEvent(event),
                      gatewayConnectionState != .fallbackSimulated,
                      gatewayConnectionState != .failed {
                gatewayConnectionState = .streaming
            }
            lastGatewayEvent = ClawGatewayEventStream.eventSummary(for: latest, latestEvent: event)
        }
    }

    private func isLiveGatewayProgressEvent(_ event: ClawGatewayEvent) -> Bool {
        switch event.kind {
        case .gatewayConnected,
             .actionStarted,
             .artifactStored,
             .actionCompleted,
             .actionFailed,
             .approvalRequested,
             .actionSkipped:
            return true
        case .sessionPrepared, .liveRequestPrepared, .sessionCompleted, .fallbackUsed:
            return false
        }
    }

    func retryLatestGatewayFailures() {
        guard clawGatewaySessions.isEmpty == false else {
            return
        }
        clawGatewaySessions[0] = ClawGatewaySimulator.retryFailures(in: clawGatewaySessions[0])
        lastGatewayEvent = ClawGatewaySimulator.eventSummary(for: clawGatewaySessions[0])
    }

    private func updateAutonomousLoopAfterTaskQueued() {
        guard let task = clawMobileTasks.first else {
            setAutonomousLoop(
                phase: .blocked,
                statusLine: "任务生成失败，没有可发送的 Claw 电脑任务。",
                lastDecision: "规划器没有产出任务。",
                requiresUserApproval: false,
                appendCheckpoint: "loop.queue failed"
            )
            return
        }

        switch task.status {
        case .blocked:
            setAutonomousLoop(
                phase: .blocked,
                statusLine: "任务包含平台或策略阻断动作，不能进入自动发送。",
                lastDecision: "阻断动作 \(task.blockedCount) 个；请修改任务或网关白名单。",
                requiresUserApproval: false,
                taskID: task.id,
                sessionID: nil,
                clearReferences: true,
                appendCheckpoint: "loop.blocked task=\(task.id.uuidString)"
            )
        case .waitingForApproval:
            setAutonomousLoop(
                phase: .waitingForUserApproval,
                statusLine: "计划已生成，需要用户审批后才会发送到桌面网关。",
                lastDecision: "检测到 \(task.approvalCount) 个审批点和风险分 \(task.riskScore)。",
                requiresUserApproval: true,
                taskID: task.id,
                sessionID: nil,
                clearReferences: true,
                appendCheckpoint: "loop.waiting_approval approvals=\(task.approvalCount) risk=\(task.riskScore)"
            )
        case .queued, .readyToSend, .sent:
            dispatchAutonomousLoopTask(task)
        }
    }

    private func dispatchAutonomousLoopTask(_ task: ClawMobileTask) {
        setAutonomousLoop(
            phase: .dispatching,
            runMode: gatewayDispatchMode,
            statusLine: "正在把 Claw 电脑任务发送到 \(gatewayDispatchMode.title)。",
            lastDecision: "发送 \(task.actions.count) 个动作；风险分 \(task.riskScore)。",
            requiresUserApproval: false,
            taskID: task.id,
            appendCheckpoint: "loop.dispatch mode=\(gatewayDispatchMode.rawValue) actions=\(task.actions.count)"
        )
        sendLatestClawMobileTask()
        updateAutonomousLoopFromLatestGatewaySession()
    }

    private func updateAutonomousLoopFromLatestGatewaySession() {
        guard let session = clawGatewaySessions.first else {
            setAutonomousLoop(
                phase: .observingGateway,
                statusLine: "任务已发送，正在等待 Gateway 会话事件。",
                lastDecision: "尚未收到 Gateway session。",
                requiresUserApproval: false,
                appendCheckpoint: "loop.waiting_session"
            )
            return
        }

        switch session.status {
        case .completed:
            setAutonomousLoop(
                phase: .completed,
                statusLine: "Gateway 会话已完成，结果和 artifact 已汇总。",
                lastDecision: "成功 \(session.succeededCount) 个动作，artifact \(session.artifactCount) 个。",
                requiresUserApproval: false,
                taskID: session.taskID,
                sessionID: session.id,
                appendCheckpoint: "loop.completed succeeded=\(session.succeededCount) artifacts=\(session.artifactCount)"
            )
        case .needsAttention:
            setAutonomousLoop(
                phase: .needsAttention,
                statusLine: "Gateway 返回失败或待确认结果，需要复核后再继续。",
                lastDecision: "失败 \(session.failedCount) 个，可重试 \(session.retryableCount) 个。",
                requiresUserApproval: true,
                taskID: session.taskID,
                sessionID: session.id,
                appendCheckpoint: "loop.needs_attention failed=\(session.failedCount) retryable=\(session.retryableCount)"
            )
        case .blocked:
            setAutonomousLoop(
                phase: .blocked,
                statusLine: "Gateway 会话被策略阻断。",
                lastDecision: "结果中包含跳过或阻断动作，循环停止。",
                requiresUserApproval: false,
                taskID: session.taskID,
                sessionID: session.id,
                appendCheckpoint: "loop.gateway_blocked"
            )
        case .prepared, .running:
            setAutonomousLoop(
                phase: .observingGateway,
                statusLine: "Gateway 会话运行中，正在等待下一批事件。",
                lastDecision: "当前状态：\(session.status.title)。",
                requiresUserApproval: false,
                taskID: session.taskID,
                sessionID: session.id,
                appendCheckpoint: "loop.observing status=\(session.status.rawValue)"
            )
        }
    }

    private func setAutonomousLoop(
        phase: ClawAutonomousLoopPhase,
        runMode: ClawGatewayDispatchMode? = nil,
        iteration: Int? = nil,
        maxIterations: Int? = nil,
        command: String? = nil,
        statusLine: String,
        lastDecision: String,
        requiresUserApproval: Bool,
        taskID: UUID? = nil,
        sessionID: UUID? = nil,
        clearReferences: Bool = false,
        appendCheckpoint: String
    ) {
        var checkpoints = autonomousLoop.checkpoints
        checkpoints.append(appendCheckpoint)
        if checkpoints.count > 8 {
            checkpoints = Array(checkpoints.suffix(8))
        }
        autonomousLoop = ClawAutonomousLoopState(
            id: autonomousLoop.id,
            phase: phase,
            runMode: runMode ?? autonomousLoop.runMode,
            iteration: iteration ?? autonomousLoop.iteration,
            maxIterations: maxIterations ?? autonomousLoop.maxIterations,
            command: command ?? autonomousLoop.command,
            statusLine: statusLine,
            lastDecision: lastDecision,
            requiresUserApproval: requiresUserApproval,
            taskID: clearReferences ? taskID : (taskID ?? autonomousLoop.taskID),
            sessionID: clearReferences ? sessionID : (sessionID ?? autonomousLoop.sessionID),
            checkpoints: checkpoints
        )
        phoneAgentExecutionLog = """
        autonomousLoop: \(autonomousLoop.phase.title)
        command: \(autonomousLoop.command)
        iteration: \(autonomousLoop.iteration)/\(autonomousLoop.maxIterations)
        decision: \(autonomousLoop.lastDecision)
        approvalRequired: \(autonomousLoop.requiresUserApproval)
        gateway: \(gatewayConnectionText)
        """
    }

    private func applyValidation(_ result: ArtifactValidationResult) {
        validation = result
        switch result.availability {
        case .missing:
            model.installState = .placeholder
            model.summary = "本地 Agent 权重暂未导入；当前启用 UI、规划器、网关 payload 和模拟电脑操作推理。"
        case .staged:
            model.installState = .staged
            model.summary = "Agent artifact 已放入本地目录，但没有通过 SHA-256 校验，真实推理仍关闭。"
        case .verified:
            model.installState = .verified
            model.summary = "Agent artifact 已通过本地校验，可替换 runtime 接入真实端侧规划。"
        }
    }
}

enum PhoneAgentPlanner {
    static func makePlan(
        command: String,
        capabilities: [PhoneAgentCapability]
    ) -> PhoneAgentPlan {
        let cleanCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = cleanCommand.lowercased()
        let request = cleanCommand.isEmpty ? "接管电脑，完成资料收集、整理和交付" : cleanCommand
        var steps: [PhoneAgentStep] = [
            PhoneAgentStep(
                title: "解析 LLM 指令",
                instruction: "把自然语言拆成目标、应用、输入、输出、风险等级和需要审批的动作。",
                target: "Claw Controller",
                surface: .clawRuntime,
                runMode: .automaticInsideApp,
                requiresUserConfirmation: false,
                isAllowedOnIOS: true,
                rationale: "手机端只做任务理解和审批准备，不直接越权控制系统。"
            )
        ]
        var notes: [String] = []
        let needsDesktopObservation = containsAny(
            normalized,
            [
                "接管", "电脑", "桌面", "屏幕", "观察", "看一下", "截图", "识别", "当前窗口", "定位按钮",
                "浏览器", "网页", "网站", "搜索", "文件", "文件夹", "终端", "shell", "命令", "脚本",
                "代码", "运行", "测试", "app", "软件", "窗口", "点击", "输入", "粘贴", "复制",
                "slack", "微信", "钉钉", "飞书", "notion", "excel"
            ]
        )

        if needsDesktopObservation {
            steps.append(
                PhoneAgentStep(
                    title: "观察桌面状态",
                    instruction: "请求网关返回当前屏幕、窗口标题、可访问性树和候选控件。",
                    target: "Desktop Screen",
                    surface: .clawGateway,
                    runMode: .gatewayOnly,
                    requiresUserConfirmation: true,
                    isAllowedOnIOS: false,
                    rationale: "真实电脑接管需要桌面端采集屏幕和控件信息，iOS 沙盒无法读取电脑屏幕。"
                )
            )
        }

        if containsAny(normalized, ["浏览器", "网页", "网站", "搜索", "google", "safari", "chrome", "打开链接", "竞品", "资料"]) {
            steps.append(
                PhoneAgentStep(
                    title: "控制桌面浏览器",
                    instruction: "让网关打开浏览器、访问页面、搜索信息、点击链接并提取结果。",
                    target: "Desktop Browser",
                    surface: .clawGateway,
                    runMode: .gatewayOnly,
                    requiresUserConfirmation: true,
                    isAllowedOnIOS: false,
                    rationale: "浏览器点击、页面读取和多标签操作应在桌面网关执行，并记录截图和 URL。"
                )
            )
        }

        if containsAny(normalized, ["文件", "文件夹", "下载", "上传", "整理", "导出", "pdf", "csv", "表格", "excel", "numbers"]) {
            steps.append(
                PhoneAgentStep(
                    title: "管理桌面文件",
                    instruction: "让网关在授权目录内查找、创建、重命名、导出或上传文件。",
                    target: "Desktop Filesystem",
                    surface: .clawGateway,
                    runMode: .gatewayOnly,
                    requiresUserConfirmation: true,
                    isAllowedOnIOS: false,
                    rationale: "文件系统写入影响范围大，必须限定工作目录并保留审计。"
                )
            )
        }

        if containsAny(normalized, ["终端", "shell", "命令", "脚本", "代码", "运行", "python", "node", "git", "安装", "构建", "测试"]) {
            steps.append(
                PhoneAgentStep(
                    title: "执行受控 Shell",
                    instruction: "把命令拆成可审查步骤，在网关白名单目录和命令策略内运行。",
                    target: "Desktop Shell",
                    surface: .clawGateway,
                    runMode: .gatewayOnly,
                    requiresUserConfirmation: true,
                    isAllowedOnIOS: false,
                    rationale: "Shell 具备高权限，默认需要用户确认、命令白名单和输出回传。"
                )
            )
        }

        if containsAny(normalized, ["app", "软件", "桌面", "窗口", "点击", "输入", "粘贴", "复制", "slack", "微信", "钉钉", "飞书", "notion", "excel"]) {
            steps.append(
                PhoneAgentStep(
                    title: "操作桌面应用",
                    instruction: "让网关基于屏幕/可访问性定位控件，点击、输入、复制粘贴并回传结果。",
                    target: "Desktop Apps",
                    surface: .clawGateway,
                    runMode: .gatewayOnly,
                    requiresUserConfirmation: true,
                    isAllowedOnIOS: false,
                    rationale: "这类动作正是 OpenClaw 式电脑接管能力，需要运行在用户授权的电脑端。"
                )
            )
        }

        if containsAny(normalized, ["整理", "提取", "抽取", "表格", "csv", "数据", "价格", "功能", "结果", "总结", "清单", "报告", "导出"]) {
            steps.append(
                PhoneAgentStep(
                    title: "提取结构化结果",
                    instruction: "让网关从浏览器页面、文件、命令输出或桌面窗口中提取结构化结果，并校验字段完整性。",
                    target: "Desktop Data",
                    surface: .clawGateway,
                    runMode: .gatewayOnly,
                    requiresUserConfirmation: true,
                    isAllowedOnIOS: false,
                    rationale: "OpenClaw 式电脑智能体需要把观察到的屏幕/网页/文件结果转成可审查数据，而不是只返回自然语言描述。"
                )
            )
        }

        if steps.contains(where: { $0.surface == .clawGateway && $0.runMode == .gatewayOnly }) {
            steps.append(
                PhoneAgentStep(
                    title: "运行电脑智能体循环",
                    instruction: "让网关基于屏幕、浏览器、文件、命令输出和桌面 App artifact 执行观察、决策、受限动作建议和验证闭环；每轮都写入可审查轨迹。",
                    target: "Desktop Agent Loop",
                    surface: .clawGateway,
                    runMode: .gatewayOnly,
                    requiresUserConfirmation: true,
                    isAllowedOnIOS: false,
                    rationale: "OpenClaw 式能力不是单次打开 App，而是能在用户策略内反复观察状态、选择下一步、停在危险动作前并保留完整 trace。"
                )
            )
        }

        if containsAny(normalized, ["发消息", "发短信", "发送", "发给", "发到", "转发", "回复", "通知", "频道", "slack", "discord", "telegram", "signal", "微信", "钉钉", "飞书", "im"]) {
            steps.append(
                PhoneAgentStep(
                    title: "确认收件人或频道",
                    instruction: "从授权通讯录、用户输入或桌面网关上下文中确认收件人，避免 LLM 猜测目标。",
                    target: "Contacts",
                    surface: .systemFramework,
                    runMode: .automaticWithPermission,
                    requiresUserConfirmation: false,
                    isAllowedOnIOS: true,
                    rationale: "通讯录只能读取用户授权的数据；第三方 IM 好友列表需要由网关或目标 API 提供。"
                )
            )
            steps.append(
                PhoneAgentStep(
                    title: "生成消息草稿",
                    instruction: "生成可发送文本，标出收件人、频道、附件和需要用户确认的最终发送动作。",
                    target: "Messages / Mail / IM",
                    surface: .composeController,
                    runMode: .needsUserConfirmation,
                    requiresUserConfirmation: true,
                    isAllowedOnIOS: true,
                    rationale: "普通 App 可调起短信或邮件撰写界面，但最终发送动作由用户确认。"
                )
            )

            if containsAny(normalized, ["微信", "钉钉", "企业微信", "飞书"]) {
                steps.append(
                    PhoneAgentStep(
                        title: "交给 Claw 网关执行第三方 App 流程",
                        instruction: "把收件人、消息草稿、目标 App 和确认要求发给用户授权的桌面/自托管网关。",
                        target: "Claw Desktop Gateway",
                        surface: .clawGateway,
                        runMode: .gatewayOnly,
                        requiresUserConfirmation: true,
                        isAllowedOnIOS: false,
                        rationale: "iOS 普通 App 不能静默控制微信、钉钉等第三方 App 的 UI。"
                    )
                )
            }

            if containsAny(normalized, ["自动发送", "直接发送", "不要确认"]) {
                notes.append("短信、iMessage、邮件和多数第三方 IM 的最终发送不能由普通 App 静默完成，需要用户确认或目标 App 提供专用 Intent。")
            }
        }

        if containsAny(normalized, ["收消息", "读消息", "读取短信", "查看微信", "监听消息", "自动回复"]) {
            steps.append(
                PhoneAgentStep(
                    title: "读取其他 App 消息",
                    instruction: "尝试读取短信、iMessage、微信或其他 App 的收件箱。",
                    target: "Messages / Third-party inbox",
                    surface: .unavailable,
                    runMode: .blockedByIOS,
                    requiresUserConfirmation: false,
                    isAllowedOnIOS: false,
                    rationale: "普通 App 无法读取系统 Messages 或第三方 App 的私有消息数据库。"
                )
            )
            notes.append("如果要自动处理收件箱，只能处理本 App 自己拥有的数据，或让目标服务提供 API、App Intent、Share Extension、Webhook，或交给用户授权的桌面 Claw Gateway。")
        }

        if containsAny(normalized, ["语音", "口述", "siri", "说话", "听我"]) {
            steps.append(
                PhoneAgentStep(
                    title: "采集语音指令",
                    instruction: "请求麦克风和语音识别权限，把口述内容转成 Claw 电脑接管指令。",
                    target: "Speech / AVAudioSession",
                    surface: .siriKit,
                    runMode: .automaticWithPermission,
                    requiresUserConfirmation: false,
                    isAllowedOnIOS: true,
                    rationale: "第三方 App 可以做自己的语音入口，但不能接管系统 Siri 的全局唤醒和私有权限。"
                )
            )
        }

        if containsAny(normalized, ["日程", "提醒", "明天", "今天", "会议", "待办", "跟进"]) {
            steps.append(
                PhoneAgentStep(
                    title: "创建跟进提醒",
                    instruction: "把任务转换成提醒事项或日历事件，必要时提醒用户回到桌面继续审批。",
                    target: "Calendar / Reminders",
                    surface: .systemFramework,
                    runMode: .automaticWithPermission,
                    requiresUserConfirmation: false,
                    isAllowedOnIOS: true,
                    rationale: "EventKit 可在授权后读写日历和提醒事项。"
                )
            )
        }

        if containsAny(normalized, ["打开", "搜索", "网页", "浏览器", "链接"]) {
            steps.append(
                PhoneAgentStep(
                    title: "打开移动端链接",
                    instruction: "生成 Universal Link 或 URL Scheme，跳转到目标 App 或网页。",
                    target: "Safari / Web App",
                    surface: .universalLink,
                    runMode: .automaticWithPermission,
                    requiresUserConfirmation: false,
                    isAllowedOnIOS: true,
                    rationale: "UIApplication.open 可以打开公开 URL；目标 App 是否接收取决于它公开的入口。"
                )
            )
        }

        if containsAny(normalized, ["后台", "自动工作", "定时", "每天"]) {
            steps.append(
                PhoneAgentStep(
                    title: "安排后台刷新",
                    instruction: "注册轻量后台任务，在系统允许的时间检查网关结果、刷新任务状态和提醒。",
                    target: "BGTaskScheduler",
                    surface: .backgroundTask,
                    runMode: .automaticWithPermission,
                    requiresUserConfirmation: false,
                    isAllowedOnIOS: true,
                    rationale: "BackgroundTasks 由系统调度，不保证精确定时或长期常驻。"
                )
            )
        }

        if steps.count == 1 {
            steps.append(
                PhoneAgentStep(
                    title: "形成电脑接管计划",
                    instruction: "生成可交给桌面网关的分步计划、输入输出约束、回滚点和审批点。",
                    target: "Claw Controller",
                    surface: .clawRuntime,
                    runMode: .automaticInsideApp,
                    requiresUserConfirmation: false,
                    isAllowedOnIOS: true,
                    rationale: "未识别出具体应用时，先把任务规划成可审查的电脑操作清单。"
                )
            )
        }

        steps.append(
            PhoneAgentStep(
                title: "生成审计记录",
                instruction: "记录模型输入、计划步骤、确认点、网关动作、输出摘要和失败原因。",
                target: "Claw Audit",
                surface: .clawRuntime,
                runMode: .automaticInsideApp,
                requiresUserConfirmation: false,
                isAllowedOnIOS: true,
                rationale: "电脑接管动作高权限，必须可追溯、可回放、可撤销。"
            )
        )

        let executable = steps.filter { $0.isAllowedOnIOS && $0.runMode.isExecutableOnDevice }.count
        let gated = steps.filter(\.requiresUserConfirmation).count
        let blocked = steps.filter { $0.isAllowedOnIOS == false }.count + notes.count
        let summary = "已把指令拆成 \(steps.count) 步：\(executable) 步可由手机端处理，\(gated) 步需要用户确认，\(blocked) 项需要桌面 Claw Gateway 或受 iOS 权限限制。"

        return PhoneAgentPlan(
            command: request,
            summary: summary,
            steps: steps,
            blockedNotes: notes
        )
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0.lowercased()) }
    }
}

enum ClawMobileBridge {
    static func makeTask(
        from plan: PhoneAgentPlan,
        profile: ClawGatewayProfile,
        selectedSkill: ClawSkill?,
        documents: [WorkspaceContext]
    ) -> ClawMobileTask {
        let actions = plan.steps.map { step in
            makeAction(
                from: step,
                plan: plan,
                profile: profile,
                selectedSkill: selectedSkill,
                documents: documents
            )
        }
        let blockedCount = actions.filter { $0.approval == .blocked }.count
        let approvalCount = actions.filter { $0.approval == .userConfirmation || $0.approval == .gatewayApproval }.count
        let status: ClawTaskStatus
        if blockedCount > 0 {
            status = .blocked
        } else if approvalCount > 0 {
            status = .waitingForApproval
        } else {
            status = .queued
        }
        let riskScore = min(actions.map(riskWeight(for:)).reduce(0, +), 100)
        let summary = "Claw 电脑任务包含 \(actions.count) 个动作，\(approvalCount) 个审批点，\(blockedCount) 个被策略或平台边界阻断动作。"

        return ClawMobileTask(
            command: plan.command,
            summary: summary,
            sourceDevice: profile.deviceName,
            destinationGateway: profile.endpoint.isEmpty ? "未配置" : profile.endpoint,
            actions: actions,
            status: status,
            riskScore: riskScore
        )
    }

    static func makeEnvelope(task: ClawMobileTask, profile: ClawGatewayProfile) -> ClawMobileEnvelope {
        let approvalSummary = "userOrGatewayApprovals=\(task.approvalCount); blocked=\(task.blockedCount); sensitive=\(task.sensitiveActionCount)"
        return ClawMobileEnvelope(
            schemaVersion: "claw.computer.control.v1",
            sourceApp: "Claw Controller",
            task: task,
            gateway: profile,
            approvalSummary: approvalSummary,
            auditRequired: profile.auditEnabled || task.sensitiveActionCount > 0
        )
    }

    static func makeEnvelopeString(task: ClawMobileTask, profile: ClawGatewayProfile) -> String {
        let envelope = makeEnvelope(task: task, profile: profile)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(envelope),
              let json = String(data: data, encoding: .utf8) else {
            return "Claw computer-control envelope 编码失败。"
        }
        return json
    }

    static func tokenFingerprint(for token: String) -> String {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return "unset"
        }
        let digest = SHA256.hash(data: Data(trimmed.utf8))
        let prefix = digest.prefix(6).map { String(format: "%02x", $0) }.joined()
        return "sha256:\(prefix)"
    }

    private static func makeAction(
        from step: PhoneAgentStep,
        plan: PhoneAgentPlan,
        profile: ClawGatewayProfile,
        selectedSkill: ClawSkill?,
        documents: [WorkspaceContext]
    ) -> ClawMobileAction {
        let kind = actionKind(for: step)
        let sensitive = handlesSensitiveData(kind: kind, step: step)
        let baseApproval = approvalLevel(for: step)
        let blockedByGatewayPolicy = baseApproval != .blocked && profile.allowedActionKinds.contains(kind) == false
        let approval: ClawApprovalLevel
        if blockedByGatewayPolicy {
            approval = .blocked
        } else if baseApproval == .automatic,
                  profile.requiresApprovalForSensitiveData,
                  sensitive,
                  requiresExplicitApprovalForSensitiveAction(kind) {
            approval = .userConfirmation
        } else {
            approval = baseApproval
        }
        let instruction = blockedByGatewayPolicy
            ? "网关动作白名单不允许 \(kind.rawValue)，不生成可执行任务。\(step.instruction)"
            : step.instruction
        let inputPreview = preview(
            for: step,
            plan: plan,
            selectedSkill: selectedSkill,
            documents: documents
        )
        let toolArguments = toolArguments(for: kind, step: step, plan: plan)

        return ClawMobileAction(
            kind: kind,
            title: step.title,
            target: step.target,
            instruction: instruction,
            approval: approval,
            sourceSurface: step.surface,
            handlesSensitiveData: sensitive,
            inputPreview: inputPreview,
            toolArguments: toolArguments
        )
    }

    private static func toolArguments(
        for kind: ClawMobileActionKind,
        step: PhoneAgentStep,
        plan: PhoneAgentPlan
    ) -> [String: String] {
        switch kind {
        case .runAgentLoop:
            return [
                "objective": plan.command,
                "loopMode": "observe-plan-act-verify",
                "maxIterations": "3",
                "inputSources": "screenObservation,accessibilityTree,browserTrace,fileDiff,commandOutput,messageDraft",
                "allowedNextActions": "observeScreen,controlBrowser,manageFiles,extractData,operateDesktopApp,composeMessage",
                "approvalRequiredFor": "runShellCommand,operateDesktopAppFinalSubmit,externalNetwork,destructiveFileChange",
                "stopBeforeDestructiveAction": "true",
                "writeTrace": "true"
            ]
        case .observeScreen:
            return [
                "observationGoal": plan.command,
                "includeScreenshot": "true",
                "includeAccessibilityTree": "true",
                "includeWindowTitles": "true",
                "maxCandidateControls": "20",
                "redaction": "maskSensitiveText"
            ]
        case .runShellCommand:
            return [
                "shellCommand": "pwd",
                "cwdPolicy": "workspaceOnly",
                "dryRunReason": "LLM natural-language shell instructions are never executed directly; Gateway may replace this after explicit user approval."
            ]
        case .controlBrowser:
            return [
                "browserGoal": plan.command,
                "browserApp": "Safari",
                "openInBrowser": "true",
                "searchQuery": plan.command,
                "searchURLTemplate": "https://www.google.com/search?q={query}",
                "captureTrace": "true",
                "html": "<html><head><title>Claw Browser Task</title></head><body><main>Replace this placeholder with approved browser snapshot HTML.</main></body></html>"
            ]
        case .manageFiles:
            return [
                "workspaceOnly": "true",
                "requestedTarget": step.target,
                "writePath": "claw-output/summary.txt",
                "writeText": "Claw Gateway workspace write placeholder. Replace with approved task output."
            ]
        case .operateDesktopApp:
            return [
                "targetApp": desktopAppTarget(for: plan.command),
                "automationMode": "accessibility",
                "inputMode": "typeOrPaste",
                "draftText": "Claw prepared result for: \(plan.command)",
                "keySequence": "command+k,return",
                "finalSubmitRequiresApproval": "true",
                "captureBeforeAfter": "true"
            ]
        case .extractData:
            return [
                "extractionGoal": plan.command,
                "sourcePriority": "browserTrace,accessibilityTree,commandOutput,fileDiff,screenObservation",
                "schema": "title:string,source:string,summary:string,confidence:number",
                "outputPath": "claw-output/extracted-data.json",
                "validateCompleteness": "true"
            ]
        default:
            return [:]
        }
    }

    private static func desktopAppTarget(for command: String) -> String {
        let normalized = command.lowercased()
        if normalized.contains("slack") {
            return "Slack"
        }
        if normalized.contains("微信") || normalized.contains("wechat") {
            return "WeChat"
        }
        if normalized.contains("钉钉") {
            return "DingTalk"
        }
        if normalized.contains("飞书") || normalized.contains("lark") {
            return "Lark"
        }
        if normalized.contains("notion") {
            return "Notion"
        }
        if normalized.contains("excel") {
            return "Microsoft Excel"
        }
        return "Active Desktop App"
    }

    private static func actionKind(for step: PhoneAgentStep) -> ClawMobileActionKind {
        if step.isAllowedOnIOS == false {
            guard step.runMode == .gatewayOnly else {
                return .blockedUnsupported
            }
            if step.target.contains("Screen") {
                return .observeScreen
            }
            if step.target.contains("Agent Loop") {
                return .runAgentLoop
            }
            if step.target.contains("Browser") {
                return .controlBrowser
            }
            if step.target.contains("Filesystem") {
                return .manageFiles
            }
            if step.target.contains("Shell") {
                return .runShellCommand
            }
            if step.target.contains("Data") {
                return .extractData
            }
            if step.target.contains("Apps") {
                return .operateDesktopApp
            }
            if step.title.contains("第三方 App") {
                return .operateDesktopApp
            }
            return .desktopHandoff
        }

        switch step.surface {
        case .clawRuntime:
            return step.title.contains("审计") ? .auditLog : .analyzeLocalContext
        case .appIntents, .shortcuts:
            return .runShortcut
        case .siriKit:
            return .speechCapture
        case .systemFramework:
            if step.title.contains("联系人") {
                return .readContacts
            }
            if step.title.contains("提醒") || step.target.contains("Calendar") || step.target.contains("Reminders") {
                return .createReminder
            }
            return .requestPermission
        case .composeController:
            return step.title.contains("邮件") || step.target == "Mail" ? .composeEmail : .composeMessage
        case .urlScheme, .universalLink:
            return .openExternalURL
        case .backgroundTask:
            return .backgroundRefresh
        case .clawGateway:
            return .desktopHandoff
        case .unavailable:
            return .blockedUnsupported
        }
    }

    private static func requiresExplicitApprovalForSensitiveAction(_ kind: ClawMobileActionKind) -> Bool {
        switch kind {
        case .runAgentLoop, .observeScreen, .controlBrowser, .operateDesktopApp, .manageFiles, .runShellCommand, .extractData, .readContacts, .composeMessage, .composeEmail, .desktopHandoff:
            return true
        case .analyzeLocalContext, .requestPermission, .createReminder, .scheduleNotification, .openExternalURL, .runShortcut, .speechCapture, .backgroundRefresh, .auditLog, .blockedUnsupported:
            return false
        }
    }

    private static func approvalLevel(for step: PhoneAgentStep) -> ClawApprovalLevel {
        if step.isAllowedOnIOS == false {
            return step.runMode == .gatewayOnly ? .gatewayApproval : .blocked
        }
        if step.requiresUserConfirmation {
            return .userConfirmation
        }
        if step.surface == .clawGateway {
            return .gatewayApproval
        }
        return .automatic
    }

    private static func handlesSensitiveData(kind: ClawMobileActionKind, step: PhoneAgentStep) -> Bool {
        switch kind {
        case .analyzeLocalContext, .runAgentLoop, .observeScreen, .controlBrowser, .operateDesktopApp, .manageFiles, .runShellCommand, .extractData, .composeMessage, .composeEmail, .readContacts, .desktopHandoff:
            return true
        case .blockedUnsupported:
            return step.target.contains("Messages") || step.target.contains("Third-party")
        case .requestPermission, .createReminder, .scheduleNotification, .openExternalURL, .runShortcut, .speechCapture, .backgroundRefresh, .auditLog:
            return false
        }
    }

    private static func riskWeight(for action: ClawMobileAction) -> Int {
        let base: Int
        switch action.kind {
        case .analyzeLocalContext:
            base = 8
        case .requestPermission:
            base = 12
        case .runAgentLoop:
            base = 46
        case .observeScreen:
            base = 28
        case .controlBrowser:
            base = 36
        case .operateDesktopApp:
            base = 44
        case .manageFiles:
            base = 48
        case .runShellCommand:
            base = 58
        case .extractData:
            base = 32
        case .readContacts:
            base = 24
        case .composeMessage, .composeEmail:
            base = 34
        case .createReminder, .scheduleNotification:
            base = 10
        case .openExternalURL, .runShortcut:
            base = 14
        case .speechCapture:
            base = 18
        case .backgroundRefresh:
            base = 12
        case .desktopHandoff:
            base = 42
        case .auditLog:
            base = 2
        case .blockedUnsupported:
            base = 60
        }
        return action.approval == .blocked ? min(base + 30, 100) : base
    }

    private static func preview(
        for step: PhoneAgentStep,
        plan: PhoneAgentPlan,
        selectedSkill: ClawSkill?,
        documents: [WorkspaceContext]
    ) -> String {
        let skill = selectedSkill?.title ?? "未选择能力"
        let context = documents.first?.title ?? "未选择上下文"
        return "command=\(plan.command); capability=\(skill); context=\(context); stepTarget=\(step.target)"
    }
}

enum ClawGatewaySimulator {
    static func makeSession(
        task: ClawMobileTask,
        profile: ClawGatewayProfile
    ) -> ClawGatewaySession {
        let results = task.actions.enumerated().map { index, action in
            makeResult(for: action, index: index)
        }
        let status: ClawGatewaySessionStatus
        if task.status == .blocked || results.contains(where: { $0.status == .skipped }) {
            status = .blocked
        } else if results.contains(where: { $0.status == .failed || $0.status == .waitingForApproval }) {
            status = .needsAttention
        } else {
            status = .completed
        }
        let audit = [
            "session.created source=Claw Controller gateway=\(profile.endpoint)",
            "task.riskScore=\(task.riskScore) approvals=\(task.approvalCount) sensitive=\(task.sensitiveActionCount)",
            "sandbox.workspace=~/ClawWorkspace commandPolicy=allowlist token=\(profile.tokenFingerprint)"
        ]

        return ClawGatewaySession(
            taskID: task.id,
            command: task.command,
            channel: "iOS Controller -> Claw Gateway",
            workspace: "~/ClawWorkspace",
            status: status,
            results: results,
            sessionArtifacts: [capabilitySnapshotArtifact(for: profile)],
            auditTrail: audit
        )
    }

    static func retryFailures(in session: ClawGatewaySession) -> ClawGatewaySession {
        var updated = session
        updated.results = updated.results.map { result in
            guard result.isRetryable else {
                return result
            }
            var retried = result
            retried.status = .succeeded
            retried.summary = "重试成功：\(result.actionTitle) 已在网关安全策略内完成。"
            retried.isRetryable = false
            retried.retryCount += 1
            retried.finishedAt = Date()
            retried.artifacts.append(
                ClawGatewayArtifact(
                    kind: .auditLog,
                    title: "retry-\(retried.retryCount)",
                    reference: "audit://retry/\(result.actionID.uuidString.prefix(8))",
                    isRedacted: true
                )
            )
            return retried
        }
        updated.status = updated.results.contains { $0.status == .failed || $0.status == .waitingForApproval } ? .needsAttention : .completed
        updated.auditTrail.append("session.retry completed retryable=\(session.retryableCount)")
        updated.updatedAt = Date()
        return updated
    }

    static func eventSummary(for session: ClawGatewaySession) -> String {
        """
        session: \(session.id.uuidString)
        status: \(session.status.title)
        command: \(session.command)
        results: \(session.succeededCount) succeeded / \(session.failedCount) failed / \(session.retryableCount) retryable
        artifacts: \(session.artifactCount)
        """
    }

    static func makeResult(
        for action: ClawMobileAction,
        index: Int
    ) -> ClawGatewayActionResult {
        if action.approval == .blocked {
            return ClawGatewayActionResult(
                actionID: action.id,
                actionKind: action.kind,
                actionTitle: action.title,
                status: .skipped,
                summary: "动作被策略阻断，未交给网关执行。",
                artifacts: [artifact(.auditLog, "blocked-\(index + 1)", redacted: true)],
                isRetryable: false
            )
        }

        switch action.kind {
        case .runAgentLoop:
            return ClawGatewayActionResult(
                actionID: action.id,
                actionKind: action.kind,
                actionTitle: action.title,
                status: .succeeded,
                summary: "电脑智能体循环已完成一次观察、决策、受限动作建议和验证记录。",
                artifacts: [
                    artifact(
                        .agentTrace,
                        "agent-loop-\(index + 1).json",
                        redacted: true,
                        metadata: agentTraceMetadata()
                    )
                ]
            )
        case .observeScreen:
            return ClawGatewayActionResult(
                actionID: action.id,
                actionKind: action.kind,
                actionTitle: action.title,
                status: .succeeded,
                summary: "已采集屏幕截图和可访问性树，敏感区域已打码。",
                artifacts: [
                    artifact(.screenshot, "screen-\(index + 1).png", redacted: true),
                    artifact(
                        .accessibilityTree,
                        "ax-tree-\(index + 1).json",
                        redacted: true,
                        metadata: accessibilityTreeMetadata()
                    )
                ]
            )
        case .controlBrowser:
            return ClawGatewayActionResult(
                actionID: action.id,
                actionKind: action.kind,
                actionTitle: action.title,
                status: .succeeded,
                summary: "浏览器流程完成：打开页面、搜索、提取结果并保存轨迹。",
                artifacts: [
                    artifact(
                        .browserTrace,
                        "browser-trace-\(index + 1).json",
                        redacted: false,
                        metadata: browserControlReviewMetadata(mode: "browser-control-dry-run", resultStatus: "succeeded")
                    ),
                    artifact(
                        .screenshot,
                        "browser-\(index + 1).png",
                        redacted: true,
                        metadata: browserControlReviewMetadata(mode: "browser-control-dry-run", resultStatus: "succeeded")
                    )
                ]
            )
        case .operateDesktopApp:
            return ClawGatewayActionResult(
                actionID: action.id,
                actionKind: action.kind,
                actionTitle: action.title,
                status: .waitingForApproval,
                summary: "桌面 App 已定位到提交/发送前状态，等待用户确认最终动作。",
                artifacts: [
                    artifact(
                        .screenshot,
                        "app-confirm-\(index + 1).png",
                        redacted: true,
                        metadata: deliverySafetyMetadata(
                            for: action.kind,
                            mode: "desktop-control-dry-run",
                            targetKind: "desktopApp",
                            finalSubmitRequiresApproval: true,
                            userApprovalRequired: true,
                            draftBodyOmitted: true,
                            pasteTextOmitted: true,
                            submitBlocked: true,
                            allowedKeyCount: 1,
                            blockedKeyCount: 1,
                            blockedSubmitKeyCount: 1
                        )
                    )
                ]
            )
        case .manageFiles:
            return ClawGatewayActionResult(
                actionID: action.id,
                actionKind: action.kind,
                actionTitle: action.title,
                status: .succeeded,
                summary: "文件操作在授权目录内完成，已生成变更清单。",
                artifacts: [
                    artifact(
                        .fileDiff,
                        "file-diff-\(index + 1).json",
                        redacted: false,
                        metadata: fileChangeReviewMetadata()
                    )
                ]
            )
        case .runShellCommand:
            return ClawGatewayActionResult(
                actionID: action.id,
                actionKind: action.kind,
                actionTitle: action.title,
                status: .failed,
                summary: "命令需要更窄工作目录或白名单确认，已暂停执行。",
                artifacts: [
                    artifact(
                        .commandOutput,
                        "shell-dry-run-\(index + 1).log",
                        redacted: true,
                        metadata: shellCommandSafetyMetadata()
                    )
                ],
                isRetryable: true
            )
        case .extractData:
            return ClawGatewayActionResult(
                actionID: action.id,
                actionKind: action.kind,
                actionTitle: action.title,
                status: .succeeded,
                summary: "结构化数据已提取并校验字段完整性。",
                artifacts: [
                    artifact(
                        .browserTrace,
                        "extracted-data-\(index + 1).json",
                        redacted: false,
                        metadata: extractionCompletenessMetadata()
                    )
                ]
            )
        case .composeMessage, .composeEmail:
            return ClawGatewayActionResult(
                actionID: action.id,
                actionKind: action.kind,
                actionTitle: action.title,
                status: .waitingForApproval,
                summary: "已生成草稿，最终发送等待用户确认。",
                artifacts: [
                    artifact(
                        .messageDraft,
                        "draft-\(index + 1).txt",
                        redacted: true,
                        metadata: deliverySafetyMetadata(
                            for: action.kind,
                            mode: "message-draft-pending-approval",
                            targetKind: action.kind == .composeEmail ? "email" : "message",
                            finalSubmitRequiresApproval: true,
                            userApprovalRequired: true,
                            draftBodyOmitted: true,
                            pasteTextOmitted: false,
                            submitBlocked: true,
                            allowedKeyCount: 0,
                            blockedKeyCount: 0,
                            blockedSubmitKeyCount: 0
                        )
                    )
                ]
            )
        case .analyzeLocalContext, .requestPermission, .readContacts, .createReminder, .scheduleNotification, .openExternalURL, .runShortcut, .speechCapture, .backgroundRefresh, .desktopHandoff, .auditLog:
            return ClawGatewayActionResult(
                actionID: action.id,
                actionKind: action.kind,
                actionTitle: action.title,
                status: action.approval == .gatewayApproval ? .waitingForApproval : .succeeded,
                summary: "动作已记录到会话事件流。",
                artifacts: [artifact(.auditLog, "event-\(index + 1).json", redacted: action.handlesSensitiveData)]
            )
        case .blockedUnsupported:
            return ClawGatewayActionResult(
                actionID: action.id,
                actionKind: action.kind,
                actionTitle: action.title,
                status: .skipped,
                summary: "平台不支持该动作，已跳过。",
                artifacts: [artifact(.auditLog, "unsupported-\(index + 1).json", redacted: true)]
            )
        }
    }

    static func capabilitySnapshotArtifact(for profile: ClawGatewayProfile) -> ClawGatewayArtifact {
        let allowedKinds = profile.allowedActionKinds
            .map(\.rawValue)
            .sorted()
            .joined(separator: ",")
        let tokenConfigured = profile.tokenFingerprint != "unset"
        return artifact(
            .auditLog,
            "gateway-capability-snapshot.json",
            redacted: true,
            metadata: [
                "snapshotKind": "gatewayCapability",
                "tokenConfigured": tokenConfigured ? "true" : "false",
                "tokenRequired": "false",
                "tokenFingerprint": tokenConfigured ? profile.tokenFingerprint : "unset",
                "allowedActionKinds": allowedKinds,
                "workspaceState": "workspace-only",
                "shellState": "dry-run",
                "browserControlState": "dry-run",
                "browserNetworkState": "disabled",
                "screenCaptureState": "dry-run",
                "windowMetadataState": "dry-run",
                "accessibilityTreeState": "dry-run",
                "desktopControlState": "dry-run",
                "safetyFlags": "allowlists-enforced,workspace-only,raw-token-omitted,final-submit-gated",
                "platform": "simulated"
            ]
        )
    }

    private static func artifact(
        _ kind: ClawGatewayArtifactKind,
        _ title: String,
        redacted: Bool,
        metadata: [String: String]? = nil
    ) -> ClawGatewayArtifact {
        ClawGatewayArtifact(
            kind: kind,
            title: title,
            reference: "\(kind.rawValue)://\(title)",
            isRedacted: redacted,
            metadata: metadata
        )
    }

    private static func agentTraceMetadata() -> [String: String] {
        [
            "readinessScore": "72",
            "readinessCanContinue": "true",
            "satisfiedSignals": "screenObservation,accessibilityTree,browserTrace,fileDiff,commandOutput",
            "missingSignals": "messageDraft",
            "selectedNextActionKind": "composeMessage",
            "selectedNextActionRequiresApproval": "true",
            "riskTags": "approval-required,final-submit-gate,missing-message-draft",
            "stopReason": "final-submit",
            "handoffStatus": "final-submit-review",
            "handoffSummary": "Evidence score 72/100 from screenObservation, accessibilityTree, browserTrace, fileDiff, commandOutput; missing messageDraft. Selected next action: composeMessage. Stop reason: final-submit."
        ]
    }

    private static func accessibilityTreeMetadata() -> [String: String] {
        [
            "accessibilityTree": "observeSummary",
            "mode": "dry-run",
            "accessibilityPolicy": "dry-run",
            "includeAccessibilityTree": "true",
            "maxCandidateControls": "20",
            "nodeCount": "1",
            "candidateControlCount": "2",
            "platform": "simulated",
            "redaction": "maskSensitiveText",
            "safetyFlags": "observe-only,values-omitted,password-fields-omitted,action-execution-not-supported,structured-arguments-only"
        ]
    }

    private static func extractionCompletenessMetadata() -> [String: String] {
        [
            "extractionReview": "artifactGrounded",
            "mode": "artifact-grounded-extraction",
            "validateCompleteness": "true",
            "rowCount": "4",
            "completenessStatus": "complete",
            "browserTraceCount": "1",
            "fileDiffCount": "1",
            "commandOutputCount": "1",
            "screenObservationCount": "1",
            "accessibilityTreeCount": "1",
            "messageDraftCount": "0",
            "sourceArtifactKinds": "browserTrace,fileDiff,commandOutput,screenObservation,accessibilityTree",
            "safetyFlags": "metadata-only,row-content-omitted,source-values-omitted,tool-arguments-omitted,artifact-payload-not-read"
        ]
    }

    private static func browserControlReviewMetadata(
        mode: String,
        resultStatus: String
    ) -> [String: String] {
        [
            "browserReview": "controlPlan",
            "mode": mode,
            "actionKind": ClawMobileActionKind.controlBrowser.rawValue,
            "browserControlPolicy": "dry-run",
            "browserControlRequested": "true",
            "openInBrowser": "true",
            "targetURLPresent": "true",
            "searchQueryPresent": "true",
            "localHTMLInput": "false",
            "networkFetchAttempted": "false",
            "networkBlocked": "false",
            "appAllowlistEnforced": "false",
            "hostAllowlistEnforced": "false",
            "executed": "false",
            "timedOut": "false",
            "resultStatus": resultStatus,
            "safetyFlags": "metadata-only,tool-arguments-omitted,url-omitted,search-query-omitted,page-content-omitted,form-fields-omitted,candidate-labels-omitted,artifact-payload-not-read"
        ]
    }

    private static func fileChangeReviewMetadata() -> [String: String] {
        [
            "fileChangeReview": "workspaceWrite",
            "mode": "workspace-write",
            "actionKind": ClawMobileActionKind.manageFiles.rawValue,
            "workspacePolicy": "session-workspace-only",
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
            "resultStatus": "succeeded",
            "safetyFlags": "metadata-only,tool-arguments-omitted,raw-path-omitted,workspace-path-omitted,file-content-omitted,diff-content-omitted,artifact-payload-not-read,session-workspace-only"
        ]
    }

    private static func shellCommandSafetyMetadata() -> [String: String] {
        [
            "shellReview": "commandSafety",
            "mode": "shell-policy-blocked",
            "actionKind": ClawMobileActionKind.runShellCommand.rawValue,
            "shellPolicy": "dry-run",
            "structuredCommandPresent": "true",
            "commandParsed": "true",
            "allowlistConfigured": "false",
            "allowlistMatched": "false",
            "executionAttempted": "false",
            "executed": "false",
            "timedOut": "false",
            "exitCodePresent": "false",
            "exitCodeZero": "false",
            "stdoutPresent": "false",
            "stderrPresent": "false",
            "commandOmitted": "true",
            "stdoutOmitted": "true",
            "stderrOmitted": "true",
            "cwdOmitted": "true",
            "resultStatus": "failed",
            "safetyFlags": "metadata-only,structured-arguments-only,tool-arguments-omitted,command-omitted,stdout-omitted,stderr-omitted,cwd-omitted,shell-allowlist-enforced,dry-run-only,no-command-executed,artifact-payload-not-read"
        ]
    }

    private static func deliverySafetyMetadata(
        for actionKind: ClawMobileActionKind,
        mode: String,
        targetKind: String,
        finalSubmitRequiresApproval: Bool,
        userApprovalRequired: Bool,
        draftBodyOmitted: Bool,
        pasteTextOmitted: Bool,
        submitBlocked: Bool,
        allowedKeyCount: Int,
        blockedKeyCount: Int,
        blockedSubmitKeyCount: Int
    ) -> [String: String] {
        var safetyFlags = [
            "metadata-only",
            "final-submit-gated",
            "user-approval-required",
            "tool-arguments-omitted",
            "artifact-payload-not-read"
        ]
        if draftBodyOmitted {
            safetyFlags.append("draft-body-omitted")
        }
        if pasteTextOmitted {
            safetyFlags.append("paste-text-omitted")
        }
        return [
            "deliveryReview": "finalSubmitGate",
            "mode": mode,
            "actionKind": actionKind.rawValue,
            "targetKind": targetKind,
            "finalSubmitRequiresApproval": String(finalSubmitRequiresApproval),
            "userApprovalRequired": String(userApprovalRequired),
            "draftBodyOmitted": String(draftBodyOmitted),
            "pasteTextOmitted": String(pasteTextOmitted),
            "submitBlocked": String(submitBlocked),
            "allowedKeyCount": String(allowedKeyCount),
            "blockedKeyCount": String(blockedKeyCount),
            "blockedSubmitKeyCount": String(blockedSubmitKeyCount),
            "safetyFlags": safetyFlags.joined(separator: ",")
        ]
    }
}

enum ClawGatewayLiveClient {
    static func makeRequest(
        task: ClawMobileTask,
        profile: ClawGatewayProfile,
        envelopeJSON: String,
        rawToken: String = ""
    ) -> ClawGatewayLiveRequest {
        let endpoint = profile.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let isWebSocket = endpoint.hasPrefix("ws://") || endpoint.hasPrefix("wss://")
        let trimmedToken = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasToken = profile.tokenFingerprint != "unset" && trimmedToken.isEmpty == false
        let canAttemptLive = endpoint.isEmpty == false && isWebSocket && hasToken
        let preflight: String
        if endpoint.isEmpty {
            preflight = "未配置桌面 Gateway endpoint。"
        } else if isWebSocket == false {
            preflight = "Gateway endpoint 必须使用 ws:// 或 wss://。"
        } else if hasToken == false {
            preflight = "缺少配对 token，只能生成请求预览。"
        } else {
            preflight = "Live Gateway 请求已准备，等待桌面端接受任务并推送事件。"
        }

        var headers = [
            "X-Claw-Device": profile.deviceName,
            "X-Claw-Schema": "claw.computer.control.v1",
            "X-Claw-Token-Fingerprint": profile.tokenFingerprint
        ]
        if trimmedToken.isEmpty == false {
            headers["Authorization"] = "Bearer \(trimmedToken)"
        }

        return ClawGatewayLiveRequest(
            endpoint: endpoint,
            tokenFingerprint: profile.tokenFingerprint,
            headers: headers,
            bodyBytes: envelopeJSON.utf8.count,
            taskID: task.id,
            command: task.command,
            actionCount: task.actions.count,
            canAttemptLive: canAttemptLive,
            preflightMessage: preflight
        )
    }

    static func liveRequestPreparedEvent(
        task: ClawMobileTask,
        sessionID: UUID,
        request: ClawGatewayLiveRequest,
        sequence: Int
    ) -> ClawGatewayEvent {
        return ClawGatewayEvent(
            sessionID: sessionID,
            taskID: task.id,
            sequence: sequence,
            kind: .liveRequestPrepared,
            summary: "\(request.preflightMessage) endpoint=\(request.endpoint) actions=\(request.actionCount) bytes=\(request.bodyBytes)"
        )
    }

    static func liveTransportProgressEvent(
        taskID: UUID,
        sessionID: UUID,
        sequence: Int,
        attempt: Int,
        reconnectCount: Int,
        pingStatus: String,
        transportErrorSummary: String? = nil,
        willRetry: Bool = false
    ) -> ClawGatewayEvent {
        var parts = [
            willRetry ? "Live Gateway WebSocket 将重连。" : "Live Gateway WebSocket 已连接，等待桌面端事件。",
            "attempt=\(attempt)",
            "reconnect=\(reconnectCount)",
            "ping=\(pingStatus)"
        ]
        if let transportErrorSummary {
            parts.append("transportError=\(transportErrorSummary)")
        }
        if willRetry {
            parts.append("willRetry=true")
        }
        return ClawGatewayEvent(
            sessionID: sessionID,
            taskID: taskID,
            sequence: sequence,
            kind: .gatewayConnected,
            summary: parts.joined(separator: " ")
        )
    }

    static func fallbackEvent(
        task: ClawMobileTask,
        sessionID: UUID,
        reason: String,
        sequence: Int,
        transportErrorSummary: String? = nil
    ) -> ClawGatewayEvent {
        var summary = "Live Gateway 未启动：\(reason) 已切换为本地事件流模拟，方便继续审查计划。"
        if let transportErrorSummary {
            summary += " transportError=\(transportErrorSummary)"
        }
        return ClawGatewayEvent(
            sessionID: sessionID,
            taskID: task.id,
            sequence: sequence,
            kind: .fallbackUsed,
            summary: summary
        )
    }

    static func safeTransportErrorSummary(_ text: String, request: ClawGatewayLiveRequest? = nil) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeEndpoint = ClawGatewayLiveRequest.safeEndpointDisplay(request?.endpoint)
        value = ClawSensitiveTextRedactor.redacted(
            value,
            rawEndpoint: request?.endpoint,
            safeEndpoint: safeEndpoint
        )
        value = value.replacingOccurrences(of: #"\s+"#, with: "_", options: .regularExpression)
        if value.isEmpty {
            return "unknown"
        }
        if value.count > 48 {
            return String(value.prefix(48)) + "..."
        }
        return value
    }

    static func requestSummary(_ request: ClawGatewayLiveRequest, session: ClawGatewaySession) -> String {
        """
        session: \(session.id.uuidString)
        status: \(session.status.title)
        mode: \(ClawGatewayDispatchMode.liveGateway.title)
        endpoint: \(request.endpoint)
        preflight: \(request.preflightMessage)
        actions: \(request.actionCount)
        """
    }
}

protocol ClawGatewayTransport: Sendable {
    func streamEvents(
        request: ClawGatewayLiveRequest,
        envelopeJSON: String,
        sessionID: UUID,
        taskID: UUID
    ) -> AsyncThrowingStream<ClawGatewayEvent, Error>
}

struct ClawGatewayTransportRetryPolicy: Equatable, Sendable {
    var maxRetries: Int
    var retryDelayNanoseconds: UInt64
    var pingAfterConnect: Bool

    static let liveDefault = ClawGatewayTransportRetryPolicy(
        maxRetries: 1,
        retryDelayNanoseconds: 250_000_000,
        pingAfterConnect: true
    )

    var maxAttempts: Int {
        max(1, maxRetries + 1)
    }
}

struct URLSessionClawGatewayTransport: ClawGatewayTransport {
    var retryPolicy: ClawGatewayTransportRetryPolicy

    init(retryPolicy: ClawGatewayTransportRetryPolicy = .liveDefault) {
        self.retryPolicy = retryPolicy
    }

    func streamEvents(
        request: ClawGatewayLiveRequest,
        envelopeJSON: String,
        sessionID: UUID,
        taskID: UUID
    ) -> AsyncThrowingStream<ClawGatewayEvent, Error> {
        AsyncThrowingStream { continuation in
            guard let url = URL(string: request.endpoint) else {
                continuation.finish(throwing: ClawGatewayTransportError.invalidEndpoint(request.endpoint))
                return
            }

            let task = Task {
                var nextSequence = 2
                var attempt = 1
                do {
                    while attempt <= retryPolicy.maxAttempts, Task.isCancelled == false {
                        var receivedDesktopEvent = false
                        let socket = URLSession.shared.webSocketTask(with: urlRequest(for: url, request: request))
                        do {
                            socket.resume()
                            try await socket.send(.string(envelopeJSON))

                            let pingStatus = await pingStatus(for: socket, policy: retryPolicy)
                            continuation.yield(ClawGatewayLiveClient.liveTransportProgressEvent(
                                taskID: taskID,
                                sessionID: sessionID,
                                sequence: nextSequence,
                                attempt: attempt,
                                reconnectCount: attempt - 1,
                                pingStatus: pingStatus
                            ))
                            nextSequence += 1

                            while Task.isCancelled == false {
                                let message = try await socket.receive()
                                let data: Data
                                switch message {
                                case .data(let payload):
                                    data = payload
                                case .string(let text):
                                    data = Data(text.utf8)
                                @unknown default:
                                    continue
                                }
                                var event = try JSONDecoder.clawGateway.decode(ClawGatewayEvent.self, from: data)
                                receivedDesktopEvent = true
                                if event.sessionID != sessionID {
                                    event = ClawGatewayEvent(
                                        id: event.id,
                                        sessionID: sessionID,
                                        taskID: taskID,
                                        sequence: event.sequence,
                                        kind: event.kind,
                                        actionID: event.actionID,
                                        actionKind: event.actionKind,
                                        actionTitle: event.actionTitle,
                                        resultStatus: event.resultStatus,
                                        summary: event.summary,
                                        artifacts: event.artifacts,
                                        isRetryable: event.isRetryable,
                                        retryCount: event.retryCount,
                                        createdAt: event.createdAt
                                    )
                                }
                                if event.sequence <= 0 {
                                    event.sequence = nextSequence
                                    nextSequence += 1
                                } else {
                                    nextSequence = max(nextSequence, event.sequence + 1)
                                }
                                continuation.yield(event)
                                if event.kind == .sessionCompleted {
                                    socket.cancel(with: .normalClosure, reason: nil)
                                    continuation.finish()
                                    return
                                }
                            }
                            socket.cancel(with: .goingAway, reason: nil)
                            continuation.finish()
                            return
                        } catch {
                            socket.cancel(with: .goingAway, reason: nil)
                            let canRetry = attempt < retryPolicy.maxAttempts && receivedDesktopEvent == false
                            if canRetry {
                                attempt += 1
                                let safeError = ClawGatewayLiveClient.safeTransportErrorSummary(
                                    error.localizedDescription,
                                    request: request
                                )
                                continuation.yield(ClawGatewayLiveClient.liveTransportProgressEvent(
                                    taskID: taskID,
                                    sessionID: sessionID,
                                    sequence: nextSequence,
                                    attempt: attempt,
                                    reconnectCount: attempt - 1,
                                    pingStatus: "skipped",
                                    transportErrorSummary: safeError,
                                    willRetry: true
                                ))
                                nextSequence += 1
                                try await Task.sleep(for: .nanoseconds(Int64(retryPolicy.retryDelayNanoseconds)))
                                continue
                            }
                            throw error
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func urlRequest(for url: URL, request: ClawGatewayLiveRequest) -> URLRequest {
        var urlRequest = URLRequest(url: url)
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        return urlRequest
    }

    private func pingStatus(
        for socket: URLSessionWebSocketTask,
        policy: ClawGatewayTransportRetryPolicy
    ) async -> String {
        guard policy.pingAfterConnect else {
            return "skipped"
        }
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                socket.sendPing { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            return "ok"
        } catch {
            return "failed"
        }
    }
}

enum ClawGatewayTransportError: LocalizedError {
    case invalidEndpoint(String)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint(let endpoint):
            return "Invalid Claw Gateway endpoint: \(endpoint)"
        }
    }
}

extension JSONDecoder {
    static var clawGateway: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

enum ClawGatewayEventStream {
    static func makePreparedSession(
        task: ClawMobileTask,
        profile: ClawGatewayProfile,
        mode: ClawGatewayDispatchMode
    ) -> ClawGatewaySession {
        ClawGatewaySession(
            taskID: task.id,
            command: task.command,
            channel: "iOS Controller -> \(mode.title)",
            workspace: "~/ClawWorkspace",
            status: .prepared,
            results: [],
            auditTrail: [
                "session.prepared source=Claw Controller gateway=\(profile.endpoint)",
                "task.riskScore=\(task.riskScore) approvals=\(task.approvalCount) sensitive=\(task.sensitiveActionCount)",
                "dispatch.mode=\(mode.rawValue) token=\(profile.tokenFingerprint)"
            ]
        )
    }

    static func sessionPreparedEvent(
        task: ClawMobileTask,
        sessionID: UUID,
        mode: ClawGatewayDispatchMode
    ) -> ClawGatewayEvent {
        ClawGatewayEvent(
            sessionID: sessionID,
            taskID: task.id,
            sequence: 0,
            kind: .sessionPrepared,
            summary: "Claw session 已创建，模式 \(mode.title)，等待 Gateway 事件。"
        )
    }

    static func simulatedEvents(
        task: ClawMobileTask,
        profile: ClawGatewayProfile,
        sessionID: UUID,
        startingSequence: Int
    ) -> [ClawGatewayEvent] {
        var sequence = startingSequence
        var events: [ClawGatewayEvent] = [
            ClawGatewayEvent(
                sessionID: sessionID,
                taskID: task.id,
                sequence: sequence,
                kind: .gatewayConnected,
                summary: "模拟 Gateway 已接收任务，安全模式 \(profile.securityMode.title)，workspace=~/ClawWorkspace。"
            )
        ]
        sequence += 1

        events.append(
            ClawGatewayEvent(
                sessionID: sessionID,
                taskID: task.id,
                sequence: sequence,
                kind: .artifactStored,
                summary: "保存 Gateway 能力快照 artifact。",
                artifacts: [ClawGatewaySimulator.capabilitySnapshotArtifact(for: profile)]
            )
        )
        sequence += 1

        for (index, action) in task.actions.enumerated() {
            let result = ClawGatewaySimulator.makeResult(for: action, index: index)
            events.append(
                ClawGatewayEvent(
                    sessionID: sessionID,
                    taskID: task.id,
                    sequence: sequence,
                    kind: .actionStarted,
                    actionID: action.id,
                    actionKind: action.kind,
                    actionTitle: action.title,
                    resultStatus: .running,
                    summary: "开始执行：\(action.title)。"
                )
            )
            sequence += 1

            if result.artifacts.isEmpty == false {
                events.append(
                    ClawGatewayEvent(
                        sessionID: sessionID,
                        taskID: task.id,
                        sequence: sequence,
                        kind: .artifactStored,
                        actionID: action.id,
                        actionKind: action.kind,
                        actionTitle: action.title,
                        resultStatus: .running,
                        summary: "保存 \(result.artifacts.count) 个 artifact。",
                        artifacts: result.artifacts
                    )
                )
                sequence += 1
            }

            events.append(
                ClawGatewayEvent(
                    sessionID: sessionID,
                    taskID: task.id,
                    sequence: sequence,
                    kind: eventKind(for: result.status),
                    actionID: action.id,
                    actionKind: action.kind,
                    actionTitle: action.title,
                    resultStatus: result.status,
                    summary: result.summary,
                    isRetryable: result.isRetryable,
                    retryCount: result.retryCount
                )
            )
            sequence += 1
        }

        events.append(
            ClawGatewayEvent(
                sessionID: sessionID,
                taskID: task.id,
                sequence: sequence,
                kind: .sessionCompleted,
                summary: "Gateway 事件流结束，控制端已汇总结果。"
            )
        )
        return events
    }

    static func apply(
        event: ClawGatewayEvent,
        to session: ClawGatewaySession
    ) -> ClawGatewaySession {
        var updated = session
        updated.updatedAt = event.createdAt

        switch event.kind {
        case .sessionPrepared:
            updated.status = .prepared
            updated.auditTrail.append("event.\(event.sequence) sessionPrepared \(event.summary)")
        case .liveRequestPrepared:
            updated.status = .running
            updated.auditTrail.append("event.\(event.sequence) liveRequestPrepared \(event.summary)")
        case .gatewayConnected:
            updated.status = .running
            updated.auditTrail.append("event.\(event.sequence) gatewayConnected \(event.summary)")
        case .actionStarted:
            upsertResult(from: event, in: &updated, fallbackStatus: .running, finished: false)
        case .artifactStored:
            if event.actionID == nil || event.actionKind == nil || event.actionTitle == nil {
                mergeSessionArtifacts(from: event, in: &updated)
            } else {
                upsertResult(from: event, in: &updated, fallbackStatus: .running, finished: false)
            }
        case .actionCompleted, .actionFailed, .approvalRequested, .actionSkipped:
            upsertResult(from: event, in: &updated, fallbackStatus: event.resultStatus ?? .succeeded, finished: true)
        case .sessionCompleted:
            updated.status = finalStatus(for: updated.results)
            updated.auditTrail.append("event.\(event.sequence) sessionCompleted \(event.summary)")
        case .fallbackUsed:
            updated.status = .running
            updated.auditTrail.append("event.\(event.sequence) fallbackUsed \(event.summary)")
        }

        return updated
    }

    static func eventSummary(
        for session: ClawGatewaySession,
        latestEvent: ClawGatewayEvent?
    ) -> String {
        """
        session: \(session.id.uuidString)
        status: \(session.status.title)
        latestEvent: \(latestEvent?.kind.title ?? "无")
        summary: \(latestEvent?.summary ?? "等待 Gateway 事件。")
        results: \(session.succeededCount) succeeded / \(session.failedCount) failed / \(session.retryableCount) retryable
        artifacts: \(session.artifactCount)
        """
    }

    private static func eventKind(for status: ClawGatewayActionResultStatus) -> ClawGatewayEventKind {
        switch status {
        case .pending, .running:
            return .actionStarted
        case .succeeded:
            return .actionCompleted
        case .failed:
            return .actionFailed
        case .skipped:
            return .actionSkipped
        case .waitingForApproval:
            return .approvalRequested
        }
    }

    private static func upsertResult(
        from event: ClawGatewayEvent,
        in session: inout ClawGatewaySession,
        fallbackStatus: ClawGatewayActionResultStatus,
        finished: Bool
    ) {
        guard let actionID = event.actionID,
              let actionKind = event.actionKind,
              let actionTitle = event.actionTitle else {
            return
        }

        let status = event.resultStatus ?? fallbackStatus
        let finishedAt = finished ? event.createdAt : nil
        if let index = session.results.firstIndex(where: { $0.actionID == actionID }) {
            session.results[index].status = status
            session.results[index].summary = event.summary
            session.results[index].artifacts = mergedArtifacts(
                session.results[index].artifacts,
                event.artifacts
            )
            session.results[index].isRetryable = event.isRetryable
            session.results[index].retryCount = event.retryCount
            session.results[index].finishedAt = finishedAt
        } else {
            session.results.append(
                ClawGatewayActionResult(
                    actionID: actionID,
                    actionKind: actionKind,
                    actionTitle: actionTitle,
                    status: status,
                    summary: event.summary,
                    artifacts: event.artifacts,
                    isRetryable: event.isRetryable,
                    retryCount: event.retryCount,
                    startedAt: event.createdAt,
                    finishedAt: finishedAt
                )
            )
        }
    }

    private static func mergeSessionArtifacts(
        from event: ClawGatewayEvent,
        in session: inout ClawGatewaySession
    ) {
        session.sessionArtifacts = mergedArtifacts(session.sessionArtifacts, event.artifacts)
        if event.artifacts.isEmpty {
            session.auditTrail.append("event.\(event.sequence) artifactStored session-level no artifacts")
        } else {
            let titles = event.artifacts.map(\.title).joined(separator: ",")
            session.auditTrail.append("event.\(event.sequence) artifactStored session-level \(event.artifacts.count) artifact(s) \(titles)")
        }
    }

    private static func mergedArtifacts(
        _ existing: [ClawGatewayArtifact],
        _ incoming: [ClawGatewayArtifact]
    ) -> [ClawGatewayArtifact] {
        var merged = existing
        for artifact in incoming {
            if merged.contains(where: { $0.reference == artifact.reference }) == false {
                merged.append(artifact)
            }
        }
        return merged
    }

    private static func finalStatus(for results: [ClawGatewayActionResult]) -> ClawGatewaySessionStatus {
        if results.contains(where: { $0.status == .skipped }) {
            return .blocked
        }
        if results.contains(where: { $0.status == .failed || $0.status == .waitingForApproval }) {
            return .needsAttention
        }
        return .completed
    }
}

struct LocalClawAgentRuntime {
    func generate(
        prompt: String,
        skill: ClawSkill?,
        model: LocalClawModel,
        validation: ArtifactValidationResult
    ) -> String {
        let taskTitle = skill?.title ?? "电脑任务规划"
        let categoryTitle = skill?.category.title ?? "通用电脑操作"
        let runtimeState = validation.canRunRealWeights ? "REAL_READY" : "SIM_ONLY"

        return """
        [\(runtimeState)] \(model.name) 不会下载真实权重，以下是模拟端侧规划输出。

        任务：\(taskTitle)（\(categoryTitle)）
        处理建议：
        1. 识别目标应用、输入来源、输出格式、成功条件和失败回滚点。
        2. 把浏览器、文件、Shell、桌面 App 和消息发送拆成可审批动作。
        3. 生成可交给 Claw Gateway 的结构化任务，并保留截图、命令和文件变更审计。

        针对输入「\(prompt)」，建议先形成可检查的执行计划，再由用户批准高风险电脑动作。真实 runtime 接入后，应优先在本机推理，不把屏幕、文件或账号上下文上传到外部服务。
        """
    }
}

extension ClawStore {
    static let defaultModel = LocalClawModel(
        name: "Claw Local Agent 1.5B",
        family: "Local Agent",
        parameterCount: "1.5B",
        quantization: "4-bit",
        contextLength: 8192,
        sizeOnDisk: "待导入",
        memoryFootprint: "约 1.8 GB",
        installState: .placeholder,
        summary: "本地 Agent 权重暂未导入；当前启用 UI、规划器、网关 payload 和模拟电脑操作推理。",
        supportedTasks: ClawCapabilityCategory.allCases,
        artifactManifest: ModelArtifactManifest(
            modelFileName: "claw-local-agent-q4.mlmodelc",
            tokenizerFileName: "claw-tokenizer.model",
            fileFormat: "Core ML compiled package",
            storageDirectory: "Application Support/ClawLocalModels",
            expectedSHA256: "manual-import-required",
            allowsNetworkDownload: false,
            importInstruction: "后续把转换好的本地 Agent Core ML 包和 tokenizer 通过 Files 手动导入；当前版本不会下载模型。"
        )
    )

    static let initialMessages: [ChatMessage] = [
        ChatMessage(
            role: .system,
            text: "Claw 以本地/自托管电脑智能体为目标 runtime。当前模型留空，真实权重未安装，所有回答均为模拟规划结果。"
        ),
        ChatMessage(
            role: .assistant,
            text: "选择一个电脑能力，描述要接管电脑完成的任务，我会生成可审批的浏览器、文件、Shell、桌面 App 和消息发送计划。"
        )
    ]

    static let defaultSkills: [ClawSkill] = [
        ClawSkill(
            title: "浏览器研究",
            subtitle: "打开网页、搜索资料、跨标签提取信息并整理结果",
            category: .browser,
            promptTemplate: "请把目标拆成浏览器操作步骤：搜索、打开页面、提取数据、引用来源、输出表格。",
            icon: "safari.fill",
            popularity: 96,
            runCount: 25300,
            recommendedInputs: ["打开浏览器搜索三个竞品的价格和功能，整理成表格"]
        ),
        ClawSkill(
            title: "文件管家",
            subtitle: "在授权目录内查找、重命名、移动、导出和归档文件",
            category: .files,
            promptTemplate: "请列出文件操作计划：目标目录、匹配规则、写入动作、回滚方案和审计摘要。",
            icon: "folder.fill",
            popularity: 91,
            runCount: 18700,
            recommendedInputs: ["把下载目录里的发票 PDF 按月份归档，并生成清单"]
        ),
        ClawSkill(
            title: "邮件与消息",
            subtitle: "整理收件箱、草拟回复、发送 Slack/IM 消息并等待确认",
            category: .communications,
            promptTemplate: "请生成消息处理计划：读取范围、候选回复、确认点、禁止静默发送的动作。",
            icon: "envelope.fill",
            popularity: 88,
            runCount: 14200,
            recommendedInputs: ["阅读今天的未读邮件，标出需要我回复的三封并起草回复"]
        ),
        ClawSkill(
            title: "表单录入",
            subtitle: "根据源数据打开后台系统、填表、校验字段并提交前等待确认",
            category: .dataEntry,
            promptTemplate: "请生成表单自动化计划：字段映射、校验规则、截图确认和提交审批。",
            icon: "rectangle.and.pencil.and.ellipsis",
            popularity: 82,
            runCount: 11600,
            recommendedInputs: ["把 CSV 里的客户信息录入后台系统，提交前让我确认"]
        ),
        ClawSkill(
            title: "代码与脚本",
            subtitle: "在受控目录运行命令、修复脚本、执行测试并回传输出",
            category: .scripts,
            promptTemplate: "请生成受控 Shell 计划：命令列表、工作目录、预期输出、危险命令拦截。",
            icon: "terminal.fill",
            popularity: 77,
            runCount: 9300,
            recommendedInputs: ["在项目目录运行测试，失败时定位原因并给出补丁建议"]
        ),
        ClawSkill(
            title: "安全审计",
            subtitle: "审查网关权限、外网暴露、凭证、命令白名单和高风险动作",
            category: .security,
            promptTemplate: "请生成 Agent 安全审计清单：网络暴露、token、凭证、目录权限、工具调用和审批策略。",
            icon: "lock.shield.fill",
            popularity: 74,
            runCount: 8700,
            recommendedInputs: ["检查我的 Claw Gateway 配置是否有外网暴露和过宽权限"]
        )
    ]

    nonisolated static let defaultDocuments: [WorkspaceContext] = [
        WorkspaceContext(
            title: "桌面接管 Playbook",
            type: "Runbook",
            updatedAt: Date(timeIntervalSinceNow: -3600 * 3),
            summary: "定义浏览器、文件、Shell、桌面 App 的审批和回滚策略。",
            riskLevel: 4
        ),
        WorkspaceContext(
            title: "Claw Gateway 权限清单",
            type: "Policy",
            updatedAt: Date(timeIntervalSinceNow: -3600 * 26),
            summary: "记录可访问目录、命令白名单、网络入口和 token 指纹。",
            riskLevel: 5
        ),
        WorkspaceContext(
            title: "自动化任务样例",
            type: "Examples",
            updatedAt: Date(timeIntervalSinceNow: -3600 * 48),
            summary: "包含网页研究、收件箱整理、文件归档和脚本测试流程。",
            riskLevel: 3
        )
    ]

    nonisolated static let defaultClawGatewayProfile = ClawGatewayProfile(
        endpoint: "ws://192.168.1.12:18789",
        deviceName: "Claw Controller iPhone",
        securityMode: .mutualApproval,
        tokenFingerprint: "unset",
        allowedActionKinds: [
            .analyzeLocalContext,
            .requestPermission,
            .runAgentLoop,
            .observeScreen,
            .controlBrowser,
            .operateDesktopApp,
            .manageFiles,
            .runShellCommand,
            .extractData,
            .readContacts,
            .composeMessage,
            .composeEmail,
            .createReminder,
            .scheduleNotification,
            .openExternalURL,
            .runShortcut,
            .speechCapture,
            .backgroundRefresh,
            .desktopHandoff,
            .auditLog
        ],
        requiresApprovalForSensitiveData: true,
        auditEnabled: true
    )

    nonisolated static let defaultPhoneAgentCapabilities: [PhoneAgentCapability] = [
        PhoneAgentCapability(
            title: "本 App 内任务规划",
            summary: "LLM 拆解指令、生成电脑操作计划、审批点和审计记录。",
            permissionName: "无需额外系统权限",
            framework: "Foundation / SwiftUI",
            surface: .clawRuntime,
            permissionState: .configured,
            runMode: .automaticInsideApp,
            canRead: true,
            canWrite: true,
            examples: ["桌面任务规划", "审批清单", "本地执行日志"],
            limitation: "只能处理用户输入和网关回传的数据，不能直接读取电脑屏幕或其他 App 私有内容。",
            appleReference: "https://developer.apple.com/documentation/foundation"
        ),
        PhoneAgentCapability(
            title: "Siri 与快捷指令入口",
            summary: "把 Claw 控制台动作暴露给 Siri、Shortcuts、Spotlight 和系统建议。",
            permissionName: "App Intents / App Shortcuts",
            framework: "AppIntents",
            surface: .appIntents,
            permissionState: .configured,
            runMode: .shortcutOrSiri,
            canRead: false,
            canWrite: true,
            examples: ["生成电脑接管计划", "把任务交给 Claw Gateway"],
            limitation: "App Intents 暴露的是本 App 能力，不等于获得控制其他 App 的通用权限。",
            appleReference: "https://developer.apple.com/documentation/appintents"
        ),
        PhoneAgentCapability(
            title: "语音指令输入",
            summary: "把用户语音转成 Claw 电脑操作指令，交给本地规划器或 Agent runtime。",
            permissionName: "Microphone / Speech Recognition",
            framework: "AVFAudio / Speech",
            surface: .siriKit,
            permissionState: .needsUserGrant,
            runMode: .automaticWithPermission,
            canRead: true,
            canWrite: false,
            examples: ["语音下达电脑任务", "口述浏览器研究目标"],
            limitation: "这是 App 自己的语音入口，不是替代系统 Siri；语音识别和麦克风都需要用户授权。",
            appleReference: "https://developer.apple.com/documentation/speech"
        ),
        PhoneAgentCapability(
            title: "通讯录匹配",
            summary: "在用户授权后读取联系人，用于确认收件人、邮件地址和协作频道。",
            permissionName: "Contacts",
            framework: "Contacts",
            surface: .systemFramework,
            permissionState: .needsUserGrant,
            runMode: .automaticWithPermission,
            canRead: true,
            canWrite: false,
            examples: ["补全邮件地址", "确认 Slack/IM 收件人"],
            limitation: "需要用户授权，不能读取第三方 App 好友列表。",
            appleReference: "https://developer.apple.com/documentation/contacts"
        ),
        PhoneAgentCapability(
            title: "短信草稿",
            summary: "创建短信/iMessage 撰写界面，把内容填好后由用户点发送。",
            permissionName: "MessageUI",
            framework: "MessageUI",
            surface: .composeController,
            permissionState: .limited,
            runMode: .needsUserConfirmation,
            canRead: false,
            canWrite: true,
            examples: ["给团队发送任务结果", "通知用户回到电脑审批"],
            limitation: "普通 App 不能静默发送短信，也不能读取 Messages 收件箱。",
            appleReference: "https://developer.apple.com/documentation/messageui/mfmessagecomposeviewcontroller"
        ),
        PhoneAgentCapability(
            title: "邮件草稿",
            summary: "生成邮件正文和附件草稿，用户确认后发送。",
            permissionName: "MessageUI",
            framework: "MessageUI",
            surface: .composeController,
            permissionState: .limited,
            runMode: .needsUserConfirmation,
            canRead: false,
            canWrite: true,
            examples: ["发送研究结果", "发送任务执行摘要"],
            limitation: "发送动作在系统 compose 界面中完成，不能后台静默发送用户邮件。",
            appleReference: "https://developer.apple.com/documentation/messageui/mfmailcomposeviewcontroller"
        ),
        PhoneAgentCapability(
            title: "日历与提醒",
            summary: "授权后创建会议、检查点、任务截止时间和继续审批提醒。",
            permissionName: "Calendar / Reminders",
            framework: "EventKit",
            surface: .systemFramework,
            permissionState: .needsUserGrant,
            runMode: .automaticWithPermission,
            canRead: true,
            canWrite: true,
            examples: ["明天 10 点检查任务结果", "网关审批提醒"],
            limitation: "只能访问授权范围内的日历/提醒；系统可能要求用户选择访问级别。",
            appleReference: "https://developer.apple.com/documentation/eventkit"
        ),
        PhoneAgentCapability(
            title: "通知提醒",
            summary: "授权后发送本地通知，提醒用户审核、确认或继续自动化流程。",
            permissionName: "Notifications",
            framework: "UserNotifications",
            surface: .systemFramework,
            permissionState: .needsUserGrant,
            runMode: .automaticWithPermission,
            canRead: false,
            canWrite: true,
            examples: ["发送前确认", "高风险 Shell 审批"],
            limitation: "通知展示和打扰策略受系统设置控制。",
            appleReference: "https://developer.apple.com/documentation/usernotifications"
        ),
        PhoneAgentCapability(
            title: "后台工作",
            summary: "在系统允许的时机刷新网关任务状态、准备摘要和安排提醒。",
            permissionName: "BackgroundTasks",
            framework: "BackgroundTasks",
            surface: .backgroundTask,
            permissionState: .notRequested,
            runMode: .automaticWithPermission,
            canRead: true,
            canWrite: true,
            examples: ["定期检查网关任务", "刷新待审批队列"],
            limitation: "不能常驻运行，不能保证精确定时，执行窗口由 iOS 调度。",
            appleReference: "https://developer.apple.com/documentation/backgroundtasks"
        ),
        PhoneAgentCapability(
            title: "打开目标 App 或网页",
            summary: "通过 URL Scheme 或 Universal Links 打开目标 App 的公开入口。",
            permissionName: "UIApplication.open",
            framework: "UIKit",
            surface: .urlScheme,
            permissionState: .configured,
            runMode: .automaticWithPermission,
            canRead: false,
            canWrite: true,
            examples: ["打开网页结果", "打开 IM 草稿链接"],
            limitation: "目标 App 必须公开入口；本 App 不能确认目标 App 内部动作是否完成。",
            appleReference: "https://developer.apple.com/documentation/uikit/uiapplication/open(_:options:completionhandler:)"
        ),
        PhoneAgentCapability(
            title: "读取其他 App 消息",
            summary: "读取短信、iMessage、微信、钉钉等第三方 App 收件箱。",
            permissionName: "无公开授权",
            framework: "iOS sandbox",
            surface: .unavailable,
            permissionState: .unavailable,
            runMode: .blockedByIOS,
            canRead: false,
            canWrite: false,
            examples: ["自动读取微信消息", "监听系统短信"],
            limitation: "iOS 沙盒不允许普通 App 读取其他 App 私有数据。",
            appleReference: "https://developer.apple.com/documentation/security"
        ),
        PhoneAgentCapability(
            title: "Claw 跨软件网关",
            summary: "把 LLM 计划、屏幕观察、浏览器、文件、Shell、桌面 App 和确认点发给用户授权的桌面/自托管代理执行。",
            permissionName: "用户自建网关",
            framework: "Network",
            surface: .clawGateway,
            permissionState: .configured,
            runMode: .gatewayOnly,
            canRead: true,
            canWrite: true,
            examples: ["桌面端打开 IM", "浏览器填表", "整理外部文件", "运行测试命令"],
            limitation: "不属于 iOS 本机权限；需要用户部署、认证、审计和最小权限策略。",
            appleReference: "https://developer.apple.com/documentation/network"
        ),
        PhoneAgentCapability(
            title: "桌面屏幕观察",
            summary: "由网关采集屏幕截图、窗口标题和可访问性树，供模型判断下一步动作。",
            permissionName: "桌面端屏幕录制/辅助功能",
            framework: "Claw Gateway",
            surface: .clawGateway,
            permissionState: .configured,
            runMode: .gatewayOnly,
            canRead: true,
            canWrite: false,
            examples: ["定位按钮", "读取当前网页", "确认弹窗状态"],
            limitation: "需要桌面端显式授权屏幕录制和辅助功能；敏感窗口应由用户排除。",
            appleReference: "https://developer.apple.com/documentation/network"
        ),
        PhoneAgentCapability(
            title: "受控 Shell",
            summary: "在用户允许的目录和命令策略内执行脚本、测试、构建和数据处理。",
            permissionName: "命令白名单 / 工作目录",
            framework: "Claw Gateway",
            surface: .clawGateway,
            permissionState: .configured,
            runMode: .gatewayOnly,
            canRead: true,
            canWrite: true,
            examples: ["运行 npm test", "执行 Python 清洗脚本", "读取命令输出"],
            limitation: "Shell 是高风险能力，默认必须审批，禁止破坏性命令和越权目录。",
            appleReference: "https://developer.apple.com/documentation/network"
        ),
        PhoneAgentCapability(
            title: "桌面文件系统",
            summary: "在授权目录内查找、读取、整理、导出和上传文件。",
            permissionName: "授权目录",
            framework: "Claw Gateway",
            surface: .clawGateway,
            permissionState: .configured,
            runMode: .gatewayOnly,
            canRead: true,
            canWrite: true,
            examples: ["归档下载文件", "导出 CSV", "上传附件"],
            limitation: "默认禁止访问主目录全量内容；所有写入都需要记录 diff 或文件清单。",
            appleReference: "https://developer.apple.com/documentation/network"
        )
    ]

    static let defaultAutomationTargets: [AutomationTarget] = [
        AutomationTarget(
            appName: "Shortcuts",
            channel: .appIntent,
            actionTitle: "把电脑任务交给快捷指令",
            endpoint: "AppIntent:BuildClawTask",
            payloadPreview: "command, approvals, gatewayPayload",
            requiresUserConfirmation: true,
            isConfigured: true,
            limitation: "适合调用本 App 暴露的 Intent；不能静默控制任意第三方 App。"
        ),
        AutomationTarget(
            appName: "Desktop Browser",
            channel: .clawGateway,
            actionTitle: "打开浏览器并执行网页流程",
            endpoint: "ws://host:18789/browser",
            payloadPreview: "open, search, click, extract, screenshot",
            requiresUserConfirmation: true,
            isConfigured: true,
            limitation: "浏览器操作在桌面网关执行；高风险表单提交前必须回到手机审批。"
        ),
        AutomationTarget(
            appName: "Desktop Files",
            channel: .clawGateway,
            actionTitle: "整理授权目录内文件",
            endpoint: "ws://host:18789/files",
            payloadPreview: "find, move, rename, export, diff",
            requiresUserConfirmation: true,
            isConfigured: true,
            limitation: "文件写入必须限定目录并记录变更清单；默认不允许全盘访问。"
        ),
        AutomationTarget(
            appName: "Shell Runner",
            channel: .clawGateway,
            actionTitle: "运行受控命令",
            endpoint: "ws://host:18789/shell",
            payloadPreview: "cwd, command, timeout, allowlist",
            requiresUserConfirmation: true,
            isConfigured: true,
            limitation: "Shell 任务默认高风险，必须审批命令、目录和超时。"
        ),
        AutomationTarget(
            appName: "Mail / IM",
            channel: .shareSheet,
            actionTitle: "发送任务结果草稿",
            endpoint: "UIActivityViewController",
            payloadPreview: "result summary, attachment, recipients",
            requiresUserConfirmation: true,
            isConfigured: true,
            limitation: "Share Sheet 由用户确认目标 App 和发送动作。"
        ),
        AutomationTarget(
            appName: "Mobile Safari",
            channel: .universalLink,
            actionTitle: "打开移动端任务链接",
            endpoint: "https://example.com/search?q={query}",
            payloadPreview: "query, task URL",
            requiresUserConfirmation: false,
            isConfigured: false,
            limitation: "只有目标域名配置了 Universal Links 才会直达 App，否则进入浏览器。"
        ),
        AutomationTarget(
            appName: "Desktop IM",
            channel: .urlScheme,
            actionTitle: "打开草稿消息",
            endpoint: "corpchat://message?text={encoded}",
            payloadPreview: "任务结果和下一步",
            requiresUserConfirmation: false,
            isConfigured: false,
            limitation: "需要目标 App 公开 URL scheme，并在 Info.plist 登记查询白名单。"
        ),
        AutomationTarget(
            appName: "Claw Desktop Gateway",
            channel: .clawGateway,
            actionTitle: "远程执行跨软件流程",
            endpoint: "ws://host:18789",
            payloadPreview: "打开软件、粘贴摘要、导出结果",
            requiresUserConfirmation: true,
            isConfigured: true,
            limitation: "iOS 端只发送任务；真正的跨 App UI 自动化需由用户授权的 Claw 网关在远端设备执行。"
        )
    ]
}
