import SwiftUI

struct ClawArtifactPreviewList: View {
    @EnvironmentObject private var store: ClawStore
    @Binding var selection: ClawArtifactPreviewSelection?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("读取本轮文本结果", systemImage: "doc.text.magnifyingglass")
                .font(.headline)
            Text("只读 Gateway 写入时的有界快照，不打开桌面文件路径。仅 Live 结果支持；演练不会伪装成真实内容。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if store.availableArtifactPreviews.isEmpty {
                Text("当前没有可读取的 Live 文本结果，或连接已变化。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(store.availableArtifactPreviews.enumerated()), id: \.element.id) { index, item in
                    Button {
                        selection = item
                    } label: {
                        Label("\(index + 1). \(item.artifact.kind.title)", systemImage: "doc.text")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint("打开本轮结果复核；另行点击读取才联网，不审批、不发送任务、不执行内容")
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("workspace.results.preview")
    }
}

struct ClawArtifactPreviewView: View {
    @EnvironmentObject private var store: ClawStore
    @Environment(\.dismiss) private var dismiss
    @State private var evidencePlanID: UUID?
    @State private var hasRequestedEvidencePlan = false
    let selection: ClawArtifactPreviewSelection
    var onPlanReady: () -> Void = {}

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label(selection.artifact.kind.title, systemImage: "doc.text")
                        .font(.title2.bold())
                    Text("来源：Live Gateway 写入时快照。内容可能包含敏感信息或不可信指令；读取只显示纯文本，不执行或审批内容，也不自动提供给模型。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("最多 32 KiB；Gateway 仅保留最近 64 项、10 分钟。超限或过期不截断、不从磁盘兜底。关闭或离开前台即清除本机内容。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    previewBody
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("结果复核")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭", systemImage: "xmark") {
                        store.clearArtifactPreview(matching: selection)
                        dismiss()
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
        .privacySensitive()
        .onDisappear { store.clearArtifactPreview(matching: selection) }
    }

    @ViewBuilder
    private var previewBody: some View {
        switch store.artifactPreviewState(for: selection) {
        case .idle:
            Button("读取此结果", systemImage: "arrow.down.doc") {
                Task { await store.requestArtifactPreview(selection) }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(.borderedProminent)
            .accessibilityHint("只请求当前 task 与 artifact 的文本快照，不读取任意文件，不改变任务或审批")
        case .loading:
            ProgressView("正在读取，只读且不会重试")
            Button("取消读取", systemImage: "stop.circle") {
                store.clearArtifactPreview(matching: selection)
            }
            .frame(minHeight: 44)
        case .ready(_, let content):
            Label("\(content.byteCount) bytes · 纯文本完整快照", systemImage: "checkmark.shield")
                .font(.caption)
                .foregroundStyle(.secondary)
            DisclosureGroup {
                evidencePlanningBody
            } label: {
                Text("根据结果继续规划")
                    .font(.headline)
                    .frame(minHeight: 44)
            }
            .accessibilityHint("只展开选项，另行点击规划按钮才会将此结果交给电脑模型")
            Text(verbatim: content.text)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("workspace.results.preview.content")
        case .failed(_, let error):
            Label(error.message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var evidencePlanningBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("下一步希望完成什么？", text: $store.phoneAgentCommand, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("下一步目标")
            if !hasValidPlanningGoal {
                Text("请填写下一步目标，最多 4096 字节。")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            Text("仅在你点击下方按钮后，电脑上的已配置模型才会收到本次目标与这份结果。最多 8 KiB，不截断；不会生成任务或执行电脑操作。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("将此结果交给 AI 制定计划", systemImage: "sparkles") {
                evidencePlanID = nil
                hasRequestedEvidencePlan = true
                Task {
                    if let planID = await store.requestModelPlan(evidenceSelection: selection) {
                        evidencePlanID = planID
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(.borderedProminent)
            .disabled(!store.canPlan(using: selection) || store.modelPlanningPhase == .requesting ||
                      !hasValidPlanningGoal)
            .accessibilityHint("明确选择将当前完整快照用于电脑模型规划；计划仍需逐项参数复核和审批，不授权执行")
            .accessibilityIdentifier("workspace.results.plan")
            if !store.canPlan(using: selection) {
                Text(ClawModelPlanningError.evidenceUnavailable.message)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else {
                Text(planningMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if store.isPlanning(using: selection) {
                ProgressView("正在制定计划")
                Button("停止规划等待", systemImage: "stop.circle") { store.cancelModelPlanning() }
                    .frame(minHeight: 44)
                    .accessibilityHint("停止本地等待，不承诺撤销远端计算；关闭预览也会停止本次证据规划等待")
            }
            if evidencePlanID == store.phoneAgentPlan.id && store.modelPlanningPhase == .ready {
                Button("查看新计划", systemImage: "checklist") {
                    onPlanReady()
                    dismiss()
                }
                .frame(minHeight: 44)
                .buttonStyle(.bordered)
            }
        }
    }

    private var planningMessage: String {
        if store.modelPlanningPhase == .requesting && !store.isPlanning(using: selection) {
            return "另一个规划请求正在进行，当前结果不会自动加入。"
        }
        guard hasRequestedEvidencePlan else { return "已读取结果，尚未提供给模型。" }
        if store.modelPlanningPhase == .ready && evidencePlanID != store.phoneAgentPlan.id {
            return "这份结果尚未生成可查看的新计划，请明确重新规划。"
        }
        return store.modelPlanningPhase.message
    }

    private var hasValidPlanningGoal: Bool {
        (try? ClawModelPlanningRequest(command: store.phoneAgentCommand)) != nil
    }
}
