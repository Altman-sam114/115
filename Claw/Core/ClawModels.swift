import Foundation
import CryptoKit

enum ModelInstallState: String, CaseIterable, Identifiable, Sendable {
    case placeholder
    case staged
    case verified

    var id: String { rawValue }

    var title: String {
        switch self {
        case .placeholder:
            return "未安装"
        case .staged:
            return "已暂存"
        case .verified:
            return "已校验"
        }
    }
}

enum ClawCapabilityCategory: String, CaseIterable, Identifiable, Sendable {
    case browser
    case files
    case communications
    case dataEntry
    case scripts
    case security

    var id: String { rawValue }

    var title: String {
        switch self {
        case .browser:
            return "浏览器控制"
        case .files:
            return "文件与系统"
        case .communications:
            return "邮件与消息"
        case .dataEntry:
            return "数据录入"
        case .scripts:
            return "代码与脚本"
        case .security:
            return "安全审计"
        }
    }

    var icon: String {
        switch self {
        case .browser:
            return "safari.fill"
        case .files:
            return "folder.fill"
        case .communications:
            return "person.2.fill"
        case .dataEntry:
            return "rectangle.and.pencil.and.ellipsis"
        case .scripts:
            return "terminal.fill"
        case .security:
            return "checkmark.shield.fill"
        }
    }
}

struct ModelArtifactManifest: Equatable, Sendable {
    let modelFileName: String
    let tokenizerFileName: String
    let fileFormat: String
    let storageDirectory: String
    let expectedSHA256: String
    let allowsNetworkDownload: Bool
    let importInstruction: String

    var requiredFiles: [String] {
        [modelFileName, tokenizerFileName]
    }
}

enum ArtifactAvailability: String, Equatable, Sendable {
    case missing
    case staged
    case verified

    var title: String {
        switch self {
        case .missing:
            return "缺失"
        case .staged:
            return "待校验"
        case .verified:
            return "可运行"
        }
    }
}

struct ArtifactFileStatus: Equatable, Sendable {
    let fileName: String
    let exists: Bool
    let byteCount: Int64?
    let isDirectory: Bool

    init(fileName: String, exists: Bool, byteCount: Int64? = nil, isDirectory: Bool = false) {
        self.fileName = fileName
        self.exists = exists
        self.byteCount = byteCount
        self.isDirectory = isDirectory
    }
}

struct ArtifactValidationResult: Equatable, Sendable {
    let availability: ArtifactAvailability
    let fileStatuses: [ArtifactFileStatus]
    let expectedSHA256: String
    let observedSHA256: String?
    let hasConcreteExpectedHash: Bool
    let hasVerifiedHash: Bool
    let networkDownloadAllowed: Bool

    var missingFiles: [String] {
        fileStatuses.filter { $0.exists == false }.map(\.fileName)
    }

    var presentFiles: [String] {
        fileStatuses.filter(\.exists).map(\.fileName)
    }

    var hasRequiredFiles: Bool {
        missingFiles.isEmpty
    }

    var canRunRealWeights: Bool {
        availability == .verified
    }

    var summary: String {
        switch availability {
        case .missing:
            return "缺少 \(missingFiles.joined(separator: ", "))"
        case .staged:
            return hasConcreteExpectedHash ? "本地文件待哈希校验" : "权重已放入占位区，等待登记官方 SHA-256"
        case .verified:
            return "本地 Agent artifact 已校验"
        }
    }
}

struct LocalClawModel: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var family: String
    var parameterCount: String
    var quantization: String
    var contextLength: Int
    var sizeOnDisk: String
    var memoryFootprint: String
    var installState: ModelInstallState
    var summary: String
    var supportedTasks: [ClawCapabilityCategory]
    var artifactManifest: ModelArtifactManifest

    init(
        id: UUID = UUID(),
        name: String,
        family: String,
        parameterCount: String,
        quantization: String,
        contextLength: Int,
        sizeOnDisk: String,
        memoryFootprint: String,
        installState: ModelInstallState,
        summary: String,
        supportedTasks: [ClawCapabilityCategory],
        artifactManifest: ModelArtifactManifest
    ) {
        self.id = id
        self.name = name
        self.family = family
        self.parameterCount = parameterCount
        self.quantization = quantization
        self.contextLength = contextLength
        self.sizeOnDisk = sizeOnDisk
        self.memoryFootprint = memoryFootprint
        self.installState = installState
        self.summary = summary
        self.supportedTasks = supportedTasks
        self.artifactManifest = artifactManifest
    }
}

struct ClawSkill: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var subtitle: String
    var category: ClawCapabilityCategory
    var promptTemplate: String
    var icon: String
    var popularity: Int
    var runCount: Int
    var recommendedInputs: [String]

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        category: ClawCapabilityCategory,
        promptTemplate: String,
        icon: String,
        popularity: Int,
        runCount: Int,
        recommendedInputs: [String]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.promptTemplate = promptTemplate
        self.icon = icon
        self.popularity = popularity
        self.runCount = runCount
        self.recommendedInputs = recommendedInputs
    }
}

enum AutomationChannel: String, CaseIterable, Identifiable, Sendable {
    case urlScheme
    case universalLink
    case shareSheet
    case appIntent
    case clawGateway

    var id: String { rawValue }

    var title: String {
        switch self {
        case .urlScheme:
            return "URL Scheme"
        case .universalLink:
            return "Universal Link"
        case .shareSheet:
            return "Share Sheet"
        case .appIntent:
            return "App Intents"
        case .clawGateway:
            return "Claw 网关"
        }
    }

    var icon: String {
        switch self {
        case .urlScheme:
            return "link"
        case .universalLink:
            return "safari.fill"
        case .shareSheet:
            return "square.and.arrow.up"
        case .appIntent:
            return "wand.and.sparkles"
        case .clawGateway:
            return "network"
        }
    }
}

struct AutomationTarget: Identifiable, Equatable, Sendable {
    let id: UUID
    var appName: String
    var channel: AutomationChannel
    var actionTitle: String
    var endpoint: String
    var payloadPreview: String
    var requiresUserConfirmation: Bool
    var isConfigured: Bool
    var limitation: String

    init(
        id: UUID = UUID(),
        appName: String,
        channel: AutomationChannel,
        actionTitle: String,
        endpoint: String,
        payloadPreview: String,
        requiresUserConfirmation: Bool,
        isConfigured: Bool,
        limitation: String
    ) {
        self.id = id
        self.appName = appName
        self.channel = channel
        self.actionTitle = actionTitle
        self.endpoint = endpoint
        self.payloadPreview = payloadPreview
        self.requiresUserConfirmation = requiresUserConfirmation
        self.isConfigured = isConfigured
        self.limitation = limitation
    }
}

enum PhoneAgentSurface: String, CaseIterable, Codable, Identifiable, Sendable {
    case clawRuntime
    case appIntents
    case shortcuts
    case siriKit
    case systemFramework
    case composeController
    case urlScheme
    case universalLink
    case backgroundTask
    case clawGateway
    case unavailable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clawRuntime:
            return "Claw Runtime"
        case .appIntents:
            return "App Intents"
        case .shortcuts:
            return "Shortcuts"
        case .siriKit:
            return "SiriKit"
        case .systemFramework:
            return "系统框架"
        case .composeController:
            return "Compose UI"
        case .urlScheme:
            return "URL Scheme"
        case .universalLink:
            return "Universal Link"
        case .backgroundTask:
            return "BackgroundTasks"
        case .clawGateway:
            return "Claw Gateway"
        case .unavailable:
            return "不可用"
        }
    }

    var icon: String {
        switch self {
        case .clawRuntime:
            return "brain.head.profile"
        case .appIntents:
            return "wand.and.sparkles"
        case .shortcuts:
            return "square.stack.3d.up.fill"
        case .siriKit:
            return "waveform.circle.fill"
        case .systemFramework:
            return "lock.shield.fill"
        case .composeController:
            return "square.and.pencil"
        case .urlScheme:
            return "link"
        case .universalLink:
            return "safari.fill"
        case .backgroundTask:
            return "clock.arrow.circlepath"
        case .clawGateway:
            return "network"
        case .unavailable:
            return "nosign"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "aiclawRuntime":
            self = .clawRuntime
        default:
            guard let value = PhoneAgentSurface(rawValue: rawValue) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown PhoneAgentSurface: \(rawValue)"
                )
            }
            self = value
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum PhoneAgentRunMode: String, CaseIterable, Identifiable, Sendable {
    case automaticInsideApp
    case automaticWithPermission
    case needsUserConfirmation
    case shortcutOrSiri
    case gatewayOnly
    case blockedByIOS

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automaticInsideApp:
            return "App 内自动"
        case .automaticWithPermission:
            return "授权后自动"
        case .needsUserConfirmation:
            return "发送前确认"
        case .shortcutOrSiri:
            return "Siri/快捷指令"
        case .gatewayOnly:
            return "仅网关"
        case .blockedByIOS:
            return "iOS 禁止"
        }
    }

    var isExecutableOnDevice: Bool {
        switch self {
        case .automaticInsideApp, .automaticWithPermission, .needsUserConfirmation, .shortcutOrSiri:
            return true
        case .gatewayOnly, .blockedByIOS:
            return false
        }
    }
}

enum PhoneAgentPermissionState: String, CaseIterable, Identifiable, Sendable {
    case notRequested
    case needsUserGrant
    case configured
    case limited
    case unavailable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notRequested:
            return "未请求"
        case .needsUserGrant:
            return "需授权"
        case .configured:
            return "已配置"
        case .limited:
            return "受限"
        case .unavailable:
            return "不可用"
        }
    }
}

struct PhoneAgentCapability: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var summary: String
    var permissionName: String
    var framework: String
    var surface: PhoneAgentSurface
    var permissionState: PhoneAgentPermissionState
    var runMode: PhoneAgentRunMode
    var canRead: Bool
    var canWrite: Bool
    var examples: [String]
    var limitation: String
    var appleReference: String

    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        permissionName: String,
        framework: String,
        surface: PhoneAgentSurface,
        permissionState: PhoneAgentPermissionState,
        runMode: PhoneAgentRunMode,
        canRead: Bool,
        canWrite: Bool,
        examples: [String],
        limitation: String,
        appleReference: String
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.permissionName = permissionName
        self.framework = framework
        self.surface = surface
        self.permissionState = permissionState
        self.runMode = runMode
        self.canRead = canRead
        self.canWrite = canWrite
        self.examples = examples
        self.limitation = limitation
        self.appleReference = appleReference
    }
}

struct PhoneAgentStep: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var instruction: String
    var target: String
    var surface: PhoneAgentSurface
    var runMode: PhoneAgentRunMode
    var requiresUserConfirmation: Bool
    var isAllowedOnIOS: Bool
    var rationale: String

    init(
        id: UUID = UUID(),
        title: String,
        instruction: String,
        target: String,
        surface: PhoneAgentSurface,
        runMode: PhoneAgentRunMode,
        requiresUserConfirmation: Bool,
        isAllowedOnIOS: Bool,
        rationale: String
    ) {
        self.id = id
        self.title = title
        self.instruction = instruction
        self.target = target
        self.surface = surface
        self.runMode = runMode
        self.requiresUserConfirmation = requiresUserConfirmation
        self.isAllowedOnIOS = isAllowedOnIOS
        self.rationale = rationale
    }
}

struct PhoneAgentPlan: Identifiable, Equatable, Sendable {
    let id: UUID
    var command: String
    var summary: String
    var steps: [PhoneAgentStep]
    var blockedNotes: [String]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        command: String,
        summary: String,
        steps: [PhoneAgentStep],
        blockedNotes: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.command = command
        self.summary = summary
        self.steps = steps
        self.blockedNotes = blockedNotes
        self.createdAt = createdAt
    }

    var confirmationCount: Int {
        steps.filter(\.requiresUserConfirmation).count
    }

    var blockedCount: Int {
        steps.filter { $0.isAllowedOnIOS == false }.count + blockedNotes.count
    }

    var executableStepCount: Int {
        steps.filter { $0.isAllowedOnIOS && $0.runMode.isExecutableOnDevice }.count
    }
}

enum ClawMobileActionKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case analyzeLocalContext
    case requestPermission
    case runAgentLoop
    case observeScreen
    case controlBrowser
    case operateDesktopApp
    case manageFiles
    case runShellCommand
    case extractData
    case readContacts
    case composeMessage
    case composeEmail
    case createReminder
    case scheduleNotification
    case openExternalURL
    case runShortcut
    case speechCapture
    case backgroundRefresh
    case desktopHandoff
    case auditLog
    case blockedUnsupported

    var id: String { rawValue }

    var title: String {
        switch self {
        case .analyzeLocalContext:
            return "本地规划"
        case .requestPermission:
            return "请求授权"
        case .runAgentLoop:
            return "电脑智能体循环"
        case .observeScreen:
            return "观察屏幕"
        case .controlBrowser:
            return "控制浏览器"
        case .operateDesktopApp:
            return "操作桌面 App"
        case .manageFiles:
            return "文件操作"
        case .runShellCommand:
            return "Shell 命令"
        case .extractData:
            return "提取数据"
        case .readContacts:
            return "读取联系人"
        case .composeMessage:
            return "短信/IM 草稿"
        case .composeEmail:
            return "邮件草稿"
        case .createReminder:
            return "创建提醒"
        case .scheduleNotification:
            return "本地通知"
        case .openExternalURL:
            return "打开链接"
        case .runShortcut:
            return "运行快捷指令"
        case .speechCapture:
            return "语音输入"
        case .backgroundRefresh:
            return "后台刷新"
        case .desktopHandoff:
            return "桌面接管"
        case .auditLog:
            return "审计记录"
        case .blockedUnsupported:
            return "禁止动作"
        }
    }

    var icon: String {
        switch self {
        case .analyzeLocalContext:
            return "brain.head.profile"
        case .requestPermission:
            return "person.badge.key.fill"
        case .runAgentLoop:
            return "point.topleft.down.curvedto.point.bottomright.up"
        case .observeScreen:
            return "eye.fill"
        case .controlBrowser:
            return "safari.fill"
        case .operateDesktopApp:
            return "macwindow.on.rectangle"
        case .manageFiles:
            return "folder.fill"
        case .runShellCommand:
            return "terminal.fill"
        case .extractData:
            return "tablecells.fill"
        case .readContacts:
            return "person.crop.circle.badge.checkmark"
        case .composeMessage:
            return "message.fill"
        case .composeEmail:
            return "envelope.fill"
        case .createReminder:
            return "checklist.checked"
        case .scheduleNotification:
            return "bell.badge.fill"
        case .openExternalURL:
            return "link"
        case .runShortcut:
            return "square.stack.3d.up.fill"
        case .speechCapture:
            return "waveform"
        case .backgroundRefresh:
            return "clock.arrow.circlepath"
        case .desktopHandoff:
            return "display.and.arrow.down"
        case .auditLog:
            return "doc.badge.gearshape"
        case .blockedUnsupported:
            return "nosign"
        }
    }
}

enum ClawApprovalLevel: String, CaseIterable, Codable, Identifiable, Sendable {
    case automatic
    case userConfirmation
    case gatewayApproval
    case blocked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            return "自动"
        case .userConfirmation:
            return "用户确认"
        case .gatewayApproval:
            return "网关确认"
        case .blocked:
            return "已阻断"
        }
    }
}

enum ClawTaskStatus: String, CaseIterable, Codable, Identifiable, Sendable {
    case queued
    case waitingForApproval
    case readyToSend
    case sent
    case blocked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .queued:
            return "已排队"
        case .waitingForApproval:
            return "待审批"
        case .readyToSend:
            return "可发送"
        case .sent:
            return "已发送"
        case .blocked:
            return "已阻断"
        }
    }
}

enum ClawGatewaySecurityMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case localNetworkToken
    case manualPairing
    case mutualApproval

    var id: String { rawValue }

    var title: String {
        switch self {
        case .localNetworkToken:
            return "局域网 Token"
        case .manualPairing:
            return "手动配对"
        case .mutualApproval:
            return "双端确认"
        }
    }
}

struct ClawGatewayProfile: Equatable, Codable, Sendable {
    var endpoint: String
    var deviceName: String
    var securityMode: ClawGatewaySecurityMode
    var tokenFingerprint: String
    var allowedActionKinds: [ClawMobileActionKind]
    var requiresApprovalForSensitiveData: Bool
    var auditEnabled: Bool

    var isConfigured: Bool {
        endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}

struct ClawMobileAction: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var kind: ClawMobileActionKind
    var title: String
    var target: String
    var instruction: String
    var approval: ClawApprovalLevel
    var sourceSurface: PhoneAgentSurface
    var handlesSensitiveData: Bool
    var inputPreview: String
    var toolArguments: [String: String]

    init(
        id: UUID = UUID(),
        kind: ClawMobileActionKind,
        title: String,
        target: String,
        instruction: String,
        approval: ClawApprovalLevel,
        sourceSurface: PhoneAgentSurface,
        handlesSensitiveData: Bool,
        inputPreview: String,
        toolArguments: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.target = target
        self.instruction = instruction
        self.approval = approval
        self.sourceSurface = sourceSurface
        self.handlesSensitiveData = handlesSensitiveData
        self.inputPreview = inputPreview
        self.toolArguments = toolArguments
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case title
        case target
        case instruction
        case approval
        case sourceSurface
        case handlesSensitiveData
        case inputPreview
        case toolArguments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.kind = try container.decode(ClawMobileActionKind.self, forKey: .kind)
        self.title = try container.decode(String.self, forKey: .title)
        self.target = try container.decode(String.self, forKey: .target)
        self.instruction = try container.decode(String.self, forKey: .instruction)
        self.approval = try container.decode(ClawApprovalLevel.self, forKey: .approval)
        self.sourceSurface = try container.decode(PhoneAgentSurface.self, forKey: .sourceSurface)
        self.handlesSensitiveData = try container.decode(Bool.self, forKey: .handlesSensitiveData)
        self.inputPreview = try container.decode(String.self, forKey: .inputPreview)
        self.toolArguments = try container.decodeIfPresent([String: String].self, forKey: .toolArguments) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encode(target, forKey: .target)
        try container.encode(instruction, forKey: .instruction)
        try container.encode(approval, forKey: .approval)
        try container.encode(sourceSurface, forKey: .sourceSurface)
        try container.encode(handlesSensitiveData, forKey: .handlesSensitiveData)
        try container.encode(inputPreview, forKey: .inputPreview)
        try container.encode(toolArguments, forKey: .toolArguments)
    }
}

struct ClawMobileTask: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var command: String
    var summary: String
    var sourceDevice: String
    var destinationGateway: String
    var actions: [ClawMobileAction]
    var status: ClawTaskStatus
    var riskScore: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        command: String,
        summary: String,
        sourceDevice: String,
        destinationGateway: String,
        actions: [ClawMobileAction],
        status: ClawTaskStatus,
        riskScore: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.command = command
        self.summary = summary
        self.sourceDevice = sourceDevice
        self.destinationGateway = destinationGateway
        self.actions = actions
        self.status = status
        self.riskScore = min(max(riskScore, 0), 100)
        self.createdAt = createdAt
    }

    var approvalCount: Int {
        actions.filter { $0.approval == .userConfirmation || $0.approval == .gatewayApproval }.count
    }

    var blockedCount: Int {
        actions.filter { $0.approval == .blocked }.count
    }

    var sensitiveActionCount: Int {
        actions.filter(\.handlesSensitiveData).count
    }
}

struct ClawMobileEnvelope: Equatable, Codable, Sendable {
    var schemaVersion: String
    var sourceApp: String
    var task: ClawMobileTask
    var gateway: ClawGatewayProfile
    var approvalSummary: String
    var auditRequired: Bool
}

enum ClawGatewaySessionStatus: String, CaseIterable, Codable, Identifiable, Sendable {
    case prepared
    case running
    case completed
    case needsAttention
    case blocked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .prepared:
            return "已准备"
        case .running:
            return "执行中"
        case .completed:
            return "已完成"
        case .needsAttention:
            return "需处理"
        case .blocked:
            return "已阻断"
        }
    }
}

enum ClawGatewayActionResultStatus: String, CaseIterable, Codable, Identifiable, Sendable {
    case pending
    case running
    case succeeded
    case failed
    case skipped
    case waitingForApproval

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending:
            return "待执行"
        case .running:
            return "执行中"
        case .succeeded:
            return "成功"
        case .failed:
            return "失败"
        case .skipped:
            return "跳过"
        case .waitingForApproval:
            return "待确认"
        }
    }
}

enum ClawGatewayArtifactKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case screenshot
    case accessibilityTree
    case commandOutput
    case fileDiff
    case browserTrace
    case agentTrace
    case messageDraft
    case auditLog

    var id: String { rawValue }

    var title: String {
        switch self {
        case .screenshot:
            return "截图"
        case .accessibilityTree:
            return "控件树"
        case .commandOutput:
            return "命令输出"
        case .fileDiff:
            return "文件变更"
        case .browserTrace:
            return "浏览轨迹"
        case .agentTrace:
            return "智能体轨迹"
        case .messageDraft:
            return "消息草稿"
        case .auditLog:
            return "审计"
        }
    }
}

struct ClawGatewayArtifact: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var kind: ClawGatewayArtifactKind
    var title: String
    var reference: String
    var isRedacted: Bool
    var metadata: [String: String]?

    init(
        id: UUID = UUID(),
        kind: ClawGatewayArtifactKind,
        title: String,
        reference: String,
        isRedacted: Bool,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.reference = reference
        self.isRedacted = isRedacted
        self.metadata = metadata
    }
}

struct ClawGatewayActionResult: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var actionID: UUID
    var actionKind: ClawMobileActionKind
    var actionTitle: String
    var status: ClawGatewayActionResultStatus
    var summary: String
    var artifacts: [ClawGatewayArtifact]
    var isRetryable: Bool
    var retryCount: Int
    var startedAt: Date
    var finishedAt: Date?

    init(
        id: UUID = UUID(),
        actionID: UUID,
        actionKind: ClawMobileActionKind,
        actionTitle: String,
        status: ClawGatewayActionResultStatus,
        summary: String,
        artifacts: [ClawGatewayArtifact] = [],
        isRetryable: Bool = false,
        retryCount: Int = 0,
        startedAt: Date = Date(),
        finishedAt: Date? = Date()
    ) {
        self.id = id
        self.actionID = actionID
        self.actionKind = actionKind
        self.actionTitle = actionTitle
        self.status = status
        self.summary = summary
        self.artifacts = artifacts
        self.isRetryable = isRetryable
        self.retryCount = retryCount
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }
}

struct ClawGatewaySession: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var taskID: UUID
    var command: String
    var channel: String
    var workspace: String
    var status: ClawGatewaySessionStatus
    var results: [ClawGatewayActionResult]
    var sessionArtifacts: [ClawGatewayArtifact]
    var auditTrail: [String]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        taskID: UUID,
        command: String,
        channel: String,
        workspace: String,
        status: ClawGatewaySessionStatus,
        results: [ClawGatewayActionResult],
        sessionArtifacts: [ClawGatewayArtifact] = [],
        auditTrail: [String],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.taskID = taskID
        self.command = command
        self.channel = channel
        self.workspace = workspace
        self.status = status
        self.results = results
        self.sessionArtifacts = sessionArtifacts
        self.auditTrail = auditTrail
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case taskID
        case command
        case channel
        case workspace
        case status
        case results
        case sessionArtifacts
        case auditTrail
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        taskID = try container.decode(UUID.self, forKey: .taskID)
        command = try container.decode(String.self, forKey: .command)
        channel = try container.decode(String.self, forKey: .channel)
        workspace = try container.decode(String.self, forKey: .workspace)
        status = try container.decode(ClawGatewaySessionStatus.self, forKey: .status)
        results = try container.decode([ClawGatewayActionResult].self, forKey: .results)
        sessionArtifacts = try container.decodeIfPresent([ClawGatewayArtifact].self, forKey: .sessionArtifacts) ?? []
        auditTrail = try container.decode([String].self, forKey: .auditTrail)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(taskID, forKey: .taskID)
        try container.encode(command, forKey: .command)
        try container.encode(channel, forKey: .channel)
        try container.encode(workspace, forKey: .workspace)
        try container.encode(status, forKey: .status)
        try container.encode(results, forKey: .results)
        try container.encode(sessionArtifacts, forKey: .sessionArtifacts)
        try container.encode(auditTrail, forKey: .auditTrail)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    var succeededCount: Int {
        results.filter { $0.status == .succeeded }.count
    }

    var failedCount: Int {
        results.filter { $0.status == .failed }.count
    }

    var retryableCount: Int {
        results.filter { $0.isRetryable }.count
    }

    var artifactCount: Int {
        allArtifacts.count
    }

    var allArtifacts: [ClawGatewayArtifact] {
        sessionArtifacts + results.flatMap(\.artifacts)
    }
}

enum ClawGatewayDispatchMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case simulatedEventStream
    case liveGateway

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simulatedEventStream:
            return "模拟事件流"
        case .liveGateway:
            return "Live Gateway"
        }
    }
}

