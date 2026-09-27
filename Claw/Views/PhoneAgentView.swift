import SwiftUI

struct PhoneAgentView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var reviewFocus: ClawMissionRunReviewFocus?

    private let examples = [
        "接管我的电脑，打开浏览器搜索竞品信息，整理成表格后发到 Slack",
        "读取微信新消息并自动回复客户",
        "在项目目录运行测试，失败时定位原因并准备补丁"
    ]

    var body: some View {
        GeometryReader { geometry in
            if ClawWorkspaceLayout.usesReviewColumn(
                width: geometry.size.width,
                accessibilitySize: dynamicTypeSize.isAccessibilitySize
            ) {
                PhoneAgentWorkbenchLayout(examples: examples, reviewFocus: $reviewFocus)
            } else {
                PhoneAgentCompactLayout(examples: examples, reviewFocus: $reviewFocus)
            }
        }
        .background(AppSurfaceBackground())
        .navigationTitle("Claw Agent")
        .navigationBarTitleDisplayMode(.inline)
    }
}
