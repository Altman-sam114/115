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

    init(
        id: UUID = UUID(),
        kind: ClawGatewayArtifactKind,
        title: String,
        reference: String,
        isRedacted: Bool
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.reference = reference
        self.isRedacted = isRedacted
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
        self.auditTrail = auditTrail
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
        results.map(\.artifacts.count).reduce(0, +)
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