enum ClawGatewayConnectionState: String, CaseIterable, Codable, Identifiable, Sendable {
    case idle
    case notConfigured
    case simulated
    case preparingLiveRequest
    case awaitingGateway
    case streaming
    case completed
    case fallbackSimulated
    case failed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .idle:
            return "空闲"
        case .notConfigured:
            return "未配置"
        case .simulated:
            return "模拟"
        case .preparingLiveRequest:
            return "准备连接"
        case .awaitingGateway:
            return "等待网关"
        case .streaming:
            return "事件同步"
        case .completed:
            return "已完成"
        case .fallbackSimulated:
            return "回退模拟"
        case .failed:
            return "连接失败"
        }
    }
}

enum ClawAutonomousLoopPhase: String, CaseIterable, Codable, Identifiable, Sendable {
    case idle
    case planning
    case waitingForUserApproval
    case dispatching
    case observingGateway
    case needsAttention
    case completed
    case blocked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .idle:
            return "空闲"
        case .planning:
            return "规划中"
        case .waitingForUserApproval:
            return "待审批"
        case .dispatching:
            return "发送中"
        case .observingGateway:
            return "观察网关"
        case .needsAttention:
            return "需处理"
        case .completed:
            return "已完成"
        case .blocked:
            return "已阻断"
        }
    }

    var icon: String {
        switch self {
        case .idle:
            return "pause.circle.fill"
        case .planning:
            return "list.bullet.rectangle.portrait.fill"
        case .waitingForUserApproval:
            return "checkmark.seal.fill"
        case .dispatching:
            return "paperplane.fill"
        case .observingGateway:
            return "waveform.path.ecg.rectangle.fill"
        case .needsAttention:
            return "exclamationmark.triangle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .blocked:
            return "nosign"
        }
    }
}

struct ClawAutonomousLoopState: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var phase: ClawAutonomousLoopPhase
    var runMode: ClawGatewayDispatchMode
    var iteration: Int
    var maxIterations: Int
    var command: String
    var statusLine: String
    var lastDecision: String
    var requiresUserApproval: Bool
    var taskID: UUID?
    var sessionID: UUID?
    var checkpoints: [String]
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        phase: ClawAutonomousLoopPhase,
        runMode: ClawGatewayDispatchMode,
        iteration: Int,
        maxIterations: Int,
        command: String,
        statusLine: String,
        lastDecision: String,
        requiresUserApproval: Bool,
        taskID: UUID? = nil,
        sessionID: UUID? = nil,
        checkpoints: [String] = [],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.phase = phase
        self.runMode = runMode
        self.iteration = iteration
        self.maxIterations = max(maxIterations, 1)
        self.command = command
        self.statusLine = statusLine
        self.lastDecision = lastDecision
        self.requiresUserApproval = requiresUserApproval
        self.taskID = taskID
        self.sessionID = sessionID
        self.checkpoints = checkpoints
        self.updatedAt = updatedAt
    }
}

enum ClawMissionRunPrimaryActionKind: String, Codable, Sendable {
    case start
    case approveAndContinue
    case continueAfterReview
    case waitForGateway
    case inspectBlocked
}

struct ClawMissionRunStage: Identifiable, Equatable, Codable, Sendable {
    var id: String { title }
    var title: String
    var icon: String
    var isComplete: Bool
    var isActive: Bool
    var isBlocked: Bool
}

enum ClawMissionRunReviewPrioritySeverity: String, Codable, Sendable {
    case critical
    case high
    case medium
    case low
    case info

    var title: String {
        switch self {
        case .critical:
            return "必须复核"
        case .high:
            return "高优先"
        case .medium:
            return "需复核"
        case .low:
            return "可检查"
        case .info:
            return "信息"
        }
    }
}

struct ClawMissionRunReviewPriorityItem: Identifiable, Equatable, Codable, Sendable {
    var id: String
    var rank: Int
    var severity: ClawMissionRunReviewPrioritySeverity
    var title: String
    var status: String
    var reason: String
    var icon: String
    var reviewKind: String
    var actionHint: String
    var isActionable: Bool
    var hasMetadata: Bool
}

struct ClawMissionRunApprovalQueueItem: Identifiable, Equatable, Codable, Sendable {
    var id: String
    var rank: Int
    var severity: ClawMissionRunReviewPrioritySeverity
    var title: String
    var status: String
    var reason: String
    var icon: String
    var reviewKind: String
    var actionKindTitle: String?
    var approvalTitle: String?
    var isActionable: Bool
    var hasMetadata: Bool
    var canFocusReview: Bool
    var isFocused: Bool
}

struct ClawMissionRunApprovalQueueSummary: Equatable, Codable, Sendable {
    var title: String
    var status: String
    var guidance: String
    var icon: String
    var totalCount: Int
    var actionableCount: Int
    var criticalOrHighCount: Int
    var metadataPendingCount: Int
    var focusedReviewKind: String?
    var focusedReviewTitle: String?
    var primaryReviewKind: String?
    var primaryReviewTitle: String?
    var canFocusPrimaryReview: Bool
    var requiresHumanAction: Bool
    var hasMetadataGap: Bool
    var isReviewable: Bool
    var items: [ClawMissionRunApprovalQueueItem]
}

struct ClawMissionRunPayloadSafetyLedgerItem: Identifiable, Equatable, Codable, Sendable {
    var id: String { reviewKind }
    var reviewKind: String
    var reviewTitle: String
    var status: String
    var guidance: String
    var icon: String
    var hasMetadata: Bool
    var payloadNotRead: Bool
    var metadataOnly: Bool
    var omissionSignalCount: Int
    var safetyFlags: [String]
    var canFocusReview: Bool
    var isFocused: Bool
}

struct ClawMissionRunPayloadSafetyLedgerSummary: Equatable, Codable, Sendable {
    var title: String
    var status: String
    var guidance: String
    var icon: String
    var totalCount: Int
    var payloadNotReadCount: Int
    var metadataOnlyCount: Int
    var omissionSignalCount: Int
    var metadataPendingCount: Int
    var focusedReviewKind: String?
    var focusedReviewTitle: String?
    var primaryReviewKind: String?
    var primaryReviewTitle: String?
    var canFocusPrimaryReview: Bool
    var hasMetadataGap: Bool
    var isReviewable: Bool
    var items: [ClawMissionRunPayloadSafetyLedgerItem]
}

struct ClawMissionRunMacAgentReadinessItem: Identifiable, Equatable, Codable, Sendable {
    var id: String
    var title: String
    var status: String
    var guidance: String
    var icon: String
    var tone: ClawMissionRunOperatorLaneTone
    var reviewKind: String?
    var reviewTitle: String?
    var canFocusReview: Bool
    var isFocused: Bool
    var isReady: Bool
    var isBlocked: Bool
    var hasMetadataGap: Bool
    var requiresHumanAction: Bool
}

struct ClawMissionRunMacAgentReadinessBoard: Equatable, Codable, Sendable {
    var title: String
    var status: String
    var guidance: String
    var icon: String
    var readyCount: Int
    var blockedCount: Int
    var metadataPendingCount: Int
    var humanActionCount: Int
    var focusedItemID: String?
    var focusedReviewKind: String?
    var focusedReviewTitle: String?
    var primaryReviewKind: String?
    var primaryReviewTitle: String?
    var canFocusPrimaryReview: Bool
    var canContinueLoop: Bool
    var requiresHumanAction: Bool
    var hasMetadataGap: Bool
    var isReviewable: Bool
    var items: [ClawMissionRunMacAgentReadinessItem]
}

struct ClawMissionRunActionPreflightItem: Identifiable, Equatable, Codable, Sendable {
    var id: String
    var rank: Int
    var title: String
    var actionKindTitle: String
    var approvalTitle: String
    var status: String
    var guidance: String
    var icon: String
    var tone: ClawMissionRunOperatorLaneTone
    var reviewKind: String?
    var reviewTitle: String?
    var canFocusReview: Bool
    var isFocused: Bool
    var hasStructuredArguments: Bool
    var hasResult: Bool
    var hasMetadata: Bool
    var isReady: Bool
    var isBlocked: Bool
    var isDegraded: Bool
    var requiresHumanAction: Bool
    var isRetryable: Bool
}

struct ClawMissionRunActionPreflightMatrix: Equatable, Codable, Sendable {
    var title: String
    var status: String
    var guidance: String
    var icon: String
    var totalCount: Int
    var readyCount: Int
    var blockedCount: Int
    var degradedCount: Int
    var humanActionCount: Int
    var metadataPendingCount: Int
    var focusedItemID: String?
    var focusedReviewKind: String?
    var focusedReviewTitle: String?
    var primaryReviewKind: String?
    var primaryReviewTitle: String?
    var canFocusPrimaryReview: Bool
    var requiresHumanAction: Bool
    var hasMetadataGap: Bool
    var isReviewable: Bool
    var items: [ClawMissionRunActionPreflightItem]
}

struct ClawMissionRunEvidenceCoverageItem: Identifiable, Equatable, Codable, Sendable {
    var id: String { reviewKind }
    var reviewKind: String
    var reviewTitle: String
    var status: String
    var guidance: String
    var icon: String
    var tone: ClawMissionRunOperatorLaneTone
    var actionCount: Int
    var hasActionSupport: Bool
    var hasEvidence: Bool
    var hasMetadata: Bool
    var payloadProtected: Bool
    var requiresHumanAction: Bool
    var hasMetadataGap: Bool
    var canFocusReview: Bool
    var isFocused: Bool
}

struct ClawMissionRunEvidenceCoverageMap: Equatable, Codable, Sendable {
    var title: String
    var status: String
    var guidance: String
    var icon: String
    var totalCount: Int
    var actionSupportedCount: Int
    var evidenceCoveredCount: Int
    var metadataReadyCount: Int
    var payloadProtectedCount: Int
    var humanActionCount: Int
    var metadataPendingCount: Int
    var focusedReviewKind: String?
    var focusedReviewTitle: String?
    var primaryReviewKind: String?
    var primaryReviewTitle: String?
    var canFocusPrimaryReview: Bool
    var requiresHumanAction: Bool
    var hasMetadataGap: Bool
    var isReviewable: Bool
    var items: [ClawMissionRunEvidenceCoverageItem]
}

struct ClawMissionRunReviewReadinessSummary: Equatable, Codable, Sendable {
    var title: String
    var status: String
    var guidance: String
    var icon: String
    var totalPriorityCount: Int
    var actionablePriorityCount: Int
    var criticalOrHighCount: Int
    var metadataPendingCount: Int
    var availableDetailReviewCount: Int
    var topReviewKind: String?
    var topReviewTitle: String?
    var topActionHint: String?
    var focusedReviewKind: String?
    var focusedReviewTitle: String?
    var focusedHasDetailReview: Bool
    var isReviewable: Bool
    var requiresHumanAction: Bool
}

struct ClawMissionRunNextReviewAction: Equatable, Codable, Sendable {
    var title: String
    var status: String
    var guidance: String
    var icon: String
    var reviewKind: String?
    var reviewTitle: String?
    var actionHint: String?
    var primaryButtonTitle: String?
    var canFocusDetailReview: Bool
    var requiresHumanAction: Bool
    var hasMetadataGap: Bool
    var isReviewable: Bool
}

struct ClawMissionRunFocusContextSummary: Equatable, Codable, Sendable {
    var title: String
    var status: String
    var guidance: String
    var icon: String
    var focusedReviewKind: String?
    var focusedReviewTitle: String?
    var primaryReviewKind: String?
    var primaryButtonTitle: String?
    var canFocusDetailReview: Bool
    var canClearFocus: Bool
    var hasEvidence: Bool
    var hasMetadataGap: Bool
    var requiresHumanAction: Bool
    var isReviewable: Bool
}

struct ClawMissionRunReviewDetailDockSummary: Equatable, Codable, Sendable {
    var title: String
    var status: String
    var guidance: String
    var icon: String
    var requestedReviewKind: String?
    var activeReviewKind: String?
    var activeReviewTitle: String?
    var detailReviewKinds: [String]
    var showsFocusedDetailOnly: Bool
    var canClearFocus: Bool
    var hasStaleFocus: Bool
    var isReviewable: Bool
}

struct ClawMissionRunArtifactEvidenceItem: Identifiable, Equatable, Codable, Sendable {
    var id: String { reviewKind }
    var reviewKind: String
    var reviewTitle: String
    var status: String
    var guidance: String
    var icon: String
    var artifactKinds: [ClawGatewayArtifactKind]
    var hasEvidence: Bool
    var metadataReady: Bool
    var isFocused: Bool
    var canFocusReview: Bool
}

struct ClawMissionRunArtifactEvidenceIndex: Equatable, Codable, Sendable {
    var title: String
    var status: String
    var guidance: String
    var icon: String
    var artifactKindCount: Int
    var metadataArtifactCount: Int
    var redactedArtifactCount: Int
    var coveredReviewCount: Int
    var missingReviewCount: Int
    var focusedReviewKind: String?
    var focusedReviewTitle: String?
    var focusedHasEvidence: Bool
    var isReviewable: Bool
    var items: [ClawMissionRunArtifactEvidenceItem]
}

struct ClawMissionRunEvidenceTrailStep: Identifiable, Equatable, Codable, Sendable {
    var id: String
    var title: String
    var status: String
    var guidance: String
    var icon: String
    var tone: ClawMissionRunOperatorLaneTone
    var reviewKind: String?
    var reviewTitle: String?
    var canFocusReview: Bool
    var isFocused: Bool
}

struct ClawMissionRunEvidenceTrailSummary: Equatable, Codable, Sendable {
    var title: String
    var status: String
    var guidance: String
    var icon: String
    var focusedReviewKind: String?
    var focusedReviewTitle: String?
    var coveredReviewCount: Int
    var totalReviewCount: Int
    var metadataPendingCount: Int
    var actionablePriorityCount: Int
    var primaryReviewKind: String?
    var primaryReviewTitle: String?
    var canFocusPrimaryReview: Bool
    var requiresHumanAction: Bool
    var hasMetadataGap: Bool
    var isReviewable: Bool
    var steps: [ClawMissionRunEvidenceTrailStep]
}

enum ClawMissionRunOperatorLaneTone: String, Codable, Sendable {
    case neutral
    case info
    case success
    case warning
    case danger
}

struct ClawMissionRunOperatorLane: Identifiable, Equatable, Codable, Sendable {
    var id: String
    var title: String
    var status: String
    var guidance: String
    var icon: String
    var tone: ClawMissionRunOperatorLaneTone
    var reviewKind: String?
    var canFocusReview: Bool
    var isFocused: Bool
}

struct ClawMissionRunOperatorStrip: Equatable, Codable, Sendable {
    var title: String
    var status: String
    var focusedReviewKind: String?
    var lanes: [ClawMissionRunOperatorLane]
}

struct ClawMissionRunLoopContinuationSummary: Equatable, Codable, Sendable {
    var title: String
    var status: String
    var guidance: String
    var icon: String
    var handoffStatus: String?
    var readinessScore: Int?
    var satisfiedSignalCount: Int
    var degradedSignalCount: Int
    var missingSignalCount: Int
    var selectedNextActionKind: String?
    var selectedNextActionRequiresApproval: Bool
    var focusReviewKind: String?
    var focusReviewTitle: String?
    var canFocusAgentTrace: Bool
    var canContinueLoop: Bool
    var requiresHumanAction: Bool
    var hasMetadataGap: Bool
    var isReviewable: Bool
}

private enum ClawArtifactMetadataParser {
    static func cleanValue(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty || trimmed == "none" ? nil : trimmed
    }

    static func intValue(_ value: String?) -> Int? {
        guard let clean = cleanValue(value) else {
            return nil
        }
        return Int(clean)
    }

    static func boolValue(_ value: String?) -> Bool? {
        guard let clean = cleanValue(value)?.lowercased() else {
            return nil
        }
        switch clean {
        case "true", "yes", "1":
            return true
        case "false", "no", "0":
            return false
        default:
            return nil
        }
    }

    static func listValue(_ value: String?) -> [String] {
        guard let clean = cleanValue(value) else {
            return []
        }
        return clean
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false && $0 != "none" }
    }
}

