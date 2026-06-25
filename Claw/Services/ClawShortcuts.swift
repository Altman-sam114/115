import AppIntents
import Foundation

struct GenerateClawExecutionPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "生成 Claw 执行计划"
    static let description = IntentDescription("把电脑任务交给 Claw 本地规划器，生成可审批的浏览器、文件、Shell 和桌面 App 操作清单。")
    static let openAppWhenRun = true

    @Parameter(title: "任务描述", requestValueDialog: "描述希望 Claw 在电脑上完成的工作")
    var text: String

    @Parameter(title: "能力类型", default: "浏览器研究")
    var task: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = trimmed.isEmpty ? "未提供任务" : trimmed
        let result = """
        Claw 本地执行计划（模拟）
        任务：\(task)
        输入：\(source)
        输出：请确认目标应用、输入来源、输出格式、审批点、回滚点和网关权限；真实 runtime 接入后将在本机完成规划。
        """
        return .result(value: result)
    }
}

struct PlanPhoneAutomationIntent: AppIntent {
    static let title: LocalizedStringResource = "规划 Claw 电脑接管"
    static let description = IntentDescription("把一句电脑任务拆成手机端审批步骤、用户确认点和 Claw Gateway 动作。")
    static let openAppWhenRun = true

    @Parameter(title: "操作指令", requestValueDialog: "描述希望 Claw 接管电脑完成的工作")
    var command: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let capabilities = ClawStore.defaultPhoneAgentCapabilities
        let plan = PhoneAgentPlanner.makePlan(
            command: command,
            capabilities: capabilities
        )
        let steps = plan.steps.enumerated().map { index, step in
            "\(index + 1). \(step.title) / \(step.surface.title) / \(step.runMode.title)"
        }
        let result = """
        Claw 电脑接管计划
        \(plan.summary)

        \(steps.joined(separator: "\n"))
        """
        return .result(value: result)
    }
}

struct BuildClawMobilePayloadIntent: AppIntent {
    static let title: LocalizedStringResource = "生成 Claw 电脑任务"
    static let description = IntentDescription("把电脑操作指令转换成可交给 Claw Gateway 审批和执行的 JSON payload。")
    static let openAppWhenRun = true

    @Parameter(title: "操作指令", requestValueDialog: "描述希望 Claw 接管电脑完成的工作")
    var command: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let profile = ClawStore.defaultClawGatewayProfile
        let plan = PhoneAgentPlanner.makePlan(
            command: command,
            capabilities: ClawStore.defaultPhoneAgentCapabilities
        )
        let task = ClawMobileBridge.makeTask(
            from: plan,
            profile: profile,
            selectedSkill: nil,
            documents: ClawStore.defaultDocuments
        )
        return .result(value: ClawMobileBridge.makeEnvelopeString(task: task, profile: profile))
    }
}

struct ClawShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GenerateClawExecutionPlanIntent(),
            phrases: [
                "用 \(.applicationName) 生成 Claw 执行计划",
                "让 \(.applicationName) 规划电脑任务"
            ],
            shortTitle: "Claw 计划",
            systemImageName: "display.and.arrow.down"
        )
        AppShortcut(
            intent: PlanPhoneAutomationIntent(),
            phrases: [
                "用 \(.applicationName) 规划电脑接管",
                "让 \(.applicationName) 安排电脑工作"
            ],
            shortTitle: "电脑接管",
            systemImageName: "desktopcomputer"
        )
        AppShortcut(
            intent: BuildClawMobilePayloadIntent(),
            phrases: [
                "用 \(.applicationName) 生成 Claw 电脑任务",
                "让 \(.applicationName) 准备 Claw 电脑 payload"
            ],
            shortTitle: "Claw 电脑任务",
            systemImageName: "network"
        )
    }
}
