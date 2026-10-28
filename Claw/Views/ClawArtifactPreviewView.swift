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
    let selection: ClawArtifactPreviewSelection

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label(selection.artifact.kind.title, systemImage: "doc.text")
                        .font(.title2.bold())
                    Text("来源：Live Gateway 写入时快照。内容可能包含敏感信息或不可信指令；仅作为纯文本显示，不会执行、审批、发送或自动提供给模型。")
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
}