private enum ClawArtifactMetadataDisplaySanitizer {
    static func safeValue(_ value: String?) -> String? {
        guard let clean = ClawArtifactMetadataParser.cleanValue(value) else {
            return nil
        }
        var redacted = ClawSensitiveTextRedactor.redacted(clean)
        let replacements: [(String, String)] = [
            (#"(?i)\bAuthorization=<redacted>"#, "header-redacted"),
            (#"(?i)\bBearer <redacted>"#, "token-redacted"),
            (#"(?i)\b(token|password|secret)=<redacted>"#, "secret-redacted"),
            (#"(?i)\bheaders=<redacted>"#, "headers-redacted"),
            (#"(?i)\bworkspace=<redacted>"#, "workspace-redacted"),
            (#"(?i)\btoolArguments\b"#, "structured-arguments-redacted"),
            (#"file://<redacted>"#, "file-redacted"),
            (#"https?://\S+"#, "url-redacted"),
            (#"<path-redacted>"#, "path-redacted")
        ]
        for (pattern, replacement) in replacements {
            redacted = redacted.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .regularExpression
            )
        }
        return ClawArtifactMetadataParser.cleanValue(redacted)
    }

    static func safeList(_ value: String?) -> [String] {
        ClawArtifactMetadataParser.listValue(value).compactMap(safeValue)
    }
}

struct ClawArtifactMetadataPair: Equatable, Codable, Sendable {
    var key: String
    var value: String
}

struct ClawGatewayArtifactMetadataReviewSummary: Equatable, Codable, Sendable {
    var artifactCount: Int
    var metadataArtifactCount: Int
    var redactedArtifactCount: Int
    var latestKind: ClawGatewayArtifactKind
    var latestTitle: String
    var latestMetadataKind: ClawGatewayArtifactKind?
    var latestMetadataTitle: String?
    var hasMetadata: Bool
    var safeMetadataPairs: [ClawArtifactMetadataPair]
    var safetyFlags: [String]
    var isLatestRedacted: Bool

    var compactStatus: String {
        guard hasMetadata else {
            return "已收到 \(latestKind.title) artifact，metadata 待同步。"
        }
        let coverage = "metadata \(metadataArtifactCount)/\(artifactCount)"
        let redacted = "redacted \(redactedArtifactCount)/\(artifactCount)"
        let metadataSource = latestMetadataKind.map { "\($0.title) \(latestMetadataTitle ?? $0.title)" } ?? "\(latestKind.title) \(latestTitle)"
        let latest = "\(latestKind.title) \(latestTitle)"
        return "\(coverage) · \(redacted) · \(latest) · metadata \(metadataSource)"
    }

    static func latest(from session: ClawGatewaySession?) -> ClawGatewayArtifactMetadataReviewSummary? {
        guard let session else {
            return nil
        }
        return latest(from: session.allArtifacts)
    }

    static func latest(from artifacts: [ClawGatewayArtifact]) -> ClawGatewayArtifactMetadataReviewSummary? {
        guard let latest = artifacts.last else {
            return nil
        }
        let metadataSource = artifacts.last { $0.metadata?.isEmpty == false } ?? latest
        let metadata = metadataSource.metadata ?? [:]
        let isFileChangeSafetyMetadata = metadata.keys.contains {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "filechangereview"
        }
        return ClawGatewayArtifactMetadataReviewSummary(
            artifactCount: artifacts.count,
            metadataArtifactCount: artifacts.filter { ($0.metadata?.isEmpty == false) }.count,
            redactedArtifactCount: artifacts.filter(\.isRedacted).count,
            latestKind: latest.kind,
            latestTitle: ClawArtifactMetadataDisplaySanitizer.safeValue(latest.title) ?? latest.kind.title,
            latestMetadataKind: metadata.isEmpty ? nil : metadataSource.kind,
            latestMetadataTitle: metadata.isEmpty ? nil : ClawArtifactMetadataDisplaySanitizer.safeValue(metadataSource.title) ?? metadataSource.kind.title,
            hasMetadata: metadata.isEmpty == false,
            safeMetadataPairs: isFileChangeSafetyMetadata ? [] : safeMetadataPairs(from: metadata),
            safetyFlags: isFileChangeSafetyMetadata ? [] : ClawArtifactMetadataDisplaySanitizer.safeList(metadata["safetyFlags"]),
            isLatestRedacted: latest.isRedacted
        )
    }

    private static func safeMetadataPairs(from metadata: [String: String]) -> [ClawArtifactMetadataPair] {
        metadata.keys.sorted().compactMap { key in
            guard let pair = safeMetadataPair(key: key, value: metadata[key]) else {
                return nil
            }
            return pair
        }
    }

    private static func safeMetadataPair(key: String, value: String?) -> ClawArtifactMetadataPair? {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanKey.isEmpty == false else {
            return nil
        }
        let lowered = cleanKey.lowercased()
        guard let safeKey = allowedMetadataKey(lowered) else {
            return nil
        }
        if lowered == "safetyflags" {
            return nil
        }
        guard let safeValue = ClawArtifactMetadataDisplaySanitizer.safeValue(value) else {
            return nil
        }
        return ClawArtifactMetadataPair(key: safeKey, value: safeValue)
    }

    private static func allowedMetadataKey(_ lowered: String) -> String? {
        let keys: [String: String] = [
            "accessibilitytree": "accessibilityTree",
            "accessibilitypolicy": "accessibilityPolicy",
            "actioncount": "actionCount",
            "actionkinds": "actionKinds",
            "allowedactionkinds": "allowedActionKinds",
            "browsercontrolstate": "browserControlState",
            "browsernetworkstate": "browserNetworkState",
            "browsertracecount": "browserTraceCount",
            "candidatecontrolcount": "candidateControlCount",
            "commandoutputcount": "commandOutputCount",
            "completenessstatus": "completenessStatus",
            "decision": "decision",
            "desktopcontrolstate": "desktopControlState",
            "deliveryreview": "deliveryReview",
            "digestmatchesfirst": "digestMatchesFirst",
            "actionkind": "actionKind",
            "targetkind": "targetKind",
            "finalsubmitrequiresapproval": "finalSubmitRequiresApproval",
            "userapprovalrequired": "userApprovalRequired",
            "draftbodyomitted": "draftBodyOmitted",
            "pastetextomitted": "pasteTextOmitted",
            "submitblocked": "submitBlocked",
            "allowedkeycount": "allowedKeyCount",
            "blockedkeycount": "blockedKeyCount",
            "blockedsubmitkeycount": "blockedSubmitKeyCount",
            "browserreview": "browserReview",
            "browsercontrolpolicy": "browserControlPolicy",
            "browsercontrolrequested": "browserControlRequested",
            "openinbrowser": "openInBrowser",
            "targeturlpresent": "targetURLPresent",
            "searchquerypresent": "searchQueryPresent",
            "localhtmlinput": "localHTMLInput",
            "networkfetchattempted": "networkFetchAttempted",
            "networkblocked": "networkBlocked",
            "appallowlistenforced": "appAllowlistEnforced",
            "hostallowlistenforced": "hostAllowlistEnforced",
            "executed": "executed",
            "timedout": "timedOut",
            "resultstatus": "resultStatus",
            "extractionreview": "extractionReview",
            "filediffcount": "fileDiffCount",
            "firstsessionid": "firstSessionID",
            "includeaccessibilitytree": "includeAccessibilityTree",
            "maxcandidatecontrols": "maxCandidateControls",
            "messagedraftcount": "messageDraftCount",
            "mode": "mode",
            "nodecount": "nodeCount",
            "originalstatus": "originalStatus",
            "platform": "platform",
            "readinesscancontinue": "readinessCanContinue",
            "readinessscore": "readinessScore",
            "redaction": "redaction",
            "replaycount": "replayCount",
            "replaydigest": "replayDigest",
            "replayguard": "replayGuard",
            "risktags": "riskTags",
            "satisfiedsignals": "satisfiedSignals",
            "screencapturestate": "screenCaptureState",
            "screenobservationcount": "screenObservationCount",
            "selectednextactionkind": "selectedNextActionKind",
            "selectednextactionrequiresapproval": "selectedNextActionRequiresApproval",
            "allowlistconfigured": "allowlistConfigured",
            "allowlistmatched": "allowlistMatched",
            "commandomitted": "commandOmitted",
            "commandparsed": "commandParsed",
            "cwdomitted": "cwdOmitted",
            "executionattempted": "executionAttempted",
            "exitcodepresent": "exitCodePresent",
            "exitcodezero": "exitCodeZero",
            "shellpolicy": "shellPolicy",
            "shellreview": "shellReview",
            "stderrpresent": "stderrPresent",
            "stderromitted": "stderrOmitted",
            "stdoutpresent": "stdoutPresent",
            "stdoutomitted": "stdoutOmitted",
            "structuredcommandpresent": "structuredCommandPresent",
            "shellstate": "shellState",
            "snapshotkind": "snapshotKind",
            "sourceartifactkinds": "sourceArtifactKinds",
            "stopreason": "stopReason",
            "taskid": "taskID",
            "tokenconfigured": "tokenConfigured",
            "tokenfingerprint": "tokenFingerprint",
            "tokenrequired": "tokenRequired",
            "validatecompleteness": "validateCompleteness",
            "windowmetadatastate": "windowMetadataState",
            "workspacestate": "workspaceState"
        ]
        return keys[lowered]
    }

}

struct ClawGatewayExtractionCompletenessReviewSummary: Equatable, Codable, Sendable {
    var extractionCount: Int
    var latestTitle: String
    var hasMetadata: Bool
    var mode: String?
    var validateCompleteness: Bool?
    var rowCount: Int?
    var completenessStatus: String?
    var browserTraceCount: Int?
    var fileDiffCount: Int?
    var commandOutputCount: Int?
    var screenObservationCount: Int?
    var accessibilityTreeCount: Int?
    var messageDraftCount: Int?
    var sourceArtifactKinds: [String]
    var safetyFlags: [String]
    var isRedacted: Bool

    var compactStatus: String {
        guard hasMetadata else {
            return "已收到结构化提取结果，metadata 待同步。"
        }
        let status = completenessStatus ?? "完整性待复核"
        let rows = rowCount.map { "rows \($0)" } ?? "rows 待复核"
        let sources = sourceArtifactKinds.isEmpty ? "sources 待复核" : "sources \(sourceArtifactKinds.count)"
        return "\(status) · \(rows) · \(sources)"
    }

    static func latest(from session: ClawGatewaySession?) -> ClawGatewayExtractionCompletenessReviewSummary? {
        guard let session else {
            return nil
        }
        return latest(from: session.allArtifacts)
    }

    static func latest(from artifacts: [ClawGatewayArtifact]) -> ClawGatewayExtractionCompletenessReviewSummary? {
        let extractions = artifacts.filter(isExtractionArtifact)
        guard let latest = extractions.last else {
            return nil
        }
        let metadata = latest.metadata ?? [:]
        return ClawGatewayExtractionCompletenessReviewSummary(
            extractionCount: extractions.count,
            latestTitle: ClawArtifactMetadataDisplaySanitizer.safeValue(latest.title) ?? latest.kind.title,
            hasMetadata: metadata.isEmpty == false,
            mode: allowedMode(metadata["mode"]),
            validateCompleteness: ClawArtifactMetadataParser.boolValue(metadata["validateCompleteness"]),
            rowCount: ClawArtifactMetadataParser.intValue(metadata["rowCount"]),
            completenessStatus: allowedCompletenessStatus(metadata["completenessStatus"]),
            browserTraceCount: ClawArtifactMetadataParser.intValue(metadata["browserTraceCount"]),
            fileDiffCount: ClawArtifactMetadataParser.intValue(metadata["fileDiffCount"]),
            commandOutputCount: ClawArtifactMetadataParser.intValue(metadata["commandOutputCount"]),
            screenObservationCount: ClawArtifactMetadataParser.intValue(metadata["screenObservationCount"]),
            accessibilityTreeCount: ClawArtifactMetadataParser.intValue(metadata["accessibilityTreeCount"]),
            messageDraftCount: ClawArtifactMetadataParser.intValue(metadata["messageDraftCount"]),
            sourceArtifactKinds: allowedSourceArtifactKinds(metadata["sourceArtifactKinds"]),
            safetyFlags: allowedSafetyFlags(metadata["safetyFlags"]),
            isRedacted: latest.isRedacted
        )
    }

    private static func isExtractionArtifact(_ artifact: ClawGatewayArtifact) -> Bool {
        artifact.kind == .browserTrace &&
        (
            artifact.title.hasPrefix("extracted-data-") ||
            ClawArtifactMetadataParser.cleanValue(artifact.metadata?["extractionReview"]) == "artifactGrounded" ||
            ClawArtifactMetadataParser.cleanValue(artifact.metadata?["mode"]) == "artifact-grounded-extraction"
        )
    }

    private static func allowedMode(_ value: String?) -> String? {
        guard let clean = ClawArtifactMetadataParser.cleanValue(value) else {
            return nil
        }
        let allowed = ["artifact-grounded-extraction", "dry-run-extraction"]
        return allowed.contains(clean) ? clean : nil
    }

    private static func allowedCompletenessStatus(_ value: String?) -> String? {
        guard let clean = ClawArtifactMetadataParser.cleanValue(value) else {
            return nil
        }
        let allowed = ["complete", "partial", "empty"]
        return allowed.contains(clean) ? clean : nil
    }

    private static func allowedSourceArtifactKinds(_ value: String?) -> [String] {
        let allowed = ["accessibilityTree", "browserTrace", "commandOutput", "fileDiff", "messageDraft", "screenObservation"]
        return ClawArtifactMetadataParser.listValue(value).filter { allowed.contains($0) }
    }

    private static func allowedSafetyFlags(_ value: String?) -> [String] {
        let allowed = [
            "artifact-payload-not-read",
            "metadata-only",
            "row-content-omitted",
            "source-values-omitted",
            "tool-arguments-omitted"
        ]
        return ClawArtifactMetadataParser.listValue(value).filter { allowed.contains($0) }
    }
}

struct ClawGatewayBrowserControlReviewSummary: Equatable, Codable, Sendable {
    var reviewCount: Int
    var latestTitle: String
    var hasMetadata: Bool
    var mode: String?
    var actionKind: String?
    var browserControlPolicy: String?
    var browserControlRequested: Bool?
    var openInBrowser: Bool?
    var targetURLPresent: Bool?
    var searchQueryPresent: Bool?
    var localHTMLInput: Bool?
    var networkFetchAttempted: Bool?
    var networkBlocked: Bool?
    var appAllowlistEnforced: Bool?
    var hostAllowlistEnforced: Bool?
    var executed: Bool?
    var timedOut: Bool?
    var resultStatus: String?
    var safetyFlags: [String]
    var isRedacted: Bool

    var compactStatus: String {
        guard hasMetadata else {
            return "已收到浏览器控制 artifact，metadata 待同步。"
        }
        let policy = browserControlPolicy.map { "policy \($0)" } ?? "policy 待复核"
        let request: String
        if browserControlRequested == true {
            request = "请求打开浏览器"
        } else if browserControlRequested == false {
            request = "未请求打开"
        } else {
            request = "打开状态待复核"
        }
        let network: String
        if networkBlocked == true {
            network = "network blocked"
        } else if networkBlocked == false {
            network = "network checked"
        } else {
            network = "network 待复核"
        }
        return "\(policy) · \(request) · \(network)"
    }

    static func latest(from session: ClawGatewaySession?) -> ClawGatewayBrowserControlReviewSummary? {
        guard let session else {
            return nil
        }
        return latest(from: session.allArtifacts)
    }

    static func latest(from artifacts: [ClawGatewayArtifact]) -> ClawGatewayBrowserControlReviewSummary? {
        let browserArtifacts = artifacts.filter(isBrowserControlArtifact)
        guard let latest = browserArtifacts.last else {
            return nil
        }
        let metadata = latest.metadata ?? [:]
        let hasReviewMetadata = ClawArtifactMetadataParser.cleanValue(metadata["browserReview"]) == "controlPlan"
        return ClawGatewayBrowserControlReviewSummary(
            reviewCount: browserArtifacts.count,
            latestTitle: ClawArtifactMetadataDisplaySanitizer.safeValue(latest.title) ?? latest.kind.title,
            hasMetadata: hasReviewMetadata,
            mode: allowedMode(metadata["mode"]),
            actionKind: allowedActionKind(metadata["actionKind"]),
            browserControlPolicy: allowedPolicy(metadata["browserControlPolicy"]),
            browserControlRequested: ClawArtifactMetadataParser.boolValue(metadata["browserControlRequested"]),
            openInBrowser: ClawArtifactMetadataParser.boolValue(metadata["openInBrowser"]),
            targetURLPresent: ClawArtifactMetadataParser.boolValue(metadata["targetURLPresent"]),
            searchQueryPresent: ClawArtifactMetadataParser.boolValue(metadata["searchQueryPresent"]),
            localHTMLInput: ClawArtifactMetadataParser.boolValue(metadata["localHTMLInput"]),
            networkFetchAttempted: ClawArtifactMetadataParser.boolValue(metadata["networkFetchAttempted"]),
            networkBlocked: ClawArtifactMetadataParser.boolValue(metadata["networkBlocked"]),
            appAllowlistEnforced: ClawArtifactMetadataParser.boolValue(metadata["appAllowlistEnforced"]),
            hostAllowlistEnforced: ClawArtifactMetadataParser.boolValue(metadata["hostAllowlistEnforced"]),
            executed: ClawArtifactMetadataParser.boolValue(metadata["executed"]),
            timedOut: ClawArtifactMetadataParser.boolValue(metadata["timedOut"]),
            resultStatus: allowedResultStatus(metadata["resultStatus"]),
            safetyFlags: allowedSafetyFlags(metadata["safetyFlags"]),
            isRedacted: latest.isRedacted
        )
    }

    private static func isBrowserControlArtifact(_ artifact: ClawGatewayArtifact) -> Bool {
        if ClawArtifactMetadataParser.cleanValue(artifact.metadata?["browserReview"]) == "controlPlan" {
            return true
        }
        if artifact.kind == .browserTrace && artifact.title.hasPrefix("browser-trace-") {
            return true
        }
        if artifact.kind == .screenshot {
            return artifact.title.hasPrefix("browser-control-") || artifact.title.hasPrefix("browser-")
        }
        return false
    }

    private static func allowedMode(_ value: String?) -> String? {
        guard let clean = ClawArtifactMetadataParser.cleanValue(value) else {
            return nil
        }
        let allowed = [
            "browser-control-not-requested",
            "browser-control-dry-run",
            "browser-control-unavailable",
            "browser-control-policy-blocked",
            "browser-control-host-blocked",
            "browser-control-opened",
            "browser-control-failed"
        ]
        return allowed.contains(clean) ? clean : nil
    }

    private static func allowedActionKind(_ value: String?) -> String? {
        guard let clean = ClawArtifactMetadataParser.cleanValue(value) else {
            return nil
        }
        return clean == "controlBrowser" ? clean : nil
    }

    private static func allowedPolicy(_ value: String?) -> String? {
        guard let clean = ClawArtifactMetadataParser.cleanValue(value) else {
            return nil
        }
        let allowed = ["not-requested", "dry-run", "enabled"]
        return allowed.contains(clean) ? clean : nil
    }

    private static func allowedResultStatus(_ value: String?) -> String? {
        guard let clean = ClawArtifactMetadataParser.cleanValue(value) else {
            return nil
        }
        let allowed = ["skipped", "succeeded", "failed"]
        return allowed.contains(clean) ? clean : nil
    }

    private static func allowedSafetyFlags(_ value: String?) -> [String] {
        let allowed = [
            "artifact-payload-not-read",
            "browser-app-allowlist-enforced",
            "browser-host-allowlist-enforced",
            "candidate-labels-omitted",
            "form-fields-omitted",
            "metadata-only",
            "network-allowlist-enforced",
            "page-content-omitted",
            "search-query-omitted",
            "tool-arguments-omitted",
            "url-omitted"
        ]
        return ClawArtifactMetadataParser.listValue(value).filter { allowed.contains($0) }
    }
}

struct ClawGatewayDeliverySafetyReviewSummary: Equatable, Codable, Sendable {
    var reviewCount: Int
    var latestTitle: String
    var hasMetadata: Bool
    var mode: String?
    var actionKind: String?
    var targetKind: String?
    var finalSubmitRequiresApproval: Bool?
    var userApprovalRequired: Bool?
    var draftBodyOmitted: Bool?
    var pasteTextOmitted: Bool?
    var submitBlocked: Bool?
    var allowedKeyCount: Int?
    var blockedKeyCount: Int?
    var blockedSubmitKeyCount: Int?
    var safetyFlags: [String]
    var isRedacted: Bool

    var compactStatus: String {
        guard hasMetadata else {
            return "已收到草稿或桌面提交 artifact，metadata 待同步。"
        }
        let gate = finalSubmitRequiresApproval == true || submitBlocked == true ? "最终提交已拦截" : "最终提交待复核"
        let draft = draftBodyOmitted == true ? "正文省略" : "正文状态待复核"
        let keys = blockedSubmitKeyCount.map { "submit keys \($0)" } ?? "submit keys 待复核"
        return "\(gate) · \(draft) · \(keys)"
    }

    static func latest(from session: ClawGatewaySession?) -> ClawGatewayDeliverySafetyReviewSummary? {
        guard let session else {
            return nil
        }
        return latest(from: session.allArtifacts)
    }

    static func latest(from artifacts: [ClawGatewayArtifact]) -> ClawGatewayDeliverySafetyReviewSummary? {
        let deliveryArtifacts = artifacts.filter(isDeliverySafetyArtifact)
        guard let latest = deliveryArtifacts.last else {
            return nil
        }
        let metadata = latest.metadata ?? [:]
        let hasReviewMetadata = ClawArtifactMetadataParser.cleanValue(metadata["deliveryReview"]) == "finalSubmitGate"
        return ClawGatewayDeliverySafetyReviewSummary(
            reviewCount: deliveryArtifacts.count,
            latestTitle: ClawArtifactMetadataDisplaySanitizer.safeValue(latest.title) ?? latest.kind.title,
            hasMetadata: hasReviewMetadata,
            mode: allowedMode(metadata["mode"]),
            actionKind: allowedActionKind(metadata["actionKind"]),
            targetKind: allowedTargetKind(metadata["targetKind"]),
            finalSubmitRequiresApproval: ClawArtifactMetadataParser.boolValue(metadata["finalSubmitRequiresApproval"]),
            userApprovalRequired: ClawArtifactMetadataParser.boolValue(metadata["userApprovalRequired"]),
            draftBodyOmitted: ClawArtifactMetadataParser.boolValue(metadata["draftBodyOmitted"]),
            pasteTextOmitted: ClawArtifactMetadataParser.boolValue(metadata["pasteTextOmitted"]),
            submitBlocked: ClawArtifactMetadataParser.boolValue(metadata["submitBlocked"]),
            allowedKeyCount: ClawArtifactMetadataParser.intValue(metadata["allowedKeyCount"]),
            blockedKeyCount: ClawArtifactMetadataParser.intValue(metadata["blockedKeyCount"]),
            blockedSubmitKeyCount: ClawArtifactMetadataParser.intValue(metadata["blockedSubmitKeyCount"]),
            safetyFlags: allowedSafetyFlags(metadata["safetyFlags"]),
            isRedacted: latest.isRedacted
        )
    }

    private static func isDeliverySafetyArtifact(_ artifact: ClawGatewayArtifact) -> Bool {
        ClawArtifactMetadataParser.cleanValue(artifact.metadata?["deliveryReview"]) == "finalSubmitGate" ||
            artifact.kind == .messageDraft
    }

    private static func allowedMode(_ value: String?) -> String? {
        guard let clean = ClawArtifactMetadataParser.cleanValue(value) else {
            return nil
        }
        let allowed = [
            "message-draft-pending-approval",
            "desktop-control-dry-run",
            "desktop-control-paused",
            "desktop-control-policy-blocked",
            "desktop-control-unavailable",
            "desktop-control-failed",
            "desktop-control-completed"
        ]
        return allowed.contains(clean) ? clean : nil
    }

    private static func allowedActionKind(_ value: String?) -> String? {
        guard let clean = ClawArtifactMetadataParser.cleanValue(value) else {
            return nil
        }
        let allowed = ["composeMessage", "composeEmail", "operateDesktopApp"]
        return allowed.contains(clean) ? clean : nil
    }

    private static func allowedTargetKind(_ value: String?) -> String? {
        guard let clean = ClawArtifactMetadataParser.cleanValue(value) else {
            return nil
        }
        let allowed = ["message", "email", "desktopApp"]
        return allowed.contains(clean) ? clean : nil
    }

    private static func allowedSafetyFlags(_ value: String?) -> [String] {
        let allowed = [
            "artifact-payload-not-read",
            "draft-body-omitted",
            "final-submit-gated",
            "metadata-only",
            "paste-text-omitted",
            "tool-arguments-omitted",
            "user-approval-required"
        ]
        return ClawArtifactMetadataParser.listValue(value).filter { allowed.contains($0) }
    }
}

struct ClawGatewayFileChangeSafetyReviewSummary: Equatable, Codable, Sendable {
    var reviewCount: Int
    var latestTitle: String
    var hasMetadata: Bool
    var mode: String?
    var actionKind: String?
    var workspacePolicy: String?
    var workspaceScoped: Bool?
    var pathEscapeBlocked: Bool?
    var writeAttempted: Bool?
    var writeSucceeded: Bool?
    var createdFileCount: Int?
    var modifiedFileCount: Int?
    var deletedFileCount: Int?
    var requestedPathPresent: Bool?
    var writeTextPresent: Bool?
    var rawPathOmitted: Bool?
    var contentOmitted: Bool?
    var diffOmitted: Bool?
    var resultStatus: String?
    var safetyFlags: [String]
    var isRedacted: Bool

    var compactStatus: String {
        guard hasMetadata else {
            return "已收到文件变更 artifact，metadata 待同步。"
        }
        let scope = workspacePolicy ?? "workspace 待复核"
        let changes = [
            createdFileCount.map { "created \($0)" },
            modifiedFileCount.map { "modified \($0)" },
            deletedFileCount.map { "deleted \($0)" }
        ]
            .compactMap { $0 }
            .joined(separator: " · ")
        let status = resultStatus ?? "result 待复核"
        return "\(scope) · \(changes.isEmpty ? "changes 待复核" : changes) · \(status)"
    }

    static func latest(from session: ClawGatewaySession?) -> ClawGatewayFileChangeSafetyReviewSummary? {
        guard let session else {
            return nil
        }
        return latest(from: session.allArtifacts)
    }

    static func latest(from artifacts: [ClawGatewayArtifact]) -> ClawGatewayFileChangeSafetyReviewSummary? {
        let fileArtifacts = artifacts.filter(isFileChangeArtifact)
        guard let latest = fileArtifacts.last else {
            return nil
        }
        let metadata = latest.metadata ?? [:]
        let hasReviewMetadata = ClawArtifactMetadataParser.cleanValue(metadata["fileChangeReview"]) == "workspaceWrite"
        return ClawGatewayFileChangeSafetyReviewSummary(
            reviewCount: fileArtifacts.count,
            latestTitle: ClawArtifactMetadataDisplaySanitizer.safeValue(latest.title) ?? latest.kind.title,
            hasMetadata: hasReviewMetadata,
            mode: allowedMode(metadata["mode"]),
            actionKind: allowedActionKind(metadata["actionKind"]),
            workspacePolicy: allowedWorkspacePolicy(metadata["workspacePolicy"]),
            workspaceScoped: ClawArtifactMetadataParser.boolValue(metadata["workspaceScoped"]),
            pathEscapeBlocked: ClawArtifactMetadataParser.boolValue(metadata["pathEscapeBlocked"]),
            writeAttempted: ClawArtifactMetadataParser.boolValue(metadata["writeAttempted"]),
            writeSucceeded: ClawArtifactMetadataParser.boolValue(metadata["writeSucceeded"]),
            createdFileCount: ClawArtifactMetadataParser.intValue(metadata["createdFileCount"]),
            modifiedFileCount: ClawArtifactMetadataParser.intValue(metadata["modifiedFileCount"]),
            deletedFileCount: ClawArtifactMetadataParser.intValue(metadata["deletedFileCount"]),
            requestedPathPresent: ClawArtifactMetadataParser.boolValue(metadata["requestedPathPresent"]),
            writeTextPresent: ClawArtifactMetadataParser.boolValue(metadata["writeTextPresent"]),
            rawPathOmitted: ClawArtifactMetadataParser.boolValue(metadata["rawPathOmitted"]),
            contentOmitted: ClawArtifactMetadataParser.boolValue(metadata["contentOmitted"]),
            diffOmitted: ClawArtifactMetadataParser.boolValue(metadata["diffOmitted"]),
            resultStatus: allowedResultStatus(metadata["resultStatus"]),
            safetyFlags: allowedSafetyFlags(metadata["safetyFlags"]),
            isRedacted: latest.isRedacted
        )
    }

    private static func isFileChangeArtifact(_ artifact: ClawGatewayArtifact) -> Bool {
        ClawArtifactMetadataParser.cleanValue(artifact.metadata?["fileChangeReview"]) == "workspaceWrite" ||
            artifact.kind == .fileDiff
    }

    private static func allowedMode(_ value: String?) -> String? {
        guard let clean = ClawArtifactMetadataParser.cleanValue(value) else {
            return nil
        }
        let allowed = ["workspace-path-blocked", "workspace-write", "workspace-write-failed"]
        return allowed.contains(clean) ? clean : nil
    }

    private static func allowedActionKind(_ value: String?) -> String? {
        guard let clean = ClawArtifactMetadataParser.cleanValue(value) else {
            return nil
        }
        return clean == "manageFiles" ? clean : nil
    }

    private static func allowedWorkspacePolicy(_ value: String?) -> String? {
        guard let clean = ClawArtifactMetadataParser.cleanValue(value) else {
            return nil
        }
        return clean == "session-workspace-only" ? clean : nil
    }

    private static func allowedResultStatus(_ value: String?) -> String? {
        guard let clean = ClawArtifactMetadataParser.cleanValue(value) else {
            return nil
        }
        let allowed = ["skipped", "succeeded", "failed"]
        return allowed.contains(clean) ? clean : nil
    }

    private static func allowedSafetyFlags(_ value: String?) -> [String] {
        let allowed = [
            "artifact-payload-not-read",
            "diff-content-omitted",
            "file-content-omitted",
            "metadata-only",
            "no-file-written",
            "path-escape-blocked",
            "raw-path-omitted",
            "session-workspace-only",
            "tool-arguments-omitted",
            "write-failed",
            "workspace-path-omitted"
        ]
        return ClawArtifactMetadataParser.listValue(value).filter { allowed.contains($0) }
    }
}

struct ClawGatewayShellCommandSafetyReviewSummary: Equatable, Codable, Sendable {
    var reviewCount: Int
    var latestTitle: String
    var hasMetadata: Bool
    var mode: String?
    var actionKind: String?
    var shellPolicy: String?
    var structuredCommandPresent: Bool?
    var commandParsed: Bool?
    var allowlistConfigured: Bool?
    var allowlistMatched: Bool?
    var executionAttempted: Bool?
    var executed: Bool?
    var timedOut: Bool?
    var exitCodePresent: Bool?
    var exitCodeZero: Bool?
    var stdoutPresent: Bool?
    var stderrPresent: Bool?
    var commandOmitted: Bool?
    var stdoutOmitted: Bool?
    var stderrOmitted: Bool?
    var cwdOmitted: Bool?
    var resultStatus: String?
    var safetyFlags: [String]
    var isRedacted: Bool

    var compactStatus: String {
        guard hasMetadata else {
            return "已收到 Shell 输出 artifact，metadata 待同步。"
        }
        let policy = shellPolicy.map { "policy \($0)" } ?? "policy 待复核"
        let execution: String
        if executed == true {
            execution = "executed"
        } else if executionAttempted == false {
            execution = "not executed"
        } else {
            execution = "execution 待复核"
        }
        let result = resultStatus ?? "result 待复核"
        return "\(policy) · \(execution) · \(result)"
    }

    static func latest(from session: ClawGatewaySession?) -> ClawGatewayShellCommandSafetyReviewSummary? {
        guard let session else {
            return nil
        }
        return latest(from: session.allArtifacts)
    }

    static func latest(from artifacts: [ClawGatewayArtifact]) -> ClawGatewayShellCommandSafetyReviewSummary? {
        let shellArtifacts = artifacts.filter(isShellCommandSafetyArtifact)
        guard let latest = shellArtifacts.last else {
            return nil
        }
        let metadata = latest.metadata ?? [:]
        let hasReviewMetadata = ClawArtifactMetadataParser.cleanValue(metadata["shellReview"]) == "commandSafety"
        return ClawGatewayShellCommandSafetyReviewSummary(
            reviewCount: shellArtifacts.count,
            latestTitle: ClawArtifactMetadataDisplaySanitizer.safeValue(latest.title) ?? latest.kind.title,
            hasMetadata: hasReviewMetadata,
            mode: allowedMode(metadata["mode"]),
            actionKind: allowedActionKind(metadata["actionKind"]),
            shellPolicy: allowedShellPolicy(metadata["shellPolicy"]),
            structuredCommandPresent: ClawArtifactMetadataParser.boolValue(metadata["structuredCommandPresent"]),
            commandParsed: ClawArtifactMetadataParser.boolValue(metadata["commandParsed"]),
            allowlistConfigured: ClawArtifactMetadataParser.boolValue(metadata["allowlistConfigured"]),
            allowlistMatched: ClawArtifactMetadataParser.boolValue(metadata["allowlistMatched"]),
            executionAttempted: ClawArtifactMetadataParser.boolValue(metadata["executionAttempted"]),
            executed: ClawArtifactMetadataParser.boolValue(metadata["executed"]),
            timedOut: ClawArtifactMetadataParser.boolValue(metadata["timedOut"]),
            exitCodePresent: ClawArtifactMetadataParser.boolValue(metadata["exitCodePresent"]),
            exitCodeZero: ClawArtifactMetadataParser.boolValue(metadata["exitCodeZero"]),
            stdoutPresent: ClawArtifactMetadataParser.boolValue(metadata["stdoutPresent"]),
            stderrPresent: ClawArtifactMetadataParser.boolValue(metadata["stderrPresent"]),
            commandOmitted: ClawArtifactMetadataParser.boolValue(metadata["commandOmitted"]),
            stdoutOmitted: ClawArtifactMetadataParser.boolValue(metadata["stdoutOmitted"]),
            stderrOmitted: ClawArtifactMetadataParser.boolValue(metadata["stderrOmitted"]),
            cwdOmitted: ClawArtifactMetadataParser.boolValue(metadata["cwdOmitted"]),
            resultStatus: allowedResultStatus(metadata["resultStatus"]),
            safetyFlags: allowedSafetyFlags(metadata["safetyFlags"]),
            isRedacted: latest.isRedacted
        )
    }

    private static func isShellCommandSafetyArtifact(_ artifact: ClawGatewayArtifact) -> Bool {
        ClawArtifactMetadataParser.cleanValue(artifact.metadata?["shellReview"]) == "commandSafety" ||
            artifact.kind == .commandOutput
    }

    private static func allowedMode(_ value: String?) -> String? {
        guard let clean = ClawArtifactMetadataParser.cleanValue(value) else {
            return nil
        }
        let allowed = ["missing-structured-command", "command-parse-failed", "shell-policy-blocked", "shell-executed"]
        return allowed.contains(clean) ? clean : nil
    }

    private static func allowedActionKind(_ value: String?) -> String? {
        guard let clean = ClawArtifactMetadataParser.cleanValue(value) else {
            return nil
        }
        return clean == "runShellCommand" ? clean : nil
    }

    private static func allowedShellPolicy(_ value: String?) -> String? {
        guard let clean = ClawArtifactMetadataParser.cleanValue(value) else {
            return nil
        }
        let allowed = ["dry-run", "allowlist-required", "allowlist-enabled"]
        return allowed.contains(clean) ? clean : nil
    }

    private static func allowedResultStatus(_ value: String?) -> String? {
        guard let clean = ClawArtifactMetadataParser.cleanValue(value) else {
            return nil
        }
        let allowed = ["skipped", "succeeded", "failed"]
        return allowed.contains(clean) ? clean : nil
    }

    private static func allowedSafetyFlags(_ value: String?) -> [String] {
        let allowed = [
            "artifact-payload-not-read",
            "command-omitted",
            "cwd-omitted",
            "dry-run-only",
            "metadata-only",
            "natural-language-not-executed",
            "no-command-executed",
            "parse-failed",
            "shell-allowlist-enforced",
            "stderr-omitted",
            "stdout-omitted",
            "structured-arguments-only",
            "tool-arguments-omitted"
        ]
        return ClawArtifactMetadataParser.listValue(value).filter { allowed.contains($0) }
    }
}

struct ClawAgentTraceReviewSummary: Equatable, Codable, Sendable {
    var traceCount: Int
    var latestTitle: String
    var hasMetadata: Bool
    var readinessScore: Int?
    var readinessCanContinue: Bool?
    var satisfiedSignals: [String]
    var degradedSignals: [String]
    var missingSignals: [String]
    var selectedNextActionKind: String?
    var selectedNextActionRequiresApproval: Bool?
    var riskTags: [String]
    var stopReason: String?
    var handoffStatus: String?
    var handoffSummary: String?
    var isRedacted: Bool

    var compactStatus: String {
        guard hasMetadata else {
            return "已收到智能体轨迹，metadata 待同步。"
        }
        let score = readinessScore.map { "证据 \($0)/100" } ?? "证据待复核"
        let action = selectedNextActionKind ?? "下一步待定"
        let handoff = handoffStatus.map { "交接 \($0)" } ?? (stopReason ?? "handoff 待同步")
        return "\(score) · \(action) · \(handoff)"
    }

    static func latest(from session: ClawGatewaySession?) -> ClawAgentTraceReviewSummary? {
        guard let session else {
            return nil
        }
        return latest(from: session.results.flatMap(\.artifacts))
    }

    static func latest(from artifacts: [ClawGatewayArtifact]) -> ClawAgentTraceReviewSummary? {
        let traces = artifacts.filter { $0.kind == .agentTrace }
        guard let latest = traces.last else {
            return nil
        }
        let metadata = latest.metadata ?? [:]
        return ClawAgentTraceReviewSummary(
            traceCount: traces.count,
            latestTitle: ClawArtifactMetadataDisplaySanitizer.safeValue(latest.title) ?? latest.kind.title,
            hasMetadata: metadata.isEmpty == false,
            readinessScore: ClawArtifactMetadataParser.intValue(metadata["readinessScore"]),
            readinessCanContinue: ClawArtifactMetadataParser.boolValue(metadata["readinessCanContinue"]),
            satisfiedSignals: Self.allowedAgentSignalList(metadata["satisfiedSignals"]),
            degradedSignals: Self.allowedAgentSignalList(metadata["degradedSignals"]),
            missingSignals: Self.allowedAgentSignalList(metadata["missingSignals"]),
            selectedNextActionKind: ClawArtifactMetadataDisplaySanitizer.safeValue(metadata["selectedNextActionKind"]),
            selectedNextActionRequiresApproval: ClawArtifactMetadataParser.boolValue(metadata["selectedNextActionRequiresApproval"]),
            riskTags: ClawArtifactMetadataDisplaySanitizer.safeList(metadata["riskTags"]),
            stopReason: ClawArtifactMetadataDisplaySanitizer.safeValue(metadata["stopReason"]),
            handoffStatus: Self.allowedHandoffStatus(metadata["handoffStatus"]),
            handoffSummary: ClawArtifactMetadataDisplaySanitizer.safeValue(metadata["handoffSummary"]),
            isRedacted: latest.isRedacted
        )
    }

    static func allowedHandoffStatus(_ value: String?) -> String? {
        guard let clean = ClawArtifactMetadataParser.cleanValue(value) else {
            return nil
        }
        let allowed = [
            "needs-evidence",
            "waiting-for-approval",
            "final-submit-review",
            "blocked",
            "ready-to-continue",
            "complete"
        ]
        return allowed.contains(clean) ? clean : nil
    }

    static func allowedAgentSignalList(_ value: String?) -> [String] {
        let allowed = [
            "screenObservation",
            "accessibilityTree",
            "browserTrace",
            "fileDiff",
            "commandOutput",
            "messageDraft",
            "agentTrace"
        ]
        return ClawArtifactMetadataParser.listValue(value).filter { allowed.contains($0) }
    }

    var needsHandoffReview: Bool {
        guard hasMetadata else {
            return true
        }
        switch handoffStatus {
        case "needs-evidence", "waiting-for-approval", "final-submit-review", "blocked":
            return true
        default:
            return false
        }
    }
}

struct ClawGatewayAccessibilityReviewSummary: Equatable, Codable, Sendable {
    var treeCount: Int
    var latestTitle: String
    var hasMetadata: Bool
    var mode: String?
    var accessibilityPolicy: String?
    var includeAccessibilityTree: Bool?
    var maxCandidateControls: Int?
    var nodeCount: Int?
    var candidateControlCount: Int?
    var platform: String?
    var redaction: String?
    var safetyFlags: [String]
    var isRedacted: Bool

    var compactStatus: String {
        guard hasMetadata else {
            return "已收到 Accessibility 观察，metadata 待同步。"
        }
        let modeText = mode.map { "ax \($0)" } ?? "ax 待复核"
        let policyText = accessibilityPolicy.map { "policy \($0)" } ?? "policy 待复核"
        let controlText: String
        if let candidateControlCount, let maxCandidateControls {
            controlText = "controls \(candidateControlCount)/\(maxCandidateControls)"
        } else if let nodeCount {
            controlText = "nodes \(nodeCount)"
        } else {
            controlText = "controls 待复核"
        }
        return "\(modeText) · \(policyText) · \(controlText)"
    }

    static func latest(from session: ClawGatewaySession?) -> ClawGatewayAccessibilityReviewSummary? {
        guard let session else {
            return nil
        }
        return latest(from: session.allArtifacts)
    }

    static func latest(from artifacts: [ClawGatewayArtifact]) -> ClawGatewayAccessibilityReviewSummary? {
        let trees = artifacts.filter { $0.kind == .accessibilityTree }
        guard let latest = trees.last else {
            return nil
        }
        let metadata = latest.metadata ?? [:]
        let hasReviewMetadata = ClawArtifactMetadataParser.cleanValue(metadata["accessibilityTree"]) == "observeSummary" ||
            ClawArtifactMetadataParser.cleanValue(metadata["mode"]) != nil
        return ClawGatewayAccessibilityReviewSummary(
            treeCount: trees.count,
            latestTitle: ClawArtifactMetadataDisplaySanitizer.safeValue(latest.title) ?? latest.kind.title,
            hasMetadata: hasReviewMetadata,
            mode: ClawArtifactMetadataDisplaySanitizer.safeValue(metadata["mode"]),
            accessibilityPolicy: ClawArtifactMetadataDisplaySanitizer.safeValue(metadata["accessibilityPolicy"]),
            includeAccessibilityTree: ClawArtifactMetadataParser.boolValue(metadata["includeAccessibilityTree"]),
            maxCandidateControls: ClawArtifactMetadataParser.intValue(metadata["maxCandidateControls"]),
            nodeCount: ClawArtifactMetadataParser.intValue(metadata["nodeCount"]),
            candidateControlCount: ClawArtifactMetadataParser.intValue(metadata["candidateControlCount"]),
            platform: ClawArtifactMetadataDisplaySanitizer.safeValue(metadata["platform"]),
            redaction: ClawArtifactMetadataDisplaySanitizer.safeValue(metadata["redaction"]),
            safetyFlags: ClawArtifactMetadataDisplaySanitizer.safeList(metadata["safetyFlags"]),
            isRedacted: latest.isRedacted
        )
    }
}

struct ClawGatewayCapabilityReviewSummary: Equatable, Codable, Sendable {
    var snapshotCount: Int
    var latestTitle: String
    var hasMetadata: Bool
    var tokenConfigured: Bool?
    var tokenRequired: Bool?
    var tokenFingerprint: String?
    var allowedActionKinds: [String]
    var workspaceState: String?
    var shellState: String?
    var browserControlState: String?
    var browserNetworkState: String?
    var screenCaptureState: String?
    var windowMetadataState: String?
    var accessibilityTreeState: String?
    var desktopControlState: String?
    var safetyFlags: [String]
    var platform: String?
    var isRedacted: Bool

    var compactStatus: String {
        guard hasMetadata else {
            return "已收到 Gateway 能力快照，metadata 待同步。"
        }
        let host = platform.map { "Gateway \($0)" } ?? "Gateway 能力"
        let token = tokenFingerprint.map { "token \($0)" } ?? "token 待复核"
        let shell = shellState.map { "shell \($0)" } ?? "shell 待复核"
        let accessibility = accessibilityTreeState.map { "ax \($0)" } ?? "ax 待复核"
        let desktop = desktopControlState.map { "desktop \($0)" } ?? "desktop 待复核"
        return "\(host) · \(token) · \(shell) · \(accessibility) · \(desktop)"
    }

    static func latest(from session: ClawGatewaySession?) -> ClawGatewayCapabilityReviewSummary? {
        guard let session else {
            return nil
        }
        return latest(from: session.allArtifacts)
    }

    static func latest(from artifacts: [ClawGatewayArtifact]) -> ClawGatewayCapabilityReviewSummary? {
        let snapshots = artifacts.filter(isCapabilitySnapshot)
        guard let latest = snapshots.last else {
            return nil
        }
        let metadata = latest.metadata ?? [:]
        return ClawGatewayCapabilityReviewSummary(
            snapshotCount: snapshots.count,
            latestTitle: ClawArtifactMetadataDisplaySanitizer.safeValue(latest.title) ?? latest.kind.title,
            hasMetadata: metadata.isEmpty == false,
            tokenConfigured: ClawArtifactMetadataParser.boolValue(metadata["tokenConfigured"]),
            tokenRequired: ClawArtifactMetadataParser.boolValue(metadata["tokenRequired"]),
            tokenFingerprint: ClawArtifactMetadataDisplaySanitizer.safeValue(metadata["tokenFingerprint"]),
            allowedActionKinds: ClawArtifactMetadataDisplaySanitizer.safeList(metadata["allowedActionKinds"]),
            workspaceState: ClawArtifactMetadataDisplaySanitizer.safeValue(metadata["workspaceState"]),
            shellState: ClawArtifactMetadataDisplaySanitizer.safeValue(metadata["shellState"]),
            browserControlState: ClawArtifactMetadataDisplaySanitizer.safeValue(metadata["browserControlState"]),
            browserNetworkState: ClawArtifactMetadataDisplaySanitizer.safeValue(metadata["browserNetworkState"]),
            screenCaptureState: ClawArtifactMetadataDisplaySanitizer.safeValue(metadata["screenCaptureState"]),
            windowMetadataState: ClawArtifactMetadataDisplaySanitizer.safeValue(metadata["windowMetadataState"]),
            accessibilityTreeState: ClawArtifactMetadataDisplaySanitizer.safeValue(metadata["accessibilityTreeState"]),
            desktopControlState: ClawArtifactMetadataDisplaySanitizer.safeValue(metadata["desktopControlState"]),
            safetyFlags: ClawArtifactMetadataDisplaySanitizer.safeList(metadata["safetyFlags"]),
            platform: ClawArtifactMetadataDisplaySanitizer.safeValue(metadata["platform"]),
            isRedacted: latest.isRedacted
        )
    }

    private static func isCapabilitySnapshot(_ artifact: ClawGatewayArtifact) -> Bool {
        artifact.kind == .auditLog &&
        (artifact.title == "gateway-capability-snapshot.json" || artifact.metadata?["snapshotKind"] == "gatewayCapability")
    }
}

struct ClawGatewayTaskReplayGuardReviewSummary: Equatable, Codable, Sendable {
    var replayCountArtifacts: Int
    var latestTitle: String
    var hasMetadata: Bool
    var decision: String?
    var taskID: String?
    var replayDigest: String?
    var digestMatchesFirst: Bool?
    var firstSessionID: String?
    var originalStatus: String?
    var replayCount: Int?
    var actionCount: Int?
    var actionKinds: [String]
    var safetyFlags: [String]
    var isRedacted: Bool

    var shortTaskID: String? {
        shortIdentifier(taskID)
    }

    var shortReplayDigest: String? {
        shortDigest(replayDigest)
    }

    var shortFirstSessionID: String? {
        shortIdentifier(firstSessionID)
    }

    var compactStatus: String {
        guard hasMetadata else {
            return "已收到 replay guard 审计，metadata 待同步。"
        }
        let decisionText = decision ?? "replay guard"
        let replayText = replayCount.map { "重复 \($0) 次" } ?? "重复次数待复核"
        let actionText = actionCount.map { "跳过 \($0) 个动作" } ?? "动作数待复核"
        let statusText = originalStatus.map { "首次 \($0)" } ?? "首次状态待复核"
        return "\(decisionText) · \(replayText) · \(actionText) · \(statusText)"
    }

    static func latest(from session: ClawGatewaySession?) -> ClawGatewayTaskReplayGuardReviewSummary? {
        guard let session else {
            return nil
        }
        return latest(from: session.allArtifacts)
    }

    static func latest(from artifacts: [ClawGatewayArtifact]) -> ClawGatewayTaskReplayGuardReviewSummary? {
        let replayArtifacts = artifacts.filter(isReplayGuardArtifact)
        guard let latest = replayArtifacts.last else {
            return nil
        }
        let metadata = latest.metadata ?? [:]
        return ClawGatewayTaskReplayGuardReviewSummary(
            replayCountArtifacts: replayArtifacts.count,
            latestTitle: ClawArtifactMetadataDisplaySanitizer.safeValue(latest.title) ?? latest.kind.title,
            hasMetadata: metadata.isEmpty == false,
            decision: ClawArtifactMetadataDisplaySanitizer.safeValue(metadata["decision"]),
            taskID: ClawArtifactMetadataDisplaySanitizer.safeValue(metadata["taskID"]),
            replayDigest: ClawArtifactMetadataDisplaySanitizer.safeValue(metadata["replayDigest"]),
            digestMatchesFirst: ClawArtifactMetadataParser.boolValue(metadata["digestMatchesFirst"]),
            firstSessionID: ClawArtifactMetadataDisplaySanitizer.safeValue(metadata["firstSessionID"]),
            originalStatus: ClawArtifactMetadataDisplaySanitizer.safeValue(metadata["originalStatus"]),
            replayCount: ClawArtifactMetadataParser.intValue(metadata["replayCount"]),
            actionCount: ClawArtifactMetadataParser.intValue(metadata["actionCount"]),
            actionKinds: ClawArtifactMetadataDisplaySanitizer.safeList(metadata["actionKinds"]),
            safetyFlags: ClawArtifactMetadataDisplaySanitizer.safeList(metadata["safetyFlags"]),
            isRedacted: latest.isRedacted
        )
    }

    private static func isReplayGuardArtifact(_ artifact: ClawGatewayArtifact) -> Bool {
        artifact.kind == .auditLog &&
        (
            artifact.title == "task-replay-guard.json" ||
            ClawArtifactMetadataParser.cleanValue(artifact.metadata?["replayGuard"]) == "taskReplayGuard"
        )
    }

    private func shortIdentifier(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        return String(value.prefix(8))
    }

    private func shortDigest(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let prefix = value.hasPrefix("sha256:") ? "sha256:" : ""
        let body = value.hasPrefix("sha256:") ? String(value.dropFirst(7)) : value
        return prefix + body.prefix(12)
    }
}

struct ClawMissionRunSummary: Equatable, Codable, Sendable {
    var command: String
    var phaseTitle: String
    var phaseIcon: String
    var progressCurrent: Int
    var progressTotal: Int
    var riskScore: Int
    var approvalCount: Int
    var blockedCount: Int
    var succeededCount: Int
    var failedCount: Int
    var retryableCount: Int
    var artifactCount: Int
    var artifactKinds: [ClawGatewayArtifactKind]
    var artifactMetadataReview: ClawGatewayArtifactMetadataReviewSummary?
    var gatewayExtractionCompletenessReview: ClawGatewayExtractionCompletenessReviewSummary?
    var gatewayBrowserControlReview: ClawGatewayBrowserControlReviewSummary?
    var gatewayDeliverySafetyReview: ClawGatewayDeliverySafetyReviewSummary?
    var gatewayFileChangeSafetyReview: ClawGatewayFileChangeSafetyReviewSummary?
    var gatewayShellCommandSafetyReview: ClawGatewayShellCommandSafetyReviewSummary?
    var agentTraceReview: ClawAgentTraceReviewSummary?
    var gatewayAccessibilityReview: ClawGatewayAccessibilityReviewSummary?
    var gatewayCapabilityReview: ClawGatewayCapabilityReviewSummary?
    var gatewayTaskReplayGuardReview: ClawGatewayTaskReplayGuardReviewSummary?
    var reviewPriorityQueue: [ClawMissionRunReviewPriorityItem]
    var approvalQueue: [ClawMissionRunApprovalQueueItem]
    var actionPreflightItems: [ClawMissionRunActionPreflightItem]
    var primaryActionTitle: String
    var primaryActionIcon: String
    var primaryActionKind: ClawMissionRunPrimaryActionKind
    var isPrimaryActionEnabled: Bool
    var requiresUserApproval: Bool
    var statusLine: String
    var stageTrack: [ClawMissionRunStage]
}

extension ClawMissionRunSummary {
    static let detailReviewKindOrder: [String] = [
        "artifact-metadata",
        "file-change-safety",
        "shell-safety",
        "extraction-completeness",
        "browser-control",
        "delivery-safety",
        "gateway-capability",
        "accessibility",
        "replay-guard",
        "agent-trace"
    ]

    var availableDetailReviewKinds: [String] {
        Self.detailReviewKindOrder.filter { kind in
            switch kind {
            case "artifact-metadata":
                return artifactMetadataReview != nil
            case "file-change-safety":
                return gatewayFileChangeSafetyReview != nil
            case "shell-safety":
                return gatewayShellCommandSafetyReview != nil
            case "extraction-completeness":
                return gatewayExtractionCompletenessReview != nil
            case "browser-control":
                return gatewayBrowserControlReview != nil
            case "delivery-safety":
                return gatewayDeliverySafetyReview != nil
            case "gateway-capability":
                return gatewayCapabilityReview != nil
            case "accessibility":
                return gatewayAccessibilityReview != nil
            case "replay-guard":
                return gatewayTaskReplayGuardReview != nil
            case "agent-trace":
                return agentTraceReview != nil
            default:
                return false
            }
        }
    }

    func activeReviewFocus(from requestedReviewKind: String?) -> String? {
        guard let requestedReviewKind else {
            return nil
        }
        if reviewPriorityQueue.contains(where: { $0.reviewKind == requestedReviewKind }) {
            return requestedReviewKind
        }
        if availableDetailReviewKinds.contains(requestedReviewKind) {
            return requestedReviewKind
        }
        return nil
    }

    var reviewDetailDockSummary: ClawMissionRunReviewDetailDockSummary {
        reviewDetailDockSummary(focusedOn: nil)
    }

    func reviewDetailDockSummary(focusedOn requestedReviewKind: String?) -> ClawMissionRunReviewDetailDockSummary {
        let activeReviewKind = activeReviewFocus(from: requestedReviewKind)
        let detailKinds = detailReviewKinds(focusedOn: activeReviewKind)
        let focusHasDetail = focusUsesDetailReview(activeReviewKind)
        let activePriorityItem = reviewPriorityItem(focusedOn: activeReviewKind)
        let activeReviewTitle = activePriorityItem?.title ?? activeReviewKind.map(Self.title(forDetailReviewKind:))
        let isReviewable = detailKinds.isEmpty == false || reviewPriorityQueue.isEmpty == false
        let hasStaleFocus = requestedReviewKind != nil && activeReviewKind == nil
        let next = nextReviewAction(focusedOn: activeReviewKind)

        if isReviewable == false {
            return ClawMissionRunReviewDetailDockSummary(
                title: "Mission 复核详情待生成",
                status: "尚无 Gateway 证据",
                guidance: "发送任务后，iPad 工作台会在这里显示当前聚焦复核详情。",
                icon: "sidebar.right",
                requestedReviewKind: requestedReviewKind,
                activeReviewKind: nil,
                activeReviewTitle: nil,
                detailReviewKinds: [],
                showsFocusedDetailOnly: false,
                canClearFocus: false,
                hasStaleFocus: hasStaleFocus,
                isReviewable: false
            )
        }

        if hasStaleFocus {
            return ClawMissionRunReviewDetailDockSummary(
                title: "Mission 复核详情已更新",
                status: "\(detailKinds.count) 类详细复核可查看",
                guidance: "当前聚焦项不在最新复核队列；右侧保持全量详情，可清除后重新选择。",
                icon: "scope",
                requestedReviewKind: requestedReviewKind,
                activeReviewKind: nil,
                activeReviewTitle: nil,
                detailReviewKinds: detailKinds,
                showsFocusedDetailOnly: false,
                canClearFocus: true,
                hasStaleFocus: true,
                isReviewable: true
            )
        }

        if let activeReviewKind, let activeReviewTitle {
            if focusHasDetail {
                return ClawMissionRunReviewDetailDockSummary(
                    title: "Mission 聚焦详情",
                    status: activeReviewTitle,
                    guidance: "右侧只显示 \(activeReviewTitle) 安全摘要；左侧 Mission Run 可清除聚焦恢复全量。",
                    icon: "sidebar.right",
                    requestedReviewKind: requestedReviewKind,
                    activeReviewKind: activeReviewKind,
                    activeReviewTitle: activeReviewTitle,
                    detailReviewKinds: detailKinds,
                    showsFocusedDetailOnly: detailKinds.count == 1,
                    canClearFocus: true,
                    hasStaleFocus: false,
                    isReviewable: true
                )
            }

            return ClawMissionRunReviewDetailDockSummary(
                title: "Mission 状态聚焦",
                status: activeReviewTitle,
                guidance: "\(activeReviewTitle) 没有单独详情 row；右侧保持全量安全摘要。",
                icon: "sidebar.right",
                requestedReviewKind: requestedReviewKind,
                activeReviewKind: activeReviewKind,
                activeReviewTitle: activeReviewTitle,
                detailReviewKinds: detailKinds,
                showsFocusedDetailOnly: false,
                canClearFocus: true,
                hasStaleFocus: false,
                isReviewable: true
            )
        }

        let guidance = next.reviewTitle.map { "建议先聚焦 \($0)：\(next.actionHint ?? next.guidance)" } ?? "从左侧复核优先队列选择一项，右侧会同步显示对应详情。"
        return ClawMissionRunReviewDetailDockSummary(
            title: "Mission 复核详情",
            status: "\(detailKinds.count) 类详细复核可查看",
            guidance: guidance,
            icon: "sidebar.right",
            requestedReviewKind: requestedReviewKind,
            activeReviewKind: nil,
            activeReviewTitle: nil,
            detailReviewKinds: detailKinds,
            showsFocusedDetailOnly: false,
            canClearFocus: false,
            hasStaleFocus: false,
            isReviewable: true
        )
    }

    func detailReviewKinds(focusedOn reviewKind: String?) -> [String] {
        let available = availableDetailReviewKinds
        guard let reviewKind, available.contains(reviewKind) else {
            return available
        }
        return [reviewKind]
    }

    func shouldShowDetailReview(_ reviewKind: String, focusedOn focusedReviewKind: String?) -> Bool {
        detailReviewKinds(focusedOn: focusedReviewKind).contains(reviewKind)
    }

    func reviewPriorityItem(focusedOn reviewKind: String?) -> ClawMissionRunReviewPriorityItem? {
        guard let reviewKind else {
            return nil
        }
        return reviewPriorityQueue.first { $0.reviewKind == reviewKind }
    }

    func focusUsesDetailReview(_ reviewKind: String?) -> Bool {
        guard let reviewKind else {
            return false
        }
        return availableDetailReviewKinds.contains(reviewKind)
    }

    var approvalQueueSummary: ClawMissionRunApprovalQueueSummary {
        approvalQueueSummary(focusedOn: nil)
    }

    func approvalQueueSummary(focusedOn reviewKind: String?) -> ClawMissionRunApprovalQueueSummary {
        let focusedKind = activeReviewFocus(from: reviewKind)
        let focusedItem = focusedKind.flatMap { kind in
            approvalQueue.first { $0.reviewKind == kind }
        }
        let items = approvalQueue.map { item in
            ClawMissionRunApprovalQueueItem(
                id: item.id,
                rank: item.rank,
                severity: item.severity,
                title: item.title,
                status: item.status,
                reason: item.reason,
                icon: item.icon,
                reviewKind: item.reviewKind,
                actionKindTitle: item.actionKindTitle,
                approvalTitle: item.approvalTitle,
                isActionable: item.isActionable,
                hasMetadata: item.hasMetadata,
                canFocusReview: item.canFocusReview,
                isFocused: item.reviewKind == focusedKind
            )
        }
        let actionableCount = items.filter(\.isActionable).count
        let criticalOrHighCount = items.filter { item in
            item.severity == .critical || item.severity == .high
        }.count
        let metadataPendingCount = items.filter { $0.hasMetadata == false }.count
        let topItem = focusedItem ?? items.first
        let isReviewable = items.isEmpty == false
        let requiresHumanAction = actionableCount > 0 || criticalOrHighCount > 0 || requiresUserApproval
        let hasMetadataGap = metadataPendingCount > 0

        let title: String
        let status: String
        let guidance: String
        let icon: String
        if isReviewable == false {
            title = "审批队列待生成"
            status = "暂无待确认项"
            guidance = "生成任务或收到 Gateway 等待确认事件后，这里会列出需要人工处理的确认点。"
            icon = "checklist"
        } else if let focusedItem {
            title = "聚焦审批队列"
            status = focusedItem.title
            guidance = "当前聚焦 \(focusedItem.title)：\(focusedItem.reason)"
            icon = focusedItem.icon
        } else if requiresHumanAction {
            title = "Mission 审批队列"
            status = "\(actionableCount) 项可处理 · \(criticalOrHighCount) 项高优先"
            guidance = topItem.map { "先看 \($0.title)：\($0.reason)" } ?? "先处理可行动确认项。"
            icon = "checkmark.seal.fill"
        } else if hasMetadataGap {
            title = "Mission 审批队列"
            status = "\(metadataPendingCount) 项 metadata 待同步"
            guidance = "等待 Gateway metadata 后再确认审批状态。"
            icon = "doc.badge.clock"
        } else {
            title = "Mission 审批队列"
            status = "\(items.count) 项可抽查"
            guidance = topItem.map { "可抽查 \($0.title)：\($0.reason)" } ?? "审批队列已同步。"
            icon = "checkmark.seal.fill"
        }

        return ClawMissionRunApprovalQueueSummary(
            title: title,
            status: status,
            guidance: guidance,
            icon: icon,
            totalCount: items.count,
            actionableCount: actionableCount,
            criticalOrHighCount: criticalOrHighCount,
            metadataPendingCount: metadataPendingCount,
            focusedReviewKind: focusedItem?.reviewKind,
            focusedReviewTitle: focusedItem?.title,
            primaryReviewKind: topItem?.reviewKind,
            primaryReviewTitle: topItem?.title,
            canFocusPrimaryReview: topItem?.canFocusReview ?? false,
            requiresHumanAction: requiresHumanAction,
            hasMetadataGap: hasMetadataGap,
            isReviewable: isReviewable,
            items: items
        )
    }

    var payloadSafetyLedger: ClawMissionRunPayloadSafetyLedgerSummary {
        payloadSafetyLedger(focusedOn: nil)
    }

    func payloadSafetyLedger(focusedOn reviewKind: String?) -> ClawMissionRunPayloadSafetyLedgerSummary {
        let focusedKind = activeReviewFocus(from: reviewKind)
        let items = availableDetailReviewKinds.map { kind in
            let flags = safetyFlags(forDetailReviewKind: kind)
            let omissionCount = Self.omissionSignalCount(in: flags)
            let hasMetadata = metadataReady(forDetailReviewKind: kind)
            return ClawMissionRunPayloadSafetyLedgerItem(
                reviewKind: kind,
                reviewTitle: Self.title(forDetailReviewKind: kind),
                status: Self.payloadSafetyStatus(hasMetadata: hasMetadata, flags: flags),
                guidance: Self.payloadSafetyGuidance(hasMetadata: hasMetadata, flags: flags),
                icon: Self.icon(forDetailReviewKind: kind),
                hasMetadata: hasMetadata,
                payloadNotRead: flags.contains("artifact-payload-not-read"),
                metadataOnly: flags.contains("metadata-only"),
                omissionSignalCount: omissionCount,
                safetyFlags: flags,
                canFocusReview: focusUsesDetailReview(kind),
                isFocused: kind == focusedKind
            )
        }

        let payloadNotReadCount = items.filter(\.payloadNotRead).count
        let metadataOnlyCount = items.filter(\.metadataOnly).count
        let omissionSignalCount = items.reduce(0) { $0 + $1.omissionSignalCount }
        let metadataPendingCount = items.filter { $0.hasMetadata == false }.count
        let focusedItem = focusedKind.flatMap { kind in
            items.first { $0.reviewKind == kind }
        }
        let primaryItem = focusedItem ?? items.first { $0.hasMetadata == false } ?? items.first { $0.payloadNotRead == false } ?? items.first
        let isReviewable = items.isEmpty == false
        let hasMetadataGap = metadataPendingCount > 0

        let title: String
        let status: String
        let guidance: String
        let icon: String
        if isReviewable == false {
            title = "Payload 安全账本待生成"
            status = "尚无 Gateway artifact"
            guidance = "发送任务后会从安全 metadata 汇总 payload 是否被读取、哪些内容已省略。"
            icon = "lock.doc"
        } else if let focusedItem {
            title = "聚焦 Payload 安全"
            status = focusedItem.reviewTitle
            guidance = "\(focusedItem.reviewTitle)：\(focusedItem.guidance)"
            icon = focusedItem.icon
        } else if hasMetadataGap {
            title = "Payload 安全账本"
            status = "\(metadataPendingCount) 项 metadata 待同步"
            guidance = primaryItem.map { "先确认 \($0.reviewTitle) 的 metadata，再判断 payload 边界。" } ?? "等待 metadata 后再判断 payload 边界。"
            icon = "doc.badge.clock"
        } else if payloadNotReadCount == items.count {
            title = "Payload 安全账本"
            status = "\(payloadNotReadCount)/\(items.count) 项未读取 payload"
            guidance = "当前复核只使用 metadata；artifact reference 和 payload 内容不会在手机端打开。"
            icon = "lock.doc"
        } else {
            title = "Payload 安全账本"
            status = "\(payloadNotReadCount)/\(items.count) 项声明未读取 payload"
            guidance = primaryItem.map { "抽查 \($0.reviewTitle) 的安全 flag，确认 metadata-only 边界。" } ?? "抽查安全 flag，确认 metadata-only 边界。"
            icon = "lock.doc"
        }

        return ClawMissionRunPayloadSafetyLedgerSummary(
            title: title,
            status: status,
            guidance: guidance,
            icon: icon,
            totalCount: items.count,
            payloadNotReadCount: payloadNotReadCount,
            metadataOnlyCount: metadataOnlyCount,
            omissionSignalCount: omissionSignalCount,
            metadataPendingCount: metadataPendingCount,
            focusedReviewKind: focusedItem?.reviewKind,
            focusedReviewTitle: focusedItem?.reviewTitle,
            primaryReviewKind: primaryItem?.reviewKind,
            primaryReviewTitle: primaryItem?.reviewTitle,
            canFocusPrimaryReview: primaryItem?.canFocusReview ?? false,
            hasMetadataGap: hasMetadataGap,
            isReviewable: isReviewable,
            items: items
        )
    }

    var macAgentReadinessBoard: ClawMissionRunMacAgentReadinessBoard {
        macAgentReadinessBoard(focusedOn: nil)
    }

    var macGatewayActionPreflightMatrix: ClawMissionRunActionPreflightMatrix {
        macGatewayActionPreflightMatrix(focusedOn: nil)
    }

    func macGatewayActionPreflightMatrix(focusedOn reviewKind: String?) -> ClawMissionRunActionPreflightMatrix {
        let focusedKind = activeReviewFocus(from: reviewKind)
        let items = actionPreflightItems.map { item in
            ClawMissionRunActionPreflightItem(
                id: item.id,
                rank: item.rank,
                title: item.title,
                actionKindTitle: item.actionKindTitle,
                approvalTitle: item.approvalTitle,
                status: item.status,
                guidance: item.guidance,
                icon: item.icon,
                tone: item.tone,
                reviewKind: item.reviewKind,
                reviewTitle: item.reviewTitle,
                canFocusReview: item.canFocusReview,
                isFocused: item.reviewKind != nil && item.reviewKind == focusedKind,
                hasStructuredArguments: item.hasStructuredArguments,
                hasResult: item.hasResult,
                hasMetadata: item.hasMetadata,
                isReady: item.isReady,
                isBlocked: item.isBlocked,
                isDegraded: item.isDegraded,
                requiresHumanAction: item.requiresHumanAction,
                isRetryable: item.isRetryable
            )
        }
        let focusedItem = items.first { item in
            item.reviewKind != nil && item.reviewKind == focusedKind
        }
        let primaryItem = focusedItem ??
            items.first(where: \.isBlocked) ??
            items.first(where: \.requiresHumanAction) ??
            items.first(where: \.isDegraded) ??
            items.first(where: { $0.hasResult && $0.hasMetadata == false }) ??
            items.first
        let readyCount = items.filter(\.isReady).count
        let blockedCount = items.filter(\.isBlocked).count
        let degradedCount = items.filter(\.isDegraded).count
        let humanActionCount = items.filter(\.requiresHumanAction).count
        let metadataPendingCount = items.filter { $0.hasResult && $0.hasMetadata == false }.count
        let isReviewable = items.isEmpty == false
        let requiresHumanAction = humanActionCount > 0 || requiresUserApproval
        let hasMetadataGap = metadataPendingCount > 0

        let title: String
        let status: String
        let guidance: String
        let icon: String
        if isReviewable == false {
            title = "Action 预检矩阵待生成"
            status = "尚无 Claw 电脑任务"
            guidance = "生成任务后会按 action 汇总结构化参数、审批、Gateway 结果和 metadata 状态。"
            icon = "list.bullet.rectangle"
        } else if let focusedItem {
            title = "聚焦 Action 预检"
            status = focusedItem.title
            guidance = "\(focusedItem.title)：\(focusedItem.guidance)"
            icon = focusedItem.icon
        } else if blockedCount > 0 {
            title = "Action 预检存在阻断"
            status = "\(blockedCount) 项阻断 · \(humanActionCount) 项需人工"
            guidance = primaryItem.map { "先看 \($0.title)：\($0.guidance)" } ?? "先处理阻断 action。"
            icon = "list.bullet.rectangle.portrait.fill"
        } else if requiresHumanAction {
            title = "Action 预检等待人工"
            status = "\(humanActionCount) 项需人工 · \(readyCount)/\(items.count) 可派发"
            guidance = primaryItem.map { "先确认 \($0.title)：\($0.guidance)" } ?? "先处理人工确认 action。"
            icon = "person.crop.circle.badge.checkmark"
        } else if hasMetadataGap {
            title = "Action 预检 metadata 待同步"
            status = "\(metadataPendingCount) 项待同步 · \(readyCount)/\(items.count) 可派发"
            guidance = primaryItem.map { "等待 \($0.title) metadata 后再复核结果。" } ?? "等待 Gateway metadata 后再复核 action 结果。"
            icon = "doc.badge.clock"
        } else if degradedCount > 0 {
            title = "Action 预检需抽查"
            status = "\(degradedCount) 项降级 · \(readyCount)/\(items.count) 可派发"
            guidance = primaryItem.map { "抽查 \($0.title)：\($0.guidance)" } ?? "抽查降级 action。"
            icon = "exclamationmark.magnifyingglass"
        } else {
            title = "Action 预检矩阵"
            status = "\(readyCount)/\(items.count) 项可派发"
            guidance = "所有 action 只展示结构化预检状态；仍需用户明确发送或继续。"
            icon = "list.bullet.rectangle"
        }

        return ClawMissionRunActionPreflightMatrix(
            title: title,
            status: status,
            guidance: guidance,
            icon: icon,
            totalCount: items.count,
            readyCount: readyCount,
            blockedCount: blockedCount,
            degradedCount: degradedCount,
            humanActionCount: humanActionCount,
            metadataPendingCount: metadataPendingCount,
            focusedItemID: focusedItem?.id,
            focusedReviewKind: focusedItem?.reviewKind,
            focusedReviewTitle: focusedItem?.reviewTitle,
            primaryReviewKind: primaryItem?.reviewKind,
            primaryReviewTitle: primaryItem?.reviewTitle,
            canFocusPrimaryReview: primaryItem?.canFocusReview ?? false,
            requiresHumanAction: requiresHumanAction,
            hasMetadataGap: hasMetadataGap,
            isReviewable: isReviewable,
            items: items
        )
    }

    var macAgentEvidenceCoverageMap: ClawMissionRunEvidenceCoverageMap {
        macAgentEvidenceCoverageMap(focusedOn: nil)
    }

    func macAgentEvidenceCoverageMap(focusedOn reviewKind: String?) -> ClawMissionRunEvidenceCoverageMap {
        let focusedKind = activeReviewFocus(from: reviewKind)
        let evidenceIndex = artifactEvidenceIndex(focusedOn: focusedKind)
        let payloadLedger = payloadSafetyLedger(focusedOn: focusedKind)
        let actionPreflight = macGatewayActionPreflightMatrix(focusedOn: focusedKind)
        let reviewKinds = evidenceCoverageReviewKinds(
            evidenceIndex: evidenceIndex,
            actionPreflight: actionPreflight
        )
        let items = reviewKinds.map { kind in
            evidenceCoverageItem(
                for: kind,
                focusedOn: focusedKind,
                evidenceIndex: evidenceIndex,
                payloadLedger: payloadLedger,
                actionPreflight: actionPreflight
            )
        }
        let actionSupportedCount = items.filter(\.hasActionSupport).count
        let evidenceCoveredCount = items.filter(\.hasEvidence).count
        let metadataReadyCount = items.filter(\.hasMetadata).count
        let payloadProtectedCount = items.filter(\.payloadProtected).count
        let humanActionCount = items.filter(\.requiresHumanAction).count
        let metadataPendingCount = items.filter(\.hasMetadataGap).count
        let focusedItem = focusedKind.flatMap { kind in
            items.first { $0.reviewKind == kind }
        }
        let primaryItem = focusedItem ??
            items.first(where: \.requiresHumanAction) ??
            items.first(where: \.hasMetadataGap) ??
            items.first(where: { $0.hasEvidence == false }) ??
            items.first
        let isReviewable = items.isEmpty == false
        let readiness = reviewReadinessSummary(focusedOn: focusedKind)
        let requiresHumanAction = humanActionCount > 0 || readiness.requiresHumanAction
        let hasMetadataGap = metadataPendingCount > 0

        let title: String
        let status: String
        let guidance: String
        let icon: String
        if isReviewable == false {
            title = "Evidence Coverage 待生成"
            status = "尚无 action 或 Gateway 证据"
            guidance = "生成任务后会按复核域汇总 action、artifact、metadata 和 payload 边界。"
            icon = "rectangle.stack.badge.play"
        } else if let focusedItem {
            title = "聚焦 Evidence Coverage"
            status = focusedItem.reviewTitle
            guidance = "\(focusedItem.reviewTitle)：\(focusedItem.guidance)"
            icon = focusedItem.icon
        } else if requiresHumanAction {
            title = "Evidence Coverage 需人工复核"
            status = "\(humanActionCount) 项需人工 · \(evidenceCoveredCount)/\(items.count) 类有证据"
            guidance = primaryItem.map { "先看 \($0.reviewTitle)：\($0.guidance)" } ?? "先处理需要人工复核的证据域。"
            icon = "person.crop.circle.badge.exclamationmark.fill"
        } else if hasMetadataGap {
            title = "Evidence Coverage metadata 待同步"
            status = "\(metadataPendingCount) 项 metadata 待同步"
            guidance = primaryItem.map { "等待 \($0.reviewTitle) metadata 后再判断覆盖。" } ?? "等待 Gateway metadata 后再判断覆盖。"
            icon = "doc.badge.clock"
        } else if evidenceCoveredCount == items.count {
            title = "Evidence Coverage 已覆盖"
            status = "\(evidenceCoveredCount)/\(items.count) 类证据可复核"
            guidance = "证据覆盖图只汇总安全 metadata，不打开 artifact payload。"
            icon = "checkmark.seal.fill"
        } else {
            title = "Evidence Coverage 可抽查"
            status = "\(evidenceCoveredCount)/\(items.count) 类证据可复核"
            guidance = primaryItem.map { "抽查 \($0.reviewTitle)：\($0.guidance)" } ?? "抽查缺少证据的复核域。"
            icon = "rectangle.stack.badge.play"
        }

        return ClawMissionRunEvidenceCoverageMap(
            title: title,
            status: status,
            guidance: guidance,
            icon: icon,
            totalCount: items.count,
            actionSupportedCount: actionSupportedCount,
            evidenceCoveredCount: evidenceCoveredCount,
            metadataReadyCount: metadataReadyCount,
            payloadProtectedCount: payloadProtectedCount,
            humanActionCount: humanActionCount,
            metadataPendingCount: metadataPendingCount,
            focusedReviewKind: focusedItem?.reviewKind,
            focusedReviewTitle: focusedItem?.reviewTitle,
            primaryReviewKind: primaryItem?.reviewKind,
            primaryReviewTitle: primaryItem?.reviewTitle,
            canFocusPrimaryReview: primaryItem?.canFocusReview ?? false,
            requiresHumanAction: requiresHumanAction,
            hasMetadataGap: hasMetadataGap,
            isReviewable: isReviewable,
            items: items
        )
    }

    private func evidenceCoverageReviewKinds(
        evidenceIndex: ClawMissionRunArtifactEvidenceIndex,
        actionPreflight: ClawMissionRunActionPreflightMatrix
    ) -> [String] {
        var seen: Set<String> = []
        var kinds: [String] = []

        func append(_ kind: String?) {
            guard let kind, seen.insert(kind).inserted else {
                return
            }
            kinds.append(kind)
        }

        for item in actionPreflight.items {
            append(item.reviewKind)
        }
        for item in evidenceIndex.items {
            append(item.reviewKind)
        }
        for item in reviewPriorityQueue {
            append(item.reviewKind)
        }

        return kinds
    }

    private func evidenceCoverageItem(
        for reviewKind: String,
        focusedOn focusedKind: String?,
        evidenceIndex: ClawMissionRunArtifactEvidenceIndex,
        payloadLedger: ClawMissionRunPayloadSafetyLedgerSummary,
        actionPreflight: ClawMissionRunActionPreflightMatrix
    ) -> ClawMissionRunEvidenceCoverageItem {
        let actions = actionPreflight.items.filter { $0.reviewKind == reviewKind }
        let evidenceItem = evidenceIndex.items.first { $0.reviewKind == reviewKind }
        let payloadItem = payloadLedger.items.first { $0.reviewKind == reviewKind }
        let priorityItems = reviewPriorityQueue.filter { $0.reviewKind == reviewKind }

        let hasActionSupport = actions.isEmpty == false
        let hasEvidence = evidenceItem?.hasEvidence ?? false
        let hasMetadata = evidenceItem?.metadataReady == true ||
            payloadItem?.hasMetadata == true ||
            priorityItems.contains(where: \.hasMetadata) ||
            actions.contains(where: \.hasMetadata)
        let payloadProtected = payloadItem.map { item in
            item.payloadNotRead || item.metadataOnly || item.omissionSignalCount > 0
        } ?? false
        let requiresHumanAction = actions.contains(where: \.requiresHumanAction) ||
            priorityItems.contains { item in
                item.isActionable || item.severity == .critical || item.severity == .high
            }
        let hasMetadataGap = hasMetadata == false &&
            (hasEvidence || hasActionSupport || priorityItems.isEmpty == false)
        let title = evidenceCoverageTitle(
            for: reviewKind,
            evidenceItem: evidenceItem,
            payloadItem: payloadItem,
            actionItems: actions
        )
        let icon = evidenceCoverageIcon(
            for: reviewKind,
            evidenceItem: evidenceItem,
            actionItems: actions
        )
        let tone: ClawMissionRunOperatorLaneTone
        let status: String
        let guidance: String

        if requiresHumanAction {
            tone = .warning
            status = "人工复核"
            guidance = hasEvidence ? "已有证据支撑，仍需人工确认该复核域。" : "已有 action 或状态项，但 Gateway 证据仍待同步。"
        } else if hasMetadataGap {
            tone = .info
            status = "metadata 待同步"
            guidance = hasActionSupport ? "action 已出现，等待 Gateway metadata 后再判断覆盖。" : "等待 metadata 后再判断该复核域。"
        } else if hasEvidence && payloadProtected {
            tone = .success
            status = "证据覆盖 · payload 受控"
            guidance = "artifact 和 metadata 已可复核，payload 边界由安全 flag 汇总。"
        } else if hasEvidence {
            tone = .success
            status = "证据覆盖"
            guidance = "已有 artifact 或安全 metadata 可支撑该复核域。"
        } else if hasActionSupport {
            tone = .info
            status = "等待 Gateway 证据"
            guidance = "action 已预检，发送或执行后等待对应 artifact/metadata。"
        } else {
            tone = .neutral
            status = "证据待同步"
            guidance = "尚未看到 action、artifact 或 metadata 支撑。"
        }

        return ClawMissionRunEvidenceCoverageItem(
            reviewKind: reviewKind,
            reviewTitle: title,
            status: status,
            guidance: guidance,
            icon: icon,
            tone: tone,
            actionCount: actions.count,
            hasActionSupport: hasActionSupport,
            hasEvidence: hasEvidence,
            hasMetadata: hasMetadata,
            payloadProtected: payloadProtected,
            requiresHumanAction: requiresHumanAction,
            hasMetadataGap: hasMetadataGap,
            canFocusReview: focusUsesDetailReview(reviewKind) ||
                reviewPriorityQueue.contains { $0.reviewKind == reviewKind } ||
                actionPreflight.items.contains { $0.reviewKind == reviewKind && $0.canFocusReview },
            isFocused: reviewKind == focusedKind
        )
    }

    private func evidenceCoverageTitle(
        for reviewKind: String,
        evidenceItem: ClawMissionRunArtifactEvidenceItem?,
        payloadItem: ClawMissionRunPayloadSafetyLedgerItem?,
        actionItems: [ClawMissionRunActionPreflightItem]
    ) -> String {
        if let reviewTitle = evidenceItem?.reviewTitle ?? payloadItem?.reviewTitle ?? actionItems.first?.reviewTitle {
            return reviewTitle
        }
        if let priorityTitle = reviewPriorityQueue.first(where: { $0.reviewKind == reviewKind })?.title {
            return priorityTitle
        }
        switch reviewKind {
        case "approval":
            return "手机审批"
        case "gateway-status":
            return "Gateway 状态"
        default:
            return Self.title(forDetailReviewKind: reviewKind)
        }
    }

    private func evidenceCoverageIcon(
        for reviewKind: String,
        evidenceItem: ClawMissionRunArtifactEvidenceItem?,
        actionItems: [ClawMissionRunActionPreflightItem]
    ) -> String {
        if let icon = evidenceItem?.icon ?? actionItems.first?.icon {
            return icon
        }
        switch reviewKind {
        case "approval":
            return "checkmark.seal.fill"
        case "gateway-status":
            return "server.rack"
        default:
            return Self.icon(forDetailReviewKind: reviewKind)
        }
    }

    func macAgentReadinessBoard(focusedOn reviewKind: String?) -> ClawMissionRunMacAgentReadinessBoard {
        let focusedKind = activeReviewFocus(from: reviewKind)
        let loop = loopContinuationSummary(focusedOn: focusedKind)
        let readiness = reviewReadinessSummary(focusedOn: focusedKind)
        let approval = approvalQueueSummary(focusedOn: focusedKind)
        let items = macAgentReadinessItems(
            focusedOn: focusedKind,
            loop: loop,
            readiness: readiness,
            approval: approval
        )
        let focusedItem = items.first { item in
            item.reviewKind != nil && item.reviewKind == focusedKind
        }
        let primaryItem = focusedItem ??
            items.first(where: \.isBlocked) ??
            items.first(where: \.requiresHumanAction) ??
            items.first(where: \.hasMetadataGap) ??
            items.first(where: { $0.isReady == false }) ??
            items.first
        let readyCount = items.filter(\.isReady).count
        let blockedCount = items.filter(\.isBlocked).count
        let metadataPendingCount = items.filter(\.hasMetadataGap).count
        let humanActionCount = items.filter(\.requiresHumanAction).count
        let isReviewable = artifactCount > 0 ||
            gatewayCapabilityReview != nil ||
            gatewayAccessibilityReview != nil ||
            agentTraceReview != nil ||
            reviewPriorityQueue.isEmpty == false ||
            approval.items.isEmpty == false
        let hasMetadataGap = metadataPendingCount > 0
        let requiresHumanAction = humanActionCount > 0 || readiness.requiresHumanAction || approval.requiresHumanAction

        let title: String
        let status: String
        let guidance: String
        let icon: String
        if isReviewable == false {
            title = "Mac Agent 就绪待生成"
            status = "尚无 Gateway 证据"
            guidance = "发送任务后会汇总连接、能力、观察、Loop 和人工闸门。"
            icon = "desktopcomputer"
        } else if let focusedItem {
            title = "聚焦 Mac Agent 就绪"
            status = focusedItem.title
            guidance = "\(focusedItem.title)：\(focusedItem.guidance)"
            icon = focusedItem.icon
        } else if blockedCount > 0 {
            title = "Mac Agent 就绪阻断"
            status = "\(blockedCount) 项阻断 · \(humanActionCount) 项需人工"
            guidance = primaryItem.map { "先看 \($0.title)：\($0.guidance)" } ?? "先处理阻断项。"
            icon = "desktopcomputer.trianglebadge.exclamationmark"
        } else if requiresHumanAction {
            title = "Mac Agent 等待人工确认"
            status = "\(humanActionCount) 项需人工 · \(readyCount)/\(items.count) 就绪"
            guidance = primaryItem.map { "先确认 \($0.title)：\($0.guidance)" } ?? "先处理人工确认项。"
            icon = "person.crop.circle.badge.checkmark"
        } else if hasMetadataGap {
            title = "Mac Agent metadata 待同步"
            status = "\(metadataPendingCount) 项待同步 · \(readyCount)/\(items.count) 就绪"
            guidance = primaryItem.map { "等待 \($0.title) metadata 后再判断桌面就绪。" } ?? "等待 Gateway metadata 后再判断桌面就绪。"
            icon = "doc.badge.clock"
        } else if loop.canContinueLoop {
            title = "Mac Agent 可继续"
            status = "\(readyCount)/\(items.count) 项就绪"
            guidance = "能力、观察和 Loop 条件已满足；仍需用户明确触发下一轮。"
            icon = "desktopcomputer.and.arrow.down"
        } else {
            title = "Mac Agent 就绪看板"
            status = "\(readyCount)/\(items.count) 项就绪"
            guidance = primaryItem.map { "可从 \($0.title) 开始复核。" } ?? "可继续抽查 Gateway readiness。"
            icon = "desktopcomputer"
        }

        return ClawMissionRunMacAgentReadinessBoard(
            title: title,
            status: status,
            guidance: guidance,
            icon: icon,
            readyCount: readyCount,
            blockedCount: blockedCount,
            metadataPendingCount: metadataPendingCount,
            humanActionCount: humanActionCount,
            focusedItemID: focusedItem?.id,
            focusedReviewKind: focusedItem?.reviewKind,
            focusedReviewTitle: focusedItem?.reviewTitle,
            primaryReviewKind: primaryItem?.reviewKind,
            primaryReviewTitle: primaryItem?.reviewTitle,
            canFocusPrimaryReview: primaryItem?.canFocusReview ?? false,
            canContinueLoop: loop.canContinueLoop,
            requiresHumanAction: requiresHumanAction,
            hasMetadataGap: hasMetadataGap,
            isReviewable: isReviewable,
            items: items
        )
    }

    private func macAgentReadinessItems(
        focusedOn focusedKind: String?,
        loop: ClawMissionRunLoopContinuationSummary,
        readiness: ClawMissionRunReviewReadinessSummary,
        approval: ClawMissionRunApprovalQueueSummary
    ) -> [ClawMissionRunMacAgentReadinessItem] {
        [
            macAgentConnectionItem(focusedOn: focusedKind),
            macAgentCapabilityItem(focusedOn: focusedKind),
            macAgentObservationItem(focusedOn: focusedKind),
            macAgentLoopItem(focusedOn: focusedKind, loop: loop),
            macAgentHumanGateItem(focusedOn: focusedKind, readiness: readiness, approval: approval)
        ]
    }

    private func macAgentConnectionItem(focusedOn focusedKind: String?) -> ClawMissionRunMacAgentReadinessItem {
        let hasGatewayEvidence = artifactCount > 0 || succeededCount > 0 || failedCount > 0 || gatewayCapabilityReview != nil
        let isBlocked = hasGatewayEvidence && (failedCount > 0 || blockedCount > 0)
        let status: String
        let guidance: String
        let tone: ClawMissionRunOperatorLaneTone
        if isBlocked {
            status = "\(failedCount) 失败 · \(blockedCount) 阻断"
            guidance = "先复核失败或阻断结果，再决定重试或下一轮。"
            tone = .danger
        } else if hasGatewayEvidence {
            status = "\(artifactCount) 个 artifact · \(succeededCount) 成功"
            guidance = "Gateway 已回传事件和 artifact，可继续核对能力与观察证据。"
            tone = .success
        } else {
            status = "等待 Gateway 事件"
            guidance = "尚未看到桌面 Gateway 回传；发送任务后再判断连接就绪。"
            tone = .neutral
        }
        return ClawMissionRunMacAgentReadinessItem(
            id: "connection",
            title: "连接回执",
            status: status,
            guidance: guidance,
            icon: isBlocked ? "network.slash" : "network",
            tone: tone,
            reviewKind: nil,
            reviewTitle: nil,
            canFocusReview: false,
            isFocused: false,
            isReady: hasGatewayEvidence && isBlocked == false,
            isBlocked: isBlocked,
            hasMetadataGap: false,
            requiresHumanAction: isBlocked
        )
    }

    private func macAgentCapabilityItem(focusedOn focusedKind: String?) -> ClawMissionRunMacAgentReadinessItem {
        let reviewKind = "gateway-capability"
        let reviewTitle = Self.title(forDetailReviewKind: reviewKind)
        guard let review = gatewayCapabilityReview else {
            return ClawMissionRunMacAgentReadinessItem(
                id: "capability",
                title: "桌面能力",
                status: "能力快照待同步",
                guidance: "等待 Gateway capability snapshot 后确认 workspace、Shell、浏览器和桌面控制策略。",
                icon: Self.icon(forDetailReviewKind: reviewKind),
                tone: .neutral,
                reviewKind: nil,
                reviewTitle: nil,
                canFocusReview: false,
                isFocused: false,
                isReady: false,
                isBlocked: false,
                hasMetadataGap: false,
                requiresHumanAction: false
            )
        }
        let states = [
            review.workspaceState,
            review.shellState,
            review.browserControlState,
            review.screenCaptureState,
            review.windowMetadataState,
            review.accessibilityTreeState,
            review.desktopControlState
        ].compactMap { $0 }
        let unavailableCount = states.filter { state in
            state == "unavailable" || state == "disabled" || state == "blocked"
        }.count
        let hasMetadataGap = review.hasMetadata == false
        let isBlocked = unavailableCount > 0
        let canFocus = focusUsesDetailReview(reviewKind)
        return ClawMissionRunMacAgentReadinessItem(
            id: "capability",
            title: "桌面能力",
            status: hasMetadataGap ? "metadata 待同步" : review.compactStatus,
            guidance: isBlocked ? "\(unavailableCount) 项能力不可用；先查看 Gateway 能力复核。" : "已收到 Gateway 能力快照，可复核执行面是否符合策略。",
            icon: Self.icon(forDetailReviewKind: reviewKind),
            tone: hasMetadataGap ? .info : (isBlocked ? .warning : .success),
            reviewKind: reviewKind,
            reviewTitle: reviewTitle,
            canFocusReview: canFocus,
            isFocused: focusedKind == reviewKind,
            isReady: review.hasMetadata && isBlocked == false,
            isBlocked: isBlocked,
            hasMetadataGap: hasMetadataGap,
            requiresHumanAction: isBlocked || hasMetadataGap
        )
    }

    private func macAgentObservationItem(focusedOn focusedKind: String?) -> ClawMissionRunMacAgentReadinessItem {
        let reviewKind = "accessibility"
        let reviewTitle = Self.title(forDetailReviewKind: reviewKind)
        guard let review = gatewayAccessibilityReview else {
            return ClawMissionRunMacAgentReadinessItem(
                id: "observation",
                title: "屏幕观察",
                status: "观察 metadata 待同步",
                guidance: "等待 observeScreen 或 Accessibility 摘要后判断可观察性。",
                icon: Self.icon(forDetailReviewKind: reviewKind),
                tone: .neutral,
                reviewKind: nil,
                reviewTitle: nil,
                canFocusReview: false,
                isFocused: false,
                isReady: false,
                isBlocked: false,
                hasMetadataGap: false,
                requiresHumanAction: false
            )
        }
        let mode = review.mode ?? ""
        let isBlocked = mode == "unavailable" || mode == "disabled" || mode == "failed"
        let hasMetadataGap = review.hasMetadata == false
        let hasObservation = (review.nodeCount ?? 0) > 0 || (review.candidateControlCount ?? 0) > 0 || review.includeAccessibilityTree == true
        let canFocus = focusUsesDetailReview(reviewKind)
        return ClawMissionRunMacAgentReadinessItem(
            id: "observation",
            title: "屏幕观察",
            status: hasMetadataGap ? "metadata 待同步" : review.compactStatus,
            guidance: isBlocked ? "观察能力不可用；先查看 Accessibility 复核。" : "已收到观察摘要，可判断屏幕和候选控件证据质量。",
            icon: Self.icon(forDetailReviewKind: reviewKind),
            tone: hasMetadataGap ? .info : (isBlocked ? .warning : .success),
            reviewKind: reviewKind,
            reviewTitle: reviewTitle,
            canFocusReview: canFocus,
            isFocused: focusedKind == reviewKind,
            isReady: review.hasMetadata && hasObservation && isBlocked == false,
            isBlocked: isBlocked,
            hasMetadataGap: hasMetadataGap,
            requiresHumanAction: isBlocked || hasMetadataGap
        )
    }

    private func macAgentLoopItem(
        focusedOn focusedKind: String?,
        loop: ClawMissionRunLoopContinuationSummary
    ) -> ClawMissionRunMacAgentReadinessItem {
        let reviewKind = "agent-trace"
        let reviewTitle = Self.title(forDetailReviewKind: reviewKind)
        let hasTrace = agentTraceReview != nil
        let canFocus = loop.canFocusAgentTrace && focusUsesDetailReview(reviewKind)
        let isBlocked = loop.handoffStatus == "blocked" || (hasTrace && loop.missingSignalCount > 0)
        return ClawMissionRunMacAgentReadinessItem(
            id: "loop",
            title: "Loop 继续",
            status: hasTrace ? loop.status : "AgentTrace 待生成",
            guidance: hasTrace ? loop.guidance : "运行 agent loop 后会显示证据分、下一步和交接状态。",
            icon: loop.icon,
            tone: loop.hasMetadataGap ? .info : (isBlocked ? .warning : (loop.canContinueLoop ? .success : .neutral)),
            reviewKind: hasTrace ? reviewKind : nil,
            reviewTitle: hasTrace ? reviewTitle : nil,
            canFocusReview: canFocus,
            isFocused: focusedKind == reviewKind,
            isReady: loop.canContinueLoop || loop.handoffStatus == "complete",
            isBlocked: isBlocked,
            hasMetadataGap: loop.hasMetadataGap,
            requiresHumanAction: loop.requiresHumanAction
        )
    }

    private func macAgentHumanGateItem(
        focusedOn focusedKind: String?,
        readiness: ClawMissionRunReviewReadinessSummary,
        approval: ClawMissionRunApprovalQueueSummary
    ) -> ClawMissionRunMacAgentReadinessItem {
        let focusedPriority = reviewPriorityItem(focusedOn: focusedKind)
        let candidateKind = focusedKind ?? approval.primaryReviewKind ?? readiness.topReviewKind
        let candidateTitle = focusedPriority?.title ?? approval.primaryReviewTitle ?? readiness.topReviewTitle ?? candidateKind.map(Self.title(forDetailReviewKind:))
        let canFocus = candidateKind.map { kind in
            focusUsesDetailReview(kind) || reviewPriorityQueue.contains { $0.reviewKind == kind }
        } ?? false
        let hasMetadataGap = readiness.metadataPendingCount > 0 || approval.hasMetadataGap
        let hasGateEvidence = readiness.isReviewable || approval.isReviewable || reviewPriorityQueue.isEmpty == false
        let requiresHumanAction = hasGateEvidence && (readiness.requiresHumanAction || approval.requiresHumanAction || requiresUserApproval)
        let status: String
        let guidance: String
        let tone: ClawMissionRunOperatorLaneTone
        if requiresHumanAction {
            status = "\(readiness.actionablePriorityCount) 项可行动 · \(approval.actionableCount) 项审批"
            guidance = candidateTitle.map { "先确认 \($0)，再决定审批、重试或下一轮。" } ?? "先处理人工确认点。"
            tone = .warning
        } else if hasMetadataGap {
            status = "\(readiness.metadataPendingCount) 项 metadata 待同步"
            guidance = "等待 metadata 完整后再判断是否可继续。"
            tone = .info
        } else if readiness.isReviewable || approval.isReviewable {
            status = "人工闸门已清点"
            guidance = "当前无可行动确认项；仍需用户明确触发下一轮。"
            tone = .success
        } else {
            status = "等待复核队列"
            guidance = "发送任务后会汇总审批、阻断和下一步确认点。"
            tone = .neutral
        }
        return ClawMissionRunMacAgentReadinessItem(
            id: "human-gate",
            title: "人工闸门",
            status: status,
            guidance: guidance,
            icon: "person.crop.circle.badge.checkmark",
            tone: tone,
            reviewKind: candidateKind,
            reviewTitle: candidateTitle,
            canFocusReview: canFocus,
            isFocused: candidateKind != nil && candidateKind == focusedKind,
            isReady: (readiness.isReviewable || approval.isReviewable) && requiresHumanAction == false && hasMetadataGap == false,
            isBlocked: false,
            hasMetadataGap: hasMetadataGap,
            requiresHumanAction: requiresHumanAction
        )
    }

    var focusContextSummary: ClawMissionRunFocusContextSummary {
        focusContextSummary(focusedOn: nil)
    }

    func focusContextSummary(focusedOn reviewKind: String?) -> ClawMissionRunFocusContextSummary {
        let priorityItem = reviewPriorityItem(focusedOn: reviewKind)
        let detailFocused = focusUsesDetailReview(reviewKind)
        let isKnownFocus = priorityItem != nil || detailFocused
        let activeFocus = isKnownFocus ? reviewKind : nil
        let readiness = reviewReadinessSummary(focusedOn: activeFocus)
        let next = nextReviewAction(focusedOn: activeFocus)
        let evidence = artifactEvidenceIndex(focusedOn: activeFocus)
        let focusedEvidenceItem = activeFocus.flatMap { kind in
            evidence.items.first { $0.reviewKind == kind }
        }

        if let priorityItem {
            let hasDetailReview = focusUsesDetailReview(priorityItem.reviewKind)
            let title = hasDetailReview ? "聚焦复核上下文" : "聚焦状态上下文"
            let guidance = hasDetailReview
                ? "当前只显示 \(priorityItem.title) 详细复核；可清除聚焦恢复全量。"
                : "\(priorityItem.title) 是状态或审批项；详细复核保持全量显示。"
            return ClawMissionRunFocusContextSummary(
                title: title,
                status: priorityItem.status,
                guidance: guidance,
                icon: priorityItem.icon,
                focusedReviewKind: priorityItem.reviewKind,
                focusedReviewTitle: priorityItem.title,
                primaryReviewKind: hasDetailReview ? priorityItem.reviewKind : nil,
                primaryButtonTitle: hasDetailReview ? "查看 \(priorityItem.title) 详情" : nil,
                canFocusDetailReview: hasDetailReview,
                canClearFocus: true,
                hasEvidence: focusedEvidenceItem?.hasEvidence ?? false,
                hasMetadataGap: priorityItem.hasMetadata == false || focusedEvidenceItem?.metadataReady == false,
                requiresHumanAction: priorityItem.isActionable || readiness.requiresHumanAction,
                isReviewable: true
            )
        }

        if let reviewKind, detailFocused {
            let detailTitle = Self.title(forDetailReviewKind: reviewKind)
            let evidenceItem = evidence.items.first { $0.reviewKind == reviewKind }
            return ClawMissionRunFocusContextSummary(
                title: "聚焦详细复核",
                status: detailTitle,
                guidance: "当前只显示 \(detailTitle) 安全摘要；可清除聚焦恢复全量。",
                icon: Self.icon(forDetailReviewKind: reviewKind),
                focusedReviewKind: reviewKind,
                focusedReviewTitle: detailTitle,
                primaryReviewKind: reviewKind,
                primaryButtonTitle: "查看 \(detailTitle) 详情",
                canFocusDetailReview: true,
                canClearFocus: true,
                hasEvidence: evidenceItem?.hasEvidence ?? false,
                hasMetadataGap: evidenceItem?.metadataReady == false,
                requiresHumanAction: readiness.requiresHumanAction,
                isReviewable: true
            )
        }

        if reviewKind != nil {
            return ClawMissionRunFocusContextSummary(
                title: "聚焦已更新",
                status: "复核项不在当前队列",
                guidance: "当前保留全量详情；可清除聚焦后重新选择复核项。",
                icon: "scope",
                focusedReviewKind: nil,
                focusedReviewTitle: nil,
                primaryReviewKind: nil,
                primaryButtonTitle: nil,
                canFocusDetailReview: false,
                canClearFocus: true,
                hasEvidence: false,
                hasMetadataGap: readiness.metadataPendingCount > 0,
                requiresHumanAction: readiness.requiresHumanAction,
                isReviewable: readiness.isReviewable
            )
        }

        guard readiness.isReviewable else {
            return ClawMissionRunFocusContextSummary(
                title: "聚焦上下文待生成",
                status: "尚无 Gateway 证据",
                guidance: "发送任务后可从复核优先队列选择聚焦项。",
                icon: "tray",
                focusedReviewKind: nil,
                focusedReviewTitle: nil,
                primaryReviewKind: nil,
                primaryButtonTitle: nil,
                canFocusDetailReview: false,
                canClearFocus: false,
                hasEvidence: false,
                hasMetadataGap: false,
                requiresHumanAction: false,
                isReviewable: false
            )
        }

        let primaryKind = next.canFocusDetailReview ? next.reviewKind : nil
        let primaryEvidenceItem = primaryKind.flatMap { kind in
            evidence.items.first { $0.reviewKind == kind }
        }
        return ClawMissionRunFocusContextSummary(
            title: "选择复核聚焦",
            status: "\(readiness.totalPriorityCount) 项复核 · \(readiness.availableDetailReviewCount) 类详情",
            guidance: next.reviewTitle.map { "建议先看 \($0)：\(next.actionHint ?? next.guidance)" } ?? readiness.guidance,
            icon: "scope",
            focusedReviewKind: nil,
            focusedReviewTitle: nil,
            primaryReviewKind: primaryKind,
            primaryButtonTitle: primaryKind == nil ? nil : next.primaryButtonTitle,
            canFocusDetailReview: primaryKind != nil,
            canClearFocus: false,
            hasEvidence: primaryEvidenceItem?.hasEvidence ?? false,
            hasMetadataGap: next.hasMetadataGap,
            requiresHumanAction: next.requiresHumanAction,
            isReviewable: true
        )
    }

    var loopContinuationSummary: ClawMissionRunLoopContinuationSummary {
        loopContinuationSummary(focusedOn: nil)
    }

    func loopContinuationSummary(focusedOn reviewKind: String?) -> ClawMissionRunLoopContinuationSummary {
        let focusKind = agentTraceReview == nil ? nil : "agent-trace"
        let canFocusAgentTrace = focusKind.map(focusUsesDetailReview) ?? false
        let isFocused = reviewKind == focusKind

        guard let review = agentTraceReview else {
            return ClawMissionRunLoopContinuationSummary(
                title: "Loop 继续态势待生成",
                status: "尚无 AgentTrace",
                guidance: "发送任务或运行 agent loop 后会显示继续条件。",
                icon: "point.topleft.down.curvedto.point.bottomright.up",
                handoffStatus: nil,
                readinessScore: nil,
                satisfiedSignalCount: 0,
                degradedSignalCount: 0,
                missingSignalCount: 0,
                selectedNextActionKind: nil,
                selectedNextActionRequiresApproval: false,
                focusReviewKind: nil,
                focusReviewTitle: nil,
                canFocusAgentTrace: false,
                canContinueLoop: false,
                requiresHumanAction: false,
                hasMetadataGap: false,
                isReviewable: false
            )
        }

        let hasMetadataGap = review.hasMetadata == false
        let selectedRequiresApproval = review.selectedNextActionRequiresApproval == true
        let hasEvidenceGap = review.missingSignals.isEmpty == false || review.degradedSignals.isEmpty == false
        let handoff = review.handoffStatus
        let canContinue = review.readinessCanContinue == true &&
            handoff == "ready-to-continue" &&
            selectedRequiresApproval == false &&
            hasEvidenceGap == false &&
            hasMetadataGap == false
        let requiresHumanAction = hasMetadataGap ||
            selectedRequiresApproval ||
            hasEvidenceGap ||
            review.needsHandoffReview ||
            blockedCount > 0 ||
            failedCount > 0 ||
            requiresUserApproval

        let title: String
        let status: String
        let guidance: String
        let icon: String

        if hasMetadataGap {
            title = "Loop metadata 待同步"
            status = "AgentTrace 已收到"
            guidance = "先聚焦 AgentTrace，确认 Gateway 是否提供了继续条件。"
            icon = "doc.badge.clock"
        } else if canContinue {
            title = "Loop 可继续"
            status = review.selectedNextActionKind.map { "下一步 \($0)" } ?? "下一步待定"
            guidance = isFocused ? "当前已聚焦 AgentTrace，可复核后由用户决定下一轮。" : "证据满足且无需审批；仍需用户明确触发下一轮。"
            icon = "arrow.forward.circle.fill"
        } else if handoff == "complete" {
            title = "Loop 已完成"
            status = review.readinessScore.map { "证据 \($0)/100" } ?? "证据已复核"
            guidance = "当前 AgentTrace 表示完成；可抽查摘要或开始新任务。"
            icon = "checkmark.circle.fill"
        } else if handoff == "blocked" {
            title = "Loop 已阻断"
            status = "需要人工处理"
            guidance = "先查看阻断原因和 AgentTrace 详情。"
            icon = "octagon.fill"
        } else if handoff == "final-submit-review" {
            title = "Loop 最终提交复核"
            status = review.selectedNextActionKind.map { "\($0) 停在提交前" } ?? "停在提交前"
            guidance = "最终提交必须由用户复核，不能自动发送或提交。"
            icon = "hand.raised.fill"
        } else if handoff == "waiting-for-approval" || selectedRequiresApproval {
            title = "Loop 等待审批"
            status = review.selectedNextActionKind.map { "\($0) 需确认" } ?? "下一步需确认"
            guidance = "先确认审批点和安全摘要，不能自动继续。"
            icon = "person.crop.circle.badge.checkmark"
        } else if handoff == "needs-evidence" || review.readinessCanContinue == false || hasEvidenceGap {
            title = "Loop 需要证据"
            status = "\(review.degradedSignals.count) 降级 · \(review.missingSignals.count) 缺失"
            guidance = "先补齐或复核降级证据，再决定下一轮。"
            icon = "tray.and.arrow.down.fill"
        } else {
            title = "Loop 继续态势"
            status = review.compactStatus
            guidance = "先查看 AgentTrace 摘要和下一步建议。"
            icon = "point.topleft.down.curvedto.point.bottomright.up"
        }

        return ClawMissionRunLoopContinuationSummary(
            title: title,
            status: status,
            guidance: guidance,
            icon: icon,
            handoffStatus: handoff,
            readinessScore: review.readinessScore,
            satisfiedSignalCount: review.satisfiedSignals.count,
            degradedSignalCount: review.degradedSignals.count,
            missingSignalCount: review.missingSignals.count,
            selectedNextActionKind: review.selectedNextActionKind,
            selectedNextActionRequiresApproval: selectedRequiresApproval,
            focusReviewKind: focusKind,
            focusReviewTitle: focusKind.map(Self.title(forDetailReviewKind:)),
            canFocusAgentTrace: canFocusAgentTrace,
            canContinueLoop: canContinue,
            requiresHumanAction: requiresHumanAction,
            hasMetadataGap: hasMetadataGap,
            isReviewable: true
        )
    }

    var artifactEvidenceIndex: ClawMissionRunArtifactEvidenceIndex {
        artifactEvidenceIndex(focusedOn: nil)
    }

    func artifactEvidenceIndex(focusedOn reviewKind: String?) -> ClawMissionRunArtifactEvidenceIndex {
        let availableKinds = availableDetailReviewKinds
        let focusedKind = reviewKind.flatMap { kind in
            availableKinds.contains(kind) || reviewPriorityQueue.contains { $0.reviewKind == kind } ? kind : nil
        }
        let items = availableKinds.map { detailReviewKind in
            artifactEvidenceItem(for: detailReviewKind, focusedOn: focusedKind)
        }
        let coveredCount = items.filter(\.hasEvidence).count
        let missingCount = max(items.count - coveredCount, 0)
        let metadataCount = artifactMetadataReview?.metadataArtifactCount ?? 0
        let redactedCount = artifactMetadataReview?.redactedArtifactCount ?? 0
        let focusedItem = focusedKind.flatMap { kind in
            items.first { $0.reviewKind == kind }
        }

        let title: String
        let status: String
        let guidance: String
        let icon: String
        if artifactKinds.isEmpty {
            title = "Artifact 证据待生成"
            status = "尚无 Gateway artifact"
            guidance = "发送任务后会索引证据类型和 metadata 覆盖。"
            icon = "tray"
        } else if missingCount > 0 {
            title = "Artifact 证据索引"
            status = "\(coveredCount)/\(items.count) 类复核有证据"
            guidance = "优先查看缺少证据或 metadata 的复核项。"
            icon = "paperclip.badge.ellipsis"
        } else {
            title = "Artifact 证据已覆盖"
            status = "\(artifactKinds.count) 类 artifact · metadata \(metadataCount)/\(artifactCount)"
            guidance = focusedItem.map { "当前聚焦 \($0.reviewTitle)：\($0.guidance)" } ?? "可继续查看复核态势和详细摘要。"
            icon = "checkmark.seal.fill"
        }

        return ClawMissionRunArtifactEvidenceIndex(
            title: title,
            status: status,
            guidance: guidance,
            icon: icon,
            artifactKindCount: artifactKinds.count,
            metadataArtifactCount: metadataCount,
            redactedArtifactCount: redactedCount,
            coveredReviewCount: coveredCount,
            missingReviewCount: missingCount,
            focusedReviewKind: focusedItem?.reviewKind,
            focusedReviewTitle: focusedItem?.reviewTitle,
            focusedHasEvidence: focusedItem?.hasEvidence ?? false,
            isReviewable: artifactKinds.isEmpty == false || items.isEmpty == false,
            items: items
        )
    }

    private func artifactEvidenceItem(
        for reviewKind: String,
        focusedOn focusedReviewKind: String?
    ) -> ClawMissionRunArtifactEvidenceItem {
        let expectedKinds = Self.evidenceArtifactKinds(for: reviewKind, availableArtifactKinds: artifactKinds)
        let matchingKinds = expectedKinds.filter { artifactKinds.contains($0) }
        let hasEvidence = matchingKinds.isEmpty == false || metadataReady(forDetailReviewKind: reviewKind)
        let metadataReady = metadataReady(forDetailReviewKind: reviewKind)
        let reviewTitle = Self.title(forDetailReviewKind: reviewKind)
        let status: String
        let guidance: String
        if hasEvidence {
            let kindTitles = (matchingKinds.isEmpty ? expectedKinds : matchingKinds)
                .prefix(3)
                .map(\.title)
                .joined(separator: "、")
            status = metadataReady ? "metadata 已覆盖" : "metadata 待同步"
            guidance = kindTitles.isEmpty ? "使用安全 metadata 作为复核证据。" : "证据类型：\(kindTitles)。"
        } else {
            status = "证据待同步"
            guidance = "尚未看到对应 artifact 类型。"
        }

        return ClawMissionRunArtifactEvidenceItem(
            reviewKind: reviewKind,
            reviewTitle: reviewTitle,
            status: status,
            guidance: guidance,
            icon: Self.icon(forDetailReviewKind: reviewKind),
            artifactKinds: matchingKinds.isEmpty ? expectedKinds : matchingKinds,
            hasEvidence: hasEvidence,
            metadataReady: metadataReady,
            isFocused: focusedReviewKind == reviewKind,
            canFocusReview: focusUsesDetailReview(reviewKind)
        )
    }

    private func metadataReady(forDetailReviewKind reviewKind: String) -> Bool {
        switch reviewKind {
        case "artifact-metadata":
            return artifactMetadataReview?.hasMetadata == true
        case "file-change-safety":
            return gatewayFileChangeSafetyReview?.hasMetadata == true
        case "shell-safety":
            return gatewayShellCommandSafetyReview?.hasMetadata == true
        case "extraction-completeness":
            return gatewayExtractionCompletenessReview?.hasMetadata == true
        case "browser-control":
            return gatewayBrowserControlReview?.hasMetadata == true
        case "delivery-safety":
            return gatewayDeliverySafetyReview?.hasMetadata == true
        case "gateway-capability":
            return gatewayCapabilityReview?.hasMetadata == true
        case "accessibility":
            return gatewayAccessibilityReview?.hasMetadata == true
        case "replay-guard":
            return gatewayTaskReplayGuardReview?.hasMetadata == true
        case "agent-trace":
            return agentTraceReview?.hasMetadata == true
        default:
            return false
        }
    }

    private func safetyFlags(forDetailReviewKind reviewKind: String) -> [String] {
        switch reviewKind {
        case "artifact-metadata":
            return artifactMetadataReview?.safetyFlags ?? []
        case "file-change-safety":
            return gatewayFileChangeSafetyReview?.safetyFlags ?? []
        case "shell-safety":
            return gatewayShellCommandSafetyReview?.safetyFlags ?? []
        case "extraction-completeness":
            return gatewayExtractionCompletenessReview?.safetyFlags ?? []
        case "browser-control":
            return gatewayBrowserControlReview?.safetyFlags ?? []
        case "delivery-safety":
            return gatewayDeliverySafetyReview?.safetyFlags ?? []
        case "gateway-capability":
            return gatewayCapabilityReview?.safetyFlags ?? []
        case "accessibility":
            return gatewayAccessibilityReview?.safetyFlags ?? []
        case "replay-guard":
            return gatewayTaskReplayGuardReview?.safetyFlags ?? []
        case "agent-trace":
            return agentTraceReview?.hasMetadata == true ? ["artifact-payload-not-read", "metadata-only"] : []
        default:
            return []
        }
    }

    private static func omissionSignalCount(in flags: [String]) -> Int {
        flags.filter { flag in
            flag.contains("omitted") ||
                flag.contains("redacted") ||
                flag.contains("gated") ||
                flag.contains("not-read")
        }.count
    }

    private static func payloadSafetyStatus(hasMetadata: Bool, flags: [String]) -> String {
        guard hasMetadata else {
            return "metadata 待同步"
        }
        if flags.contains("artifact-payload-not-read") {
            return flags.contains("metadata-only") ? "payload 未读取 · metadata-only" : "payload 未读取"
        }
        if flags.contains("metadata-only") {
            return "metadata-only 边界"
        }
        return "payload 边界待复核"
    }

    private static func payloadSafetyGuidance(hasMetadata: Bool, flags: [String]) -> String {
        guard hasMetadata else {
            return "等待 Gateway metadata 后再判断 payload 是否被读取。"
        }
        let omissionCount = omissionSignalCount(in: flags)
        if flags.contains("artifact-payload-not-read") {
            return omissionCount > 0
                ? "\(omissionCount) 个省略/保护信号；不打开 artifact reference。"
                : "声明未读取 payload；仅使用安全 metadata。"
        }
        if flags.contains("metadata-only") {
            return omissionCount > 0
                ? "\(omissionCount) 个省略/保护信号；继续按 metadata 复核。"
                : "只展示 metadata 摘要，不展示 payload 内容。"
        }
        return "未看到 payload-not-read flag；保持人工抽查。"
    }

    var evidenceTrailSummary: ClawMissionRunEvidenceTrailSummary {
        evidenceTrailSummary(focusedOn: nil)
    }

    func evidenceTrailSummary(focusedOn reviewKind: String?) -> ClawMissionRunEvidenceTrailSummary {
        let focusedKind = activeReviewFocus(from: reviewKind)
        let evidence = artifactEvidenceIndex(focusedOn: focusedKind)
        let readiness = reviewReadinessSummary(focusedOn: focusedKind)
        let next = nextReviewAction(focusedOn: focusedKind)
        let focusedTitle = focusedKind.flatMap { kind in
            reviewPriorityItem(focusedOn: kind)?.title ?? Self.title(forDetailReviewKind: kind)
        }
        let metadataTarget = reviewPriorityQueue.first { $0.hasMetadata == false }
        let topItem = reviewPriorityQueue.first
        let primaryReviewKind = next.reviewKind ?? topItem?.reviewKind
        let primaryReviewTitle = next.reviewTitle ?? topItem?.title
        let canFocusPrimary = primaryReviewKind.map(canFocusEvidenceTrailReviewKind) ?? false
        let hasMetadataGap = readiness.metadataPendingCount > 0 || next.hasMetadataGap
        let requiresHumanAction = readiness.requiresHumanAction || next.requiresHumanAction
        let isReviewable = evidence.isReviewable || readiness.isReviewable || next.isReviewable

        let steps = [
            evidenceTrailStep(
                id: "evidence",
                title: "证据覆盖",
                status: evidence.isReviewable ? "\(evidence.coveredReviewCount)/\(evidence.items.count) 类覆盖" : "等待 artifact",
                guidance: evidence.focusedReviewTitle.map { "当前聚焦 \($0)，先核对对应证据和 metadata。" } ?? evidence.guidance,
                icon: evidence.icon,
                tone: evidence.missingReviewCount > 0 ? .info : (evidence.isReviewable ? .success : .neutral),
                reviewKind: evidence.focusedReviewKind,
                reviewTitle: evidence.focusedReviewTitle,
                focusedKind: focusedKind
            ),
            evidenceTrailStep(
                id: "metadata",
                title: "metadata 状态",
                status: readiness.isReviewable ? "\(readiness.metadataPendingCount) 项待同步" : "等待 metadata",
                guidance: metadataTarget.map { "优先确认 \($0.title)：\($0.actionHint)" } ?? "metadata 已进入安全摘要后，再查看详细复核 row。",
                icon: readiness.metadataPendingCount > 0 ? "doc.badge.clock" : "doc.badge.gearshape",
                tone: readiness.metadataPendingCount > 0 ? .info : (readiness.isReviewable ? .success : .neutral),
                reviewKind: metadataTarget?.reviewKind,
                reviewTitle: metadataTarget?.title,
                focusedKind: focusedKind
            ),
            evidenceTrailStep(
                id: "priority",
                title: "优先复核",
                status: topItem?.title ?? "暂无优先项",
                guidance: topItem.map { "\($0.severity.title)：\($0.actionHint)" } ?? readiness.guidance,
                icon: topItem?.icon ?? "list.bullet.clipboard",
                tone: topItem.map { tone(forReviewPrioritySeverity: $0.severity) } ?? (readiness.isReviewable ? .success : .neutral),
                reviewKind: topItem?.reviewKind,
                reviewTitle: topItem?.title,
                focusedKind: focusedKind
            ),
            evidenceTrailStep(
                id: "next",
                title: "下一步",
                status: next.reviewTitle ?? next.status,
                guidance: next.actionHint.map { "\(next.guidance) \($0)" } ?? next.guidance,
                icon: next.icon,
                tone: next.requiresHumanAction ? .warning : (next.isReviewable ? .success : .neutral),
                reviewKind: next.reviewKind,
                reviewTitle: next.reviewTitle,
                focusedKind: focusedKind
            )
        ]

        let title: String
        let status: String
        let guidance: String
        let icon: String
        if isReviewable == false {
            title = "Mission 复核路径待生成"
            status = "尚无 Gateway 证据"
            guidance = "发送任务后会把证据、metadata、优先复核和下一步串成短路径。"
            icon = "point.topleft.down.curvedto.point.bottomright.up"
        } else if let focusedTitle {
            title = "Mission 聚焦复核路径"
            status = "聚焦 \(focusedTitle)"
            guidance = "按当前聚焦项核对证据、metadata 和下一步；不会打开 artifact 内容。"
            icon = "scope"
        } else if requiresHumanAction {
            title = "Mission 复核路径"
            status = "\(readiness.actionablePriorityCount) 项可行动 · \(readiness.criticalOrHighCount) 项高优先"
            guidance = primaryReviewTitle.map { "建议先看 \($0)，再决定审批、重试或下一轮。" } ?? "先处理需要人工复核的项目。"
            icon = "point.topleft.down.curvedto.point.bottomright.up"
        } else if hasMetadataGap {
            title = "Mission 复核路径"
            status = "\(readiness.metadataPendingCount) 项 metadata 待同步"
            guidance = "先确认 metadata 覆盖，再抽查详细复核。"
            icon = "doc.badge.clock"
        } else {
            title = "Mission 复核路径"
            status = "\(evidence.coveredReviewCount)/\(evidence.items.count) 类证据可复核"
            guidance = primaryReviewTitle.map { "可从 \($0) 开始抽查。" } ?? "可继续查看详细复核摘要。"
            icon = "checkmark.seal.fill"
        }

        return ClawMissionRunEvidenceTrailSummary(
            title: title,
            status: status,
            guidance: guidance,
            icon: icon,
            focusedReviewKind: focusedKind,
            focusedReviewTitle: focusedTitle,
            coveredReviewCount: evidence.coveredReviewCount,
            totalReviewCount: evidence.items.count,
            metadataPendingCount: readiness.metadataPendingCount,
            actionablePriorityCount: readiness.actionablePriorityCount,
            primaryReviewKind: primaryReviewKind,
            primaryReviewTitle: primaryReviewTitle,
            canFocusPrimaryReview: canFocusPrimary,
            requiresHumanAction: requiresHumanAction,
            hasMetadataGap: hasMetadataGap,
            isReviewable: isReviewable,
            steps: steps
        )
    }

    private func evidenceTrailStep(
        id: String,
        title: String,
        status: String,
        guidance: String,
        icon: String,
        tone: ClawMissionRunOperatorLaneTone,
        reviewKind: String?,
        reviewTitle: String?,
        focusedKind: String?
    ) -> ClawMissionRunEvidenceTrailStep {
        let canFocus = reviewKind.map(canFocusEvidenceTrailReviewKind) ?? false
        return ClawMissionRunEvidenceTrailStep(
            id: id,
            title: title,
            status: status,
            guidance: guidance,
            icon: icon,
            tone: tone,
            reviewKind: reviewKind,
            reviewTitle: reviewTitle,
            canFocusReview: canFocus,
            isFocused: reviewKind != nil && reviewKind == focusedKind
        )
    }

    private func canFocusEvidenceTrailReviewKind(_ reviewKind: String) -> Bool {
        focusUsesDetailReview(reviewKind) || reviewPriorityQueue.contains { $0.reviewKind == reviewKind }
    }

    private func tone(forReviewPrioritySeverity severity: ClawMissionRunReviewPrioritySeverity) -> ClawMissionRunOperatorLaneTone {
        switch severity {
        case .critical:
            return .danger
        case .high:
            return .warning
        case .medium:
            return .info
        case .low:
            return .success
        case .info:
            return .neutral
        }
    }

    var operatorStrip: ClawMissionRunOperatorStrip {
        operatorStrip(focusedOn: nil)
    }

    func operatorStrip(focusedOn reviewKind: String?) -> ClawMissionRunOperatorStrip {
        let focusedKind = reviewKind.flatMap { kind in
            availableDetailReviewKinds.contains(kind) || reviewPriorityQueue.contains { $0.reviewKind == kind } ? kind : nil
        }
        let evidence = artifactEvidenceIndex(focusedOn: focusedKind)
        let readiness = reviewReadinessSummary(focusedOn: focusedKind)
        let next = nextReviewAction(focusedOn: focusedKind)
        let gatewayTone: ClawMissionRunOperatorLaneTone
        if blockedCount > 0 || failedCount > 0 {
            gatewayTone = .danger
        } else if requiresUserApproval || retryableCount > 0 {
            gatewayTone = .warning
        } else if succeededCount > 0 {
            gatewayTone = .success
        } else if progressCurrent > 0 {
            gatewayTone = .info
        } else {
            gatewayTone = .neutral
        }

        let evidenceTone: ClawMissionRunOperatorLaneTone
        if evidence.isReviewable == false {
            evidenceTone = .neutral
        } else if evidence.missingReviewCount > 0 {
            evidenceTone = .info
        } else {
            evidenceTone = .success
        }

        let reviewTone: ClawMissionRunOperatorLaneTone
        if readiness.isReviewable == false {
            reviewTone = .neutral
        } else if readiness.requiresHumanAction {
            reviewTone = .warning
        } else if readiness.metadataPendingCount > 0 {
            reviewTone = .info
        } else {
            reviewTone = .success
        }

        let nextTone: ClawMissionRunOperatorLaneTone
        if next.requiresHumanAction {
            nextTone = .warning
        } else if next.hasMetadataGap {
            nextTone = .info
        } else if next.isReviewable {
            nextTone = .success
        } else {
            nextTone = .neutral
        }

        let nextReviewKind = next.reviewKind
        let lanes = [
            ClawMissionRunOperatorLane(
                id: "gateway",
                title: "Gateway",
                status: "\(phaseTitle) · \(progressCurrent)/\(progressTotal)",
                guidance: "\(succeededCount) 成功 · \(failedCount) 失败 · \(retryableCount) 可重试",
                icon: phaseIcon,
                tone: gatewayTone,
                reviewKind: nil,
                canFocusReview: false,
                isFocused: false
            ),
            ClawMissionRunOperatorLane(
                id: "evidence",
                title: "证据",
                status: "\(evidence.coveredReviewCount)/\(evidence.items.count) 类覆盖",
                guidance: "artifact \(evidence.artifactKindCount) · metadata \(evidence.metadataArtifactCount)",
                icon: evidence.icon,
                tone: evidenceTone,
                reviewKind: evidence.focusedReviewKind,
                canFocusReview: false,
                isFocused: evidence.focusedReviewKind != nil
            ),
            ClawMissionRunOperatorLane(
                id: "review",
                title: "复核",
                status: "\(readiness.actionablePriorityCount) 可行动 · \(readiness.criticalOrHighCount) 高优先",
                guidance: readiness.topReviewTitle.map { "先看 \($0)" } ?? readiness.guidance,
                icon: readiness.icon,
                tone: reviewTone,
                reviewKind: readiness.topReviewKind,
                canFocusReview: readiness.topReviewKind.map(focusUsesDetailReview) ?? false,
                isFocused: focusedKind == readiness.topReviewKind
            ),
            ClawMissionRunOperatorLane(
                id: "next",
                title: "下一步",
                status: next.reviewTitle ?? next.status,
                guidance: next.actionHint ?? next.guidance,
                icon: next.icon,
                tone: nextTone,
                reviewKind: nextReviewKind,
                canFocusReview: nextReviewKind.map(focusUsesDetailReview) ?? false,
                isFocused: focusedKind == nextReviewKind
            )
        ]
        let status = focusedKind.flatMap { Self.title(forDetailReviewKind: $0) }.map { "聚焦 \($0)" } ?? "\(lanes.count) 条操作态势"
        return ClawMissionRunOperatorStrip(
            title: "Mission Operator",
            status: status,
            focusedReviewKind: focusedKind,
            lanes: lanes
        )
    }

    var reviewReadinessSummary: ClawMissionRunReviewReadinessSummary {
        reviewReadinessSummary(focusedOn: nil)
    }

    func reviewReadinessSummary(focusedOn reviewKind: String?) -> ClawMissionRunReviewReadinessSummary {
        let topItem = reviewPriorityQueue.first
        let focusedItem = reviewPriorityItem(focusedOn: reviewKind)
        let actionableCount = reviewPriorityQueue.filter(\.isActionable).count
        let criticalOrHighCount = reviewPriorityQueue.filter { item in
            item.severity == .critical || item.severity == .high
        }.count
        let metadataPendingCount = reviewPriorityQueue.filter { $0.hasMetadata == false }.count
        let availableDetailCount = availableDetailReviewKinds.count
        let isReviewable = reviewPriorityQueue.isEmpty == false || availableDetailCount > 0
        let requiresHumanAction = isReviewable && (
            actionableCount > 0 ||
            criticalOrHighCount > 0 ||
            requiresUserApproval ||
            blockedCount > 0 ||
            failedCount > 0
        )
        let title: String
        let status: String
        let guidance: String
        let icon: String

        if isReviewable == false {
            title = "复核态势待生成"
            status = "尚无 Gateway 证据"
            guidance = "发送任务后会汇总复核重点。"
            icon = "tray"
        } else if requiresHumanAction {
            title = "需要人工复核"
            status = "\(actionableCount) 项可行动 · \(criticalOrHighCount) 项高优先"
            if let topItem {
                guidance = "先看 \(topItem.title)：\(topItem.actionHint)"
            } else {
                guidance = "先查看审批、阻断和失败动作。"
            }
            icon = "person.crop.circle.badge.exclamationmark.fill"
        } else if metadataPendingCount > 0 {
            title = "metadata 待同步"
            status = "\(metadataPendingCount) 项缺少复核 metadata"
            guidance = "先确认缺失 metadata 的复核项。"
            icon = "doc.badge.clock"
        } else {
            title = "复核态势可检查"
            status = "\(availableDetailCount) 类详细复核可查看"
            guidance = topItem.map { "可抽查 \($0.title)：\($0.actionHint)" } ?? "可继续查看详细复核。"
            icon = "checkmark.seal.fill"
        }

        return ClawMissionRunReviewReadinessSummary(
            title: title,
            status: status,
            guidance: guidance,
            icon: icon,
            totalPriorityCount: reviewPriorityQueue.count,
            actionablePriorityCount: actionableCount,
            criticalOrHighCount: criticalOrHighCount,
            metadataPendingCount: metadataPendingCount,
            availableDetailReviewCount: availableDetailCount,
            topReviewKind: topItem?.reviewKind,
            topReviewTitle: topItem?.title,
            topActionHint: topItem?.actionHint,
            focusedReviewKind: focusedItem?.reviewKind,
            focusedReviewTitle: focusedItem?.title,
            focusedHasDetailReview: focusUsesDetailReview(focusedItem?.reviewKind),
            isReviewable: isReviewable,
            requiresHumanAction: requiresHumanAction
        )
    }

    var nextReviewAction: ClawMissionRunNextReviewAction {
        nextReviewAction(focusedOn: nil)
    }

    func nextReviewAction(focusedOn reviewKind: String?) -> ClawMissionRunNextReviewAction {
        let readiness = reviewReadinessSummary(focusedOn: reviewKind)
        let focusedItem = reviewPriorityItem(focusedOn: reviewKind)
        let targetItem = focusedItem ?? reviewPriorityQueue.first

        if let targetItem {
            let canFocusDetail = focusUsesDetailReview(targetItem.reviewKind)
            let title = focusedItem == nil ? "下一步复核" : "继续聚焦复核"
            let guidance: String
            let primaryButtonTitle: String

            if canFocusDetail {
                guidance = "查看 \(targetItem.title) 详情：\(targetItem.actionHint)"
                primaryButtonTitle = "聚焦 \(targetItem.title)"
            } else {
                guidance = "\(targetItem.title) 是状态或审批项；保留全量详情并查看相关提示。"
                primaryButtonTitle = "聚焦 \(targetItem.title)"
            }

            return ClawMissionRunNextReviewAction(
                title: title,
                status: targetItem.status,
                guidance: guidance,
                icon: targetItem.icon,
                reviewKind: targetItem.reviewKind,
                reviewTitle: targetItem.title,
                actionHint: targetItem.actionHint,
                primaryButtonTitle: primaryButtonTitle,
                canFocusDetailReview: canFocusDetail,
                requiresHumanAction: targetItem.isActionable || readiness.requiresHumanAction,
                hasMetadataGap: targetItem.hasMetadata == false || readiness.metadataPendingCount > 0,
                isReviewable: true
            )
        }

        if let firstDetailReviewKind = availableDetailReviewKinds.first {
            let detailTitle = Self.title(forDetailReviewKind: firstDetailReviewKind)
            return ClawMissionRunNextReviewAction(
                title: "下一步复核",
                status: "\(readiness.availableDetailReviewCount) 类详细复核可查看",
                guidance: "可先抽查 \(detailTitle) 的安全摘要。",
                icon: "doc.text.magnifyingglass",
                reviewKind: firstDetailReviewKind,
                reviewTitle: detailTitle,
                actionHint: "抽查详细复核",
                primaryButtonTitle: "聚焦 \(detailTitle)",
                canFocusDetailReview: true,
                requiresHumanAction: readiness.requiresHumanAction,
                hasMetadataGap: readiness.metadataPendingCount > 0,
                isReviewable: true
            )
        }

        return ClawMissionRunNextReviewAction(
            title: "下一步复核待生成",
            status: "尚无 Gateway 证据",
            guidance: "发送任务后会给出下一步人工复核行动。",
            icon: "tray",
            reviewKind: nil,
            reviewTitle: nil,
            actionHint: nil,
            primaryButtonTitle: nil,
            canFocusDetailReview: false,
            requiresHumanAction: false,
            hasMetadataGap: false,
            isReviewable: false
        )
    }

    static func title(forDetailReviewKind reviewKind: String) -> String {
        switch reviewKind {
        case "artifact-metadata":
            return "Artifact metadata"
        case "file-change-safety":
            return "文件变更安全"
        case "shell-safety":
            return "Shell 命令安全"
        case "extraction-completeness":
            return "提取完整性"
        case "browser-control":
            return "浏览器控制"
        case "delivery-safety":
            return "最终提交安全"
        case "gateway-capability":
            return "Gateway 能力"
        case "accessibility":
            return "Accessibility 观察"
        case "replay-guard":
            return "Replay Guard"
        case "agent-trace":
            return "AgentTrace"
        default:
            return "详细复核"
        }
    }

    private static func icon(forDetailReviewKind reviewKind: String) -> String {
        switch reviewKind {
        case "artifact-metadata":
            return "paperclip.badge.ellipsis"
        case "file-change-safety":
            return "folder.badge.gearshape.fill"
        case "shell-safety":
            return "terminal.fill"
        case "extraction-completeness":
            return "tablecells.fill"
        case "browser-control":
            return "safari.fill"
        case "delivery-safety":
            return "hand.raised.fill"
        case "gateway-capability":
            return "server.rack"
        case "accessibility":
            return "accessibility.fill"
        case "replay-guard":
            return "rectangle.stack.badge.person.crop.fill"
        case "agent-trace":
            return "point.topleft.down.curvedto.point.bottomright.up"
        default:
            return "doc.text.magnifyingglass"
        }
    }

    private static func evidenceArtifactKinds(
        for reviewKind: String,
        availableArtifactKinds: [ClawGatewayArtifactKind]
    ) -> [ClawGatewayArtifactKind] {
        switch reviewKind {
        case "artifact-metadata":
            return availableArtifactKinds
        case "file-change-safety":
            return [.fileDiff]
        case "shell-safety":
            return [.commandOutput]
        case "extraction-completeness":
            return [.browserTrace, .fileDiff, .commandOutput, .screenshot, .accessibilityTree]
        case "browser-control":
            return [.browserTrace]
        case "delivery-safety":
            return [.messageDraft]
        case "gateway-capability":
            return [.auditLog]
        case "accessibility":
            return [.accessibilityTree]
        case "replay-guard":
            return [.auditLog]
        case "agent-trace":
            return [.agentTrace]
        default:
            return []
        }
    }
}

struct ClawGatewayLiveRequest: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var endpoint: String
    var transport: String
    var requestPath: String
    var tokenFingerprint: String
    var headers: [String: String]
    var bodyBytes: Int
    var taskID: UUID
    var command: String
    var actionCount: Int
    var canAttemptLive: Bool
    var preflightMessage: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        endpoint: String,
        transport: String = "websocket",
        requestPath: String = "/v1/tasks",
        tokenFingerprint: String,
        headers: [String: String],
        bodyBytes: Int,
        taskID: UUID,
        command: String,
        actionCount: Int,
        canAttemptLive: Bool,
        preflightMessage: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.endpoint = endpoint
        self.transport = transport
        self.requestPath = requestPath
        self.tokenFingerprint = tokenFingerprint
        self.headers = headers
        self.bodyBytes = bodyBytes
        self.taskID = taskID
        self.command = command
        self.actionCount = actionCount
        self.canAttemptLive = canAttemptLive
        self.preflightMessage = preflightMessage
        self.createdAt = createdAt
    }

    var safeEndpointDisplay: String {
        Self.safeEndpointDisplay(endpoint)
    }

    static func safeEndpointDisplay(_ endpoint: String?) -> String {
        let trimmed = endpoint?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard trimmed.isEmpty == false else {
            return "未配置"
        }
        if let components = URLComponents(string: trimmed),
           let scheme = components.scheme,
           let host = components.host {
            var display = "\(scheme)://\(host)"
            if let port = components.port {
                display += ":\(port)"
            }
            let path = components.path.trimmingCharacters(in: .whitespacesAndNewlines)
            if path.isEmpty == false && path != "/" {
                display += path
            }
            return display
        }

        var candidate = String(trimmed.split(separator: "?", maxSplits: 1).first ?? "")
        if let atIndex = candidate.lastIndex(of: "@") {
            let afterUserInfo = candidate[candidate.index(after: atIndex)...]
            if let schemeRange = candidate.range(of: "://") {
                candidate = String(candidate[..<schemeRange.upperBound]) + afterUserInfo
            } else {
                candidate = String(afterUserInfo)
            }
        }
        if let schemeRange = candidate.range(of: "://") {
            let rest = candidate[schemeRange.upperBound...]
            if let slashIndex = rest.firstIndex(of: "/") {
                return String(candidate[..<slashIndex])
            }
        }
        return candidate
    }
}

enum ClawGatewayEventKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case sessionPrepared
    case liveRequestPrepared
    case gatewayConnected
    case actionStarted
    case artifactStored
    case actionCompleted
    case actionFailed
    case approvalRequested
    case actionSkipped
    case sessionCompleted
    case fallbackUsed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sessionPrepared:
            return "会话准备"
        case .liveRequestPrepared:
            return "连接请求"
        case .gatewayConnected:
            return "网关连接"
        case .actionStarted:
            return "动作开始"
        case .artifactStored:
            return "证据保存"
        case .actionCompleted:
            return "动作完成"
        case .actionFailed:
            return "动作失败"
        case .approvalRequested:
            return "等待确认"
        case .actionSkipped:
            return "动作跳过"
        case .sessionCompleted:
            return "会话结束"
        case .fallbackUsed:
            return "回退执行"
        }
    }
}

struct ClawGatewayEvent: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var sessionID: UUID
    var taskID: UUID
    var sequence: Int
    var kind: ClawGatewayEventKind
    var actionID: UUID?
    var actionKind: ClawMobileActionKind?
    var actionTitle: String?
    var resultStatus: ClawGatewayActionResultStatus?
    var summary: String
    var artifacts: [ClawGatewayArtifact]
    var isRetryable: Bool
    var retryCount: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        taskID: UUID,
        sequence: Int,
        kind: ClawGatewayEventKind,
        actionID: UUID? = nil,
        actionKind: ClawMobileActionKind? = nil,
        actionTitle: String? = nil,
        resultStatus: ClawGatewayActionResultStatus? = nil,
        summary: String,
        artifacts: [ClawGatewayArtifact] = [],
        isRetryable: Bool = false,
        retryCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sessionID = sessionID
        self.taskID = taskID
        self.sequence = sequence
        self.kind = kind
        self.actionID = actionID
        self.actionKind = actionKind
        self.actionTitle = actionTitle
        self.resultStatus = resultStatus
        self.summary = summary
        self.artifacts = artifacts
        self.isRetryable = isRetryable
        self.retryCount = retryCount
        self.createdAt = createdAt
    }
}

enum ClawSensitiveTextRedactor {
    static func redacted(
        _ text: String,
        rawEndpoint: String? = nil,
        safeEndpoint: String? = nil
    ) -> String {
        var value = text
        if let rawEndpoint,
           rawEndpoint.isEmpty == false,
           let safeEndpoint,
           rawEndpoint != safeEndpoint {
            value = value.replacingOccurrences(of: rawEndpoint, with: safeEndpoint)
        }
        let replacements: [(String, String)] = [
            (#"(?i)\bheaders\s*[:=]\s*\{[^}]*\}"#, "headers=<redacted>"),
            (#"(?i)\bheaders\s*[:=]\s*[^,\s;。]+"#, "headers=<redacted>"),
            (#"(?i)\bAuthorization\s*[:=]\s*(Bearer\s+)?[^,\s;}]+"#, "Authorization=<redacted>"),
            (#"(?i)\bBearer\s+[^,\s;}]+"#, "Bearer <redacted>"),
            (#"(?i)\b(token|password|secret)\s*[:=]\s*[^,\s;}]+"#, "$1=<redacted>"),
            (#"https?://\S+"#, "url-redacted"),
            (#"file://\S+"#, "file://<redacted>"),
            (#"(?i)\bworkspace\s*[:=]\s*[^,\s;}]+"#, "workspace=<redacted>"),
            (#"(?i)\b[A-Z]:\\[^\s,;}]+"#, "<path-redacted>"),
            (#"\\\\[^\s\\,;}]+(\\[^\s\\,;}]+)+"#, "<path-redacted>"),
            (#"~\/[^\s,;}]+"#, "<path-redacted>"),
            (#"(/Users|/home|/private|/var|/tmp)/[^\s,;}]+"#, "<path-redacted>")
        ]
        for (pattern, replacement) in replacements {
            value = value.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .regularExpression
            )
        }
        return value
    }
}

struct ClawGatewayLiveHealthSummary: Equatable, Codable, Sendable {
    var endpoint: String
    var transport: String
    var requestPath: String
    var tokenFingerprint: String?
    var preflightMessage: String
    var canAttemptLive: Bool
    var connectionState: ClawGatewayConnectionState
    var sessionStatus: ClawGatewaySessionStatus?
    var actionCount: Int
    var bodyBytes: Int
    var eventCount: Int
    var latestEventSequence: Int?
    var latestEventKind: ClawGatewayEventKind?
    var latestEventAt: Date?
    var latestEventSummary: String?
    var hasGatewayAck: Bool
    var gatewayConnectedCount: Int
    var hasDuplicateGatewayConnected: Bool
    var transportAttemptCount: Int
    var reconnectCount: Int
    var hasReconnectAttempt: Bool
    var lastPingSucceeded: Bool?
    var lastTransportErrorSummary: String?
    var hasFallback: Bool
    var hasError: Bool
    var isCompleted: Bool
    var compactStatus: String
    var detailLine: String

    static func make(
        request: ClawGatewayLiveRequest?,
        connectionState: ClawGatewayConnectionState,
        events: [ClawGatewayEvent],
        latestSession: ClawGatewaySession?
    ) -> ClawGatewayLiveHealthSummary {
        let endpoint = ClawGatewayLiveRequest.safeEndpointDisplay(request?.endpoint)
        let preflightMessage = safeSummary(
            request?.preflightMessage ?? "尚未准备 Live Gateway 请求。",
            rawEndpoint: request?.endpoint,
            safeEndpoint: endpoint
        ) ?? "尚未准备 Live Gateway 请求。"
        let latestEvent = latestEvent(in: events)
        let latestEventSummary = safeSummary(
            latestEvent?.summary,
            rawEndpoint: request?.endpoint,
            safeEndpoint: endpoint
        )
        let transportDiagnostics = transportDiagnostics(
            in: events,
            rawEndpoint: request?.endpoint,
            safeEndpoint: endpoint
        )
        let gatewayConnectedCount = events.count { $0.kind == .gatewayConnected }
        let hasGatewayAck = events.contains(where: isDesktopGatewayAck)
        let hasFallback = connectionState == .fallbackSimulated || events.contains { $0.kind == .fallbackUsed }
        let isCompleted = connectionState == .completed || latestSession?.status == .completed
        let hasSessionFailure = latestSession?.status == .blocked || events.contains { $0.kind == .actionFailed }
        let hasTerminalTransportError = transportDiagnostics.lastErrorSummary != nil &&
            (connectionState == .failed || hasFallback || hasSessionFailure)
        let hasError = connectionState == .failed ||
            hasSessionFailure ||
            (hasFallback && request?.canAttemptLive == true) ||
            hasTerminalTransportError
        let compactStatus = makeCompactStatus(
            request: request,
            connectionState: connectionState,
            eventCount: events.count,
            hasGatewayAck: hasGatewayAck,
            gatewayConnectedCount: gatewayConnectedCount,
            reconnectCount: transportDiagnostics.reconnectCount,
            hasFallback: hasFallback,
            hasError: hasError,
            isCompleted: isCompleted
        )
        let detailLine = makeDetailLine(
            preflightMessage: preflightMessage,
            latestEvent: latestEvent,
            latestEventSummary: latestEventSummary
        )

        return ClawGatewayLiveHealthSummary(
            endpoint: endpoint,
            transport: request?.transport ?? "未选择",
            requestPath: request?.requestPath ?? "未准备",
            tokenFingerprint: cleanTokenFingerprint(request?.tokenFingerprint),
            preflightMessage: preflightMessage,
            canAttemptLive: request?.canAttemptLive ?? false,
            connectionState: connectionState,
            sessionStatus: latestSession?.status,
            actionCount: request?.actionCount ?? 0,
            bodyBytes: request?.bodyBytes ?? 0,
            eventCount: events.count,
            latestEventSequence: latestEvent?.sequence,
            latestEventKind: latestEvent?.kind,
            latestEventAt: latestEvent?.createdAt,
            latestEventSummary: latestEventSummary,
            hasGatewayAck: hasGatewayAck,
            gatewayConnectedCount: gatewayConnectedCount,
            hasDuplicateGatewayConnected: gatewayConnectedCount > 1,
            transportAttemptCount: transportDiagnostics.attemptCount,
            reconnectCount: transportDiagnostics.reconnectCount,
            hasReconnectAttempt: transportDiagnostics.reconnectCount > 0,
            lastPingSucceeded: transportDiagnostics.lastPingSucceeded,
            lastTransportErrorSummary: transportDiagnostics.lastErrorSummary,
            hasFallback: hasFallback,
            hasError: hasError,
            isCompleted: isCompleted,
            compactStatus: compactStatus,
            detailLine: detailLine
        )
    }

    private static func latestEvent(in events: [ClawGatewayEvent]) -> ClawGatewayEvent? {
        events.max {
            if $0.createdAt == $1.createdAt {
                return $0.sequence < $1.sequence
            }
            return $0.createdAt < $1.createdAt
        }
    }

    private static func safeSummary(
        _ summary: String?,
        rawEndpoint: String?,
        safeEndpoint: String
    ) -> String? {
        let value = summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard value.isEmpty == false else {
            return nil
        }
        return ClawSensitiveTextRedactor.redacted(
            value,
            rawEndpoint: rawEndpoint,
            safeEndpoint: safeEndpoint
        )
    }

    private struct TransportDiagnostics {
        var attemptCount: Int = 0
        var reconnectCount: Int = 0
        var lastPingSucceeded: Bool?
        var lastErrorSummary: String?
    }

    private static func transportDiagnostics(
        in events: [ClawGatewayEvent],
        rawEndpoint: String?,
        safeEndpoint: String
    ) -> TransportDiagnostics {
        var diagnostics = TransportDiagnostics()
        for event in events where event.kind == .gatewayConnected || event.kind == .fallbackUsed {
            let sanitized = safeSummary(
                event.summary,
                rawEndpoint: rawEndpoint,
                safeEndpoint: safeEndpoint
            ) ?? ""
            if let attempt = intValue(for: "attempt", in: sanitized) {
                diagnostics.attemptCount = max(diagnostics.attemptCount, attempt)
            }
            if let reconnect = intValue(for: "reconnect", in: sanitized) {
                diagnostics.reconnectCount = max(diagnostics.reconnectCount, reconnect)
            }
            if let ping = stringValue(for: "ping", in: sanitized) {
                if ping == "ok" {
                    diagnostics.lastPingSucceeded = true
                } else if ping == "failed" {
                    diagnostics.lastPingSucceeded = false
                }
            }
            if let transportError = stringValue(for: "transportError", in: sanitized) {
                diagnostics.lastErrorSummary = truncateTransportSummary(transportError)
            }
        }
        if diagnostics.attemptCount == 0 {
            diagnostics.attemptCount = events.contains { $0.kind == .gatewayConnected } ? 1 : 0
        }
        return diagnostics
    }

    private static func intValue(for key: String, in text: String) -> Int? {
        guard let value = stringValue(for: key, in: text) else {
            return nil
        }
        return Int(value)
    }

    private static func stringValue(for key: String, in text: String) -> String? {
        let pattern = #"(?<![A-Za-z0-9_])"# + NSRegularExpression.escapedPattern(for: key) + #"=([^,\s;。]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: text,
                range: NSRange(text.startIndex..<text.endIndex, in: text)
              ),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }

    private static func truncateTransportSummary(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 36 else {
            return trimmed
        }
        return String(trimmed.prefix(36)) + "..."
    }

    private static func cleanTokenFingerprint(_ fingerprint: String?) -> String? {
        let trimmed = fingerprint?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func isDesktopGatewayAck(_ event: ClawGatewayEvent) -> Bool {
        event.kind == .gatewayConnected &&
            event.summary.localizedStandardContains("Live Gateway WebSocket") == false
    }

    private static func makeCompactStatus(
        request: ClawGatewayLiveRequest?,
        connectionState: ClawGatewayConnectionState,
        eventCount: Int,
        hasGatewayAck: Bool,
        gatewayConnectedCount: Int,
        reconnectCount: Int,
        hasFallback: Bool,
        hasError: Bool,
        isCompleted: Bool
    ) -> String {
        guard request != nil else {
            return "尚未准备 Live Gateway 请求。"
        }
        if hasFallback {
            return hasError ? "Live Gateway 失败后已回退模拟。" : "Live Gateway 已回退模拟。"
        }
        if hasError {
            return "Live Gateway 事件流需要复核。"
        }
        if isCompleted {
            return "Live Gateway 会话已完成。"
        }
        switch connectionState {
        case .streaming:
            if reconnectCount > 0 {
                return "Live Gateway 已重连 \(reconnectCount) 次，正在同步事件。"
            }
            if hasGatewayAck {
                return "正在同步桌面 Gateway 事件，已收到 \(eventCount) 条。"
            }
            if gatewayConnectedCount > 0 {
                return "WebSocket 已打开并发送 envelope，等待桌面端事件。"
            }
            return "正在同步 Live Gateway 事件。"
        case .awaitingGateway:
            return "Live Gateway 请求已准备，等待桌面端接受任务。"
        case .notConfigured:
            return "Live Gateway 尚不可用。"
        case .preparingLiveRequest:
            return "正在准备 Live Gateway 请求。"
        case .completed:
            return "Live Gateway 会话已完成。"
        case .fallbackSimulated:
            return "Live Gateway 已回退模拟。"
        case .failed:
            return "Live Gateway 连接失败。"
        case .idle:
            return "Live Gateway 空闲。"
        case .simulated:
            return "当前使用模拟事件流。"
        }
    }

    private static func makeDetailLine(
        preflightMessage: String,
        latestEvent: ClawGatewayEvent?,
        latestEventSummary: String?
    ) -> String {
        guard let latestEvent else {
            return "\(preflightMessage) 暂无 Gateway 事件。"
        }
        let eventText = "#\(latestEvent.sequence) \(latestEvent.kind.title)"
        if let latestEventSummary {
            return "\(preflightMessage) 最新事件 \(eventText)：\(latestEventSummary)"
        }
        return "\(preflightMessage) 最新事件 \(eventText)。"
    }
}

enum ChatRole: String, Sendable {
    case user
    case assistant
    case system
}

struct ChatMessage: Identifiable, Equatable, Sendable {
    let id: UUID
    var role: ChatRole
    var text: String
    var timestamp: Date
    var skillTitle: String?

    init(
        id: UUID = UUID(),
        role: ChatRole,
        text: String,
        timestamp: Date = Date(),
        skillTitle: String? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
        self.skillTitle = skillTitle
    }
}

struct WorkspaceContext: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var type: String
    var updatedAt: Date
    var summary: String
    var riskLevel: Int

    init(id: UUID = UUID(), title: String, type: String, updatedAt: Date, summary: String, riskLevel: Int) {
        self.id = id
        self.title = title
        self.type = type
        self.updatedAt = updatedAt
        self.summary = summary
        self.riskLevel = riskLevel
    }
}

enum LocalArtifactValidator {
    static func validate(
        manifest: ModelArtifactManifest,
        presentFiles: Set<String>,
        observedSHA256: String? = nil
    ) -> ArtifactValidationResult {
        let statuses = manifest.requiredFiles.map { fileName in
            ArtifactFileStatus(fileName: fileName, exists: presentFiles.contains(fileName))
        }

        return validate(manifest: manifest, fileStatuses: statuses, observedSHA256: observedSHA256)
    }

    static func validate(
        manifest: ModelArtifactManifest,
        in directoryURL: URL,
        observedSHA256: String? = nil,
        fileManager: FileManager = .default
    ) -> ArtifactValidationResult {
        let statuses = manifest.requiredFiles.map { fileName in
            let fileURL = directoryURL.appendingPathComponent(fileName)
            var isDirectory = ObjCBool(false)
            let exists = fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory)
            let attributes = exists ? try? fileManager.attributesOfItem(atPath: fileURL.path) : nil
            let byteCount = (attributes?[.size] as? NSNumber)?.int64Value
            return ArtifactFileStatus(
                fileName: fileName,
                exists: exists,
                byteCount: byteCount,
                isDirectory: isDirectory.boolValue
            )
        }

        let shouldHash = observedSHA256 == nil
            && statuses.allSatisfy(\.exists)
            && isConcreteSHA256(manifest.expectedSHA256)
        let computedHash = shouldHash
            ? ModelArtifactHasher.sha256Hex(
                for: directoryURL.appendingPathComponent(manifest.modelFileName),
                fileManager: fileManager
            )
            : nil

        return validate(
            manifest: manifest,
            fileStatuses: statuses,
            observedSHA256: observedSHA256 ?? computedHash
        )
    }

    static func validate(
        manifest: ModelArtifactManifest,
        fileStatuses: [ArtifactFileStatus],
        observedSHA256: String? = nil
    ) -> ArtifactValidationResult {
        let statusesByName = Dictionary(uniqueKeysWithValues: fileStatuses.map { ($0.fileName, $0) })
        let orderedStatuses = manifest.requiredFiles.map { fileName in
            statusesByName[fileName] ?? ArtifactFileStatus(fileName: fileName, exists: false)
        }
        let missingFiles = orderedStatuses.filter { $0.exists == false }
        let expectedHash = manifest.expectedSHA256.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let observedHash = observedSHA256?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hasConcreteHash = isConcreteSHA256(expectedHash)
        let hasVerifiedHash = hasConcreteHash && observedHash == expectedHash

        let availability: ArtifactAvailability
        if missingFiles.isEmpty == false {
            availability = .missing
        } else if hasVerifiedHash {
            availability = .verified
        } else {
            availability = .staged
        }

        return ArtifactValidationResult(
            availability: availability,
            fileStatuses: orderedStatuses,
            expectedSHA256: manifest.expectedSHA256,
            observedSHA256: observedSHA256,
            hasConcreteExpectedHash: hasConcreteHash,
            hasVerifiedHash: hasVerifiedHash,
            networkDownloadAllowed: manifest.allowsNetworkDownload
        )
    }

    static func isConcreteSHA256(_ value: String) -> Bool {
        value.range(of: #"^[0-9a-fA-F]{64}$"#, options: .regularExpression) != nil
    }
}

enum ModelArtifactHasher {
    static func sha256Hex(for url: URL, fileManager: FileManager = .default) -> String? {
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return nil
        }

        do {
            var hasher = SHA256()
            if isDirectory.boolValue {
                try updateDirectoryHash(&hasher, directoryURL: url, fileManager: fileManager)
            } else {
                try updateHash(&hasher, withFileAt: url)
            }
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        } catch {
            return nil
        }
    }

    private static func updateDirectoryHash(
        _ hasher: inout SHA256,
        directoryURL: URL,
        fileManager: FileManager
    ) throws {
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let basePath = directoryURL.standardizedFileURL.path
        let files = enumerator
            .compactMap { $0 as? URL }
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .sorted { $0.standardizedFileURL.path < $1.standardizedFileURL.path }

        for fileURL in files {
            let filePath = fileURL.standardizedFileURL.path
            let relativePath = filePath.hasPrefix(basePath + "/")
                ? String(filePath.dropFirst(basePath.count + 1))
                : fileURL.lastPathComponent
            hasher.update(data: Data("path:\(relativePath)\n".utf8))
            try updateHash(&hasher, withFileAt: fileURL)
        }
    }

    private static func updateHash(_ hasher: inout SHA256, withFileAt url: URL) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }

        while true {
            let chunk = handle.readData(ofLength: 1024 * 1024)
            if chunk.isEmpty {
                break
            }
            hasher.update(data: chunk)
        }
    }
}

enum ArtifactImportError: Error, Equatable {
    case emptySelection
    case missingRequiredFiles([String])

    var message: String {
        switch self {
        case .emptySelection:
            return "没有选择任何本地文件。"
        case .missingRequiredFiles(let fileNames):
            return "缺少必需文件：\(fileNames.joined(separator: ", "))。"
        }
    }
}

struct ModelArtifactStore {
    static let localModelsDirectoryName = "ClawLocalModels"

    static func defaultDirectoryURL(fileManager: FileManager = .default) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseURL.appendingPathComponent(localModelsDirectoryName, isDirectory: true)
    }

    static func validate(
        manifest: ModelArtifactManifest,
        directoryURL: URL = defaultDirectoryURL(),
        fileManager: FileManager = .default
    ) -> ArtifactValidationResult {
        LocalArtifactValidator.validate(
            manifest: manifest,
            in: directoryURL,
            fileManager: fileManager
        )
    }

    static func importArtifacts(
        manifest: ModelArtifactManifest,
        sourceURLs: [URL],
        destinationDirectoryURL: URL = defaultDirectoryURL(),
        fileManager: FileManager = .default
    ) throws -> ArtifactValidationResult {
        guard sourceURLs.isEmpty == false else {
            throw ArtifactImportError.emptySelection
        }

        let sourcesByName = Dictionary(grouping: sourceURLs, by: \.lastPathComponent)
        let missingFiles = manifest.requiredFiles.filter { sourcesByName[$0]?.first == nil }
        guard missingFiles.isEmpty else {
            throw ArtifactImportError.missingRequiredFiles(missingFiles)
        }

        try fileManager.createDirectory(at: destinationDirectoryURL, withIntermediateDirectories: true)

        for fileName in manifest.requiredFiles {
            guard let sourceURL = sourcesByName[fileName]?.first else { continue }
            let destinationURL = destinationDirectoryURL.appendingPathComponent(fileName)
            let didAccess = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            if sourceURL.standardizedFileURL.path != destinationURL.standardizedFileURL.path {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            }
        }

        return validate(
            manifest: manifest,
            directoryURL: destinationDirectoryURL,
            fileManager: fileManager
        )
    }
}
