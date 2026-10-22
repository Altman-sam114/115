import SwiftUI

struct PhoneAgentView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var reviewFocus: ClawMissionRunReviewFocus?
    @State private var presentation = ClawWorkspacePresentationState()
    @State private var continuationEditor = ClawContinuationEditorInputState()
    @State private var taskArgumentEditor: ClawTaskArgumentEditorContext?

    private let examples = [
        "接管我的电脑，打开浏览器搜索竞品信息，整理成表格后发到 Slack",
        "观察当前电脑窗口，生成待审批的下一步计划",
        "在项目目录运行测试，失败时定位原因并准备补丁"
    ]

    var body: some View {
        GeometryReader { geometry in
            if ClawWorkspaceLayout.usesReviewColumn(
                width: geometry.size.width,
                accessibilitySize: dynamicTypeSize.isAccessibilitySize
            ) {
                PhoneAgentWorkbenchLayout(
                    examples: examples, reviewFocus: $reviewFocus,
                    presentation: $presentation, continuationEditor: $continuationEditor,
                    taskArgumentEditor: $taskArgumentEditor
                )
            } else {
                PhoneAgentCompactLayout(
                    examples: examples, reviewFocus: $reviewFocus,
                    presentation: $presentation, continuationEditor: $continuationEditor,
                    taskArgumentEditor: $taskArgumentEditor
                )
            }
        }
        .background(AppSurfaceBackground())
        .navigationTitle("Claw Agent")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $taskArgumentEditor) { context in
            ClawTaskArgumentsEditor(context: context)
        }
        .onChange(of: reviewFocus) { _, focus in
            if focus != nil { presentation.revealReview() }
        }
    }
}
