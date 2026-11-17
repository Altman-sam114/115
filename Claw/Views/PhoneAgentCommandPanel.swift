import SwiftUI

struct PhoneAgentCommandPanel: View {
    @EnvironmentObject private var store: ClawStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var guide: SetupGuide?
    @FocusState private var commandIsFocused: Bool
    let examples: [String]
    let onSelectDetail: (ClawWorkspaceDetailSection) -> Void

    private enum SetupGuide: String, Identifiable {
        case connection
        var id: String { rawValue }
    }

    private var inputIsValid: Bool {
        (try? ClawModelPlanningRequest(command: store.phoneAgentCommand)) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Claw 工作台", systemImage: "display.and.arrow.down")
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
            Text("告诉 AI 你的目标，先看计划，再批准电脑执行。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("例如：整理项目资料，生成一份摘要", text: $store.phoneAgentCommand, axis: .vertical)
                .lineLimit(3...6)
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                .privacySensitive()
                .focused($commandIsFocused)
                .accessibilityLabel("任务目标")
                .accessibilityHint("只编辑本次任务；不会自动发送或执行")
                .accessibilityIdentifier("workspace.command.input")

            if !inputIsValid && !store.phoneAgentCommand.isEmpty {
                Text("请输入有效任务，最多 4096 字节；中文通常每字占 3 字节。")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                if store.gatewayConfigurationIsReady {
                    Task {
                        if let planID = await store.requestModelPlan(), store.phoneAgentPlan.id == planID {
                            onSelectDetail(.plan)
                        }
                    }
                } else {
                    guide = .connection
                }
            } label: {
                Label(store.gatewayConfigurationIsReady ? "AI 制定计划" : "先连接电脑", systemImage: "sparkles")
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(store.modelPlanningPhase == .requesting || (store.gatewayConfigurationIsReady && !inputIsValid))
            .keyboardShortcut(.return, modifiers: .command)
            .accessibilityHint("连接就绪后只向已配置的电脑模型发送本次任务文字；生成计划后仍需复核参数与审批，不执行电脑动作")
            .accessibilityIdentifier("workspace.command.plan")

            if store.modelPlanningPhase == .requesting {
                HStack {
                    ProgressView()
                    Button("停止等待") { store.cancelModelPlanning() }
                        .frame(minHeight: 44)
                        .accessibilityHint("停止本地等待，不承诺取消远端计算，不自动重试")
                }
            }

            Text(store.gatewayConfigurationIsReady ? store.modelPlanningPhase.message : "在你的电脑启动 Gateway 并配置模型，然后保存连接。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Label(store.phoneAgentPlan.source.title, systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let usage = store.modelPlanningUsage {
                Text(usage.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))
            layout {
                Menu {
                    ForEach(examples, id: \.self) { example in
                        Button(example) {
                            store.usePhoneAgentExample(example)
                            onSelectDetail(.plan)
                            commandIsFocused = true
                        }
                    }
                } label: {
                    Label("示例任务", systemImage: "lightbulb")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityHint("只填入示例文字并聚焦输入框，便于继续修改，不向电脑发送任务")
                .accessibilityIdentifier("workspace.command.examples")

                Menu {
                    Button("编辑任务目标", systemImage: "pencil") { commandIsFocused = true }
                        .keyboardShortcut("l", modifiers: .command)
                    Button("预览规则计划", systemImage: "list.bullet.rectangle") {
                        store.generatePhoneAgentPlan()
                        onSelectDetail(.plan)
                    }
                    Button("查看演练（模拟）", systemImage: "play.circle") {
                        store.simulatePhoneAgentExecution()
                        onSelectDetail(.events)
                    }
                    Button("连接与权限说明", systemImage: "lock.shield") { guide = .connection }
                } label: {
                    Label("更多", systemImage: "ellipsis.circle")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityIdentifier("workspace.command.more")
            }
            .buttonStyle(.bordered)
        }
        .panelCard()
        .sheet(item: $guide) { _ in
            ClawConnectionSetupGuide()
        }
    }
}

private struct ClawConnectionSetupGuide: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    guideStep("1. 准备电脑", icon: "desktopcomputer",
                              text: "在你的 Mac 上运行 Claw Gateway，并配置它使用的模型。Mac 版 App 同样通过 Gateway 执行，安装控制台不会自动获得电脑操作权限。")
                    guideStep("2. 保存连接", icon: "network",
                              text: "Mac 同机服务可使用 ws://127.0.0.1:18789。iPad 上的 127.0.0.1 指向 iPad 自己；连接电脑请使用可达的可信 wss:// 地址和 Gateway 凭据。")
                    ClawGatewayConfigurationView()
                    guideStep("3. 按需要授权", icon: "lock.shield",
                              text: "截图需要屏幕录制权限；读取或操作控件需要辅助功能权限；部分应用操作另需自动化权限。在 Mac 系统设置中授权实际运行 Gateway 的程序。文件操作仍限于批准的工作目录，不默认要求全磁盘访问。")
                    guideStep("4. 从小任务开始", icon: "checklist",
                              text: "回到工作台，让 AI 制定计划，逐项核对参数并审批。保存连接不会自动联网、发送任务或执行操作。iPad 负责控制和复核，不能静默接管其他 App。")
                }
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(20)
            }
            .navigationTitle("连接你的电脑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func guideStep(_ title: String, icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
