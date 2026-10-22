import SwiftUI

struct ClawTaskArgumentsList: View {
    @EnvironmentObject private var store: ClawStore
    let task: ClawMobileTask
    @Binding var editor: ClawTaskArgumentEditorContext?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("最终执行参数", systemImage: "slider.horizontal.3")
                .font(.headline)
            Text("点击动作复核具体输入。应用修改会撤销旧审批；Live 发送前会再次校验，模拟演练不代表真实执行。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(task.actions) { action in
                if ClawTaskArguments.isEditable(action.kind) {
                    let context = ClawTaskArgumentEditorContext(task: task, action: action)
                    Button {
                        editor = context
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            Text(action.kind.title).font(.subheadline.bold())
                            Spacer(minLength: 8)
                            Label(
                                ClawTaskArguments.issue(in: action) == nil ? "可复核" : "需填写",
                                systemImage: ClawTaskArguments.issue(in: action) == nil ? "checkmark.circle" : "pencil.circle"
                            )
                            .font(.caption)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!store.canEditTaskArguments(context))
                    .accessibilityHint("只打开此动作的最终参数，不审批、不发送，不执行电脑动作")
                } else {
                    Label("\(action.kind.title)：固定策略，原文可在 envelope 中复核", systemImage: "lock.shield")
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .panelCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace.task.final-arguments")
    }
}

struct ClawTaskArgumentsEditor: View {
    @EnvironmentObject private var store: ClawStore
    @Environment(\.dismiss) private var dismiss
    let context: ClawTaskArgumentEditorContext
    @State private var input: ClawTaskArgumentInput
    @State private var staleMessage: String?

    init(context: ClawTaskArgumentEditorContext) {
        self.context = context
        _input = State(initialValue: ClawTaskArgumentInput(action: context.action))
    }

    private var validationIssue: ClawTaskArgumentIssue? {
        var action = context.action
        action.toolArguments = input.arguments(for: action.kind)
        return ClawTaskArguments.issue(in: action)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("这里展示将写入 envelope 的最终输入，可能包含敏感内容。只在本机编辑；应用后必须重新审批，关闭不会应用。")
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Gateway 仍会独立检查 workspace、浏览器、Shell、桌面白名单和最终提交权限。参数有效不代表已授权或已执行。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("结构化参数") {
                    fields
                }
                .disabled(!store.canEditTaskArguments(context))
                Section {
                    if !store.canEditTaskArguments(context) {
                        Text("任务或审批状态已经变化，此编辑器已过期；请关闭后重新打开。")
                            .foregroundStyle(.orange)
                    } else if let validationIssue {
                        Text(validationIssue.message).foregroundStyle(.orange)
                    }
                    if let staleMessage {
                        Text(staleMessage).foregroundStyle(.orange)
                    }
                    Button("应用参数并撤销旧审批", systemImage: "checkmark.circle") {
                        if store.applyTaskArgumentInput(input, context: context) {
                            dismiss()
                        } else {
                            staleMessage = "参数未应用；当前任务或安全状态已变化，请重新打开编辑器。"
                        }
                    }
                    .frame(minHeight: 44)
                    .disabled(validationIssue != nil || !store.canEditTaskArguments(context))
                    .accessibilityHint("只更新当前未发送动作并撤销旧审批，不会发送、联网或执行电脑动作")
                }
            }
            .navigationTitle(context.action.kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var fields: some View {
        switch context.action.kind {
        case .controlBrowser:
            Picker("浏览器动作", selection: $input.browserMode) {
                ForEach(ClawTaskArgumentInput.BrowserMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            TextField("浏览器 App", text: $input.browserApp)
                .frame(minHeight: 44)
            TextField("目标说明", text: $input.browserGoal, axis: .vertical)
                .frame(minHeight: 44)
            TextField(input.browserMode == .search ? "最终搜索词" : "完整 http(s) 链接", text: $input.browserTarget, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(minHeight: 44)
            Text("搜索使用固定 Google URL 模板；打开链接不接受账号密码。网页内容不由客户端伪造，真实证据需 Gateway 返回。")
                .font(.footnote)
        case .manageFiles:
            TextField("workspace 相对文件路径", text: $input.filePath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(minHeight: 44)
            TextField("最终文件正文", text: $input.fileText, axis: .vertical)
                .lineLimit(5...12)
                .frame(minHeight: 120)
            Text("固定 writeText、workspaceOnly=true；不会把任务指令自动写入文件。单字段最多 4096 UTF-8 bytes。")
                .font(.footnote)
        case .runShellCommand:
            TextField("最终结构化命令", text: $input.shellCommand, axis: .vertical)
                .font(.body.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(minHeight: 88)
            Text("不会从自然语言生成命令。Gateway 使用 workspace 内的 allowlisted executable，不启用 Shell 解释器；管道、重定向等不作为 Shell 语法执行。")
                .font(.footnote)
        case .operateDesktopApp:
            TextField("目标 App", text: $input.desktopApp).frame(minHeight: 44)
            TextField("最终粘贴正文（可空）", text: $input.desktopText, axis: .vertical)
                .lineLimit(3...10)
                .frame(minHeight: 88)
            TextField("快捷键序列（可空，逗号分隔）", text: $input.desktopKeys)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(minHeight: 44)
            Text("正文或快捷键至少填写一项。不会从 inputPreview 或任务说明生成粘贴文本；最终提交仍停在确认闸门。")
                .font(.footnote)
        case .extractData:
            TextField("提取目标", text: $input.extractionGoal, axis: .vertical).frame(minHeight: 88)
            TextField("workspace 相对输出路径", text: $input.extractionPath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(minHeight: 44)
            Text("固定来源优先级、字段 schema 和完整性校验；目标和路径各最多 500 UTF-8 bytes。")
                .font(.footnote)
        case .composeMessage, .composeEmail:
            TextField("明确收件人或频道", text: $input.recipient).frame(minHeight: 44)
            TextField("最终草稿正文", text: $input.messageBody, axis: .vertical)
                .lineLimit(5...12)
                .frame(minHeight: 120)
            Text("只生成待确认草稿，不发送消息或邮件，也不猜测收件人。")
                .font(.footnote)
        default:
            Text("此动作没有可编辑参数。")
        }
    }
}
