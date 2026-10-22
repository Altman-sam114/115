import Foundation

/// Presentation-only sizing. A layout change cannot authorize or send a task.
enum ClawWorkspaceLayout {
    static let minimumReviewColumnWidth: Double = 900

    static func usesReviewColumn(width: Double, accessibilitySize: Bool) -> Bool {
        width.isFinite && width >= minimumReviewColumnWidth && !accessibilitySize
    }

    static func leadingColumnWidth(for width: Double) -> Double {
        guard width.isFinite, width > 0 else { return 330 }
        return min(max(width * 0.36, 330), 440)
    }
}

enum ClawWorkspaceDetailSection: String, CaseIterable, Identifiable, Sendable {
    case plan, review, events, connection

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plan: "计划与审批"
        case .review: "证据复核"
        case .events: "会话与事件"
        case .connection: "连接与权限"
        }
    }

    var icon: String {
        switch self {
        case .plan: "checklist"
        case .review: "doc.text.magnifyingglass"
        case .events: "waveform.path.ecg"
        case .connection: "lock.shield"
        }
    }
}

enum ClawWorkspaceResultSource: Equatable, Sendable {
    case noSession, simulated, liveUnconfirmed, liveEvents, unknown

    static func resolve(channel: String?, hasGatewayAck: Bool) -> Self {
        guard let channel else { return .noSession }
        if channel == "iOS Controller -> \(ClawGatewayDispatchMode.simulatedEventStream.title)" {
            return .simulated
        }
        if channel == "iOS Controller -> \(ClawGatewayDispatchMode.liveGateway.title)" {
            return hasGatewayAck ? .liveEvents : .liveUnconfirmed
        }
        return .unknown
    }

    var title: String {
        switch self {
        case .noSession: "尚无执行会话"
        case .simulated: "模拟结果"
        case .liveUnconfirmed: "Live 结果未确认"
        case .liveEvents: "Live 事件已接收"
        case .unknown: "来源需复核"
        }
    }

    var icon: String {
        switch self {
        case .noSession: "tray"
        case .simulated: "play.circle"
        case .liveUnconfirmed: "questionmark.circle"
        case .liveEvents: "antenna.radiowaves.left.and.right"
        case .unknown: "exclamationmark.triangle"
        }
    }
}

struct ClawWorkspacePresentationState: Equatable, Sendable {
    var selectedDetail: ClawWorkspaceDetailSection = .plan
    var showsAdvancedReviews = false
    var showsEnvelope = false

    mutating func revealReview() {
        selectedDetail = .review
    }
}

enum ClawWorkspacePresentationContract {
    static let minimumHitArea: Double = 44
    static let navigationHint = "只切换本机详情，不审批、不发送、不重试，也不执行电脑动作"
    static let advancedHint = "只展开既有安全诊断，不改变任务或授权，也不读取 artifact 正文"
}

/// Unapplied form input stays in the owning view, never in checkpoints or wire data.
struct ClawContinuationEditorInputState: Equatable, Sendable {
    var fileWritePath = ""
    var fileWriteText = ""
    var extractionGoal = ""
    var extractionOutputPath = ""
    private var loadedScope: Scope?

    init() {}

    mutating func synchronize(
        with summary: ClawContinuationDraftPresentationSummary,
        replacingInputs: Bool = false
    ) {
        guard let scope = Self.scope(for: summary) else {
            self = Self()
            return
        }
        guard replacingInputs || scope != loadedScope else { return }
        loadedScope = scope
        fileWritePath = summary.fileArguments.isVisible ? summary.fileArguments.writePath : ""
        fileWriteText = summary.fileArguments.isVisible ? summary.fileArguments.writeText : ""
        extractionGoal = summary.extractionArguments.isVisible ? summary.extractionArguments.extractionGoal : ""
        extractionOutputPath = summary.extractionArguments.isVisible ? summary.extractionArguments.outputPath : ""
    }

    func isBound(to summary: ClawContinuationDraftPresentationSummary) -> Bool {
        guard let scope = Self.scope(for: summary) else { return false }
        return scope == loadedScope
    }

    func canApply(
        rendered: ClawContinuationDraftPresentationSummary,
        current: ClawContinuationDraftPresentationSummary
    ) -> Bool {
        isBound(to: rendered) && rendered == current &&
            ((current.fileArguments.isVisible && current.fileArguments.isEditable) ||
             (current.extractionArguments.isVisible && current.extractionArguments.isEditable))
    }

    private static func scope(for summary: ClawContinuationDraftPresentationSummary) -> Scope? {
        guard summary.isVisible,
              let draftID = summary.draftID,
              let taskID = summary.sourceTaskID,
              let sessionID = summary.sourceSessionID,
              summary.fileArguments.isVisible != summary.extractionArguments.isVisible else { return nil }
        return Scope(draftID: draftID, taskID: taskID, sessionID: sessionID, isFile: summary.fileArguments.isVisible)
    }

    private struct Scope: Equatable, Sendable {
        let draftID: UUID
        let taskID: UUID
        let sessionID: UUID
        let isFile: Bool
    }
}
