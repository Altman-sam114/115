import SwiftUI

struct PhoneAgentWorkbenchLayout: View {
    let examples: [String]
    @Binding var reviewFocus: ClawMissionRunReviewFocus?

    var body: some View {
        GeometryReader { proxy in
            let leftWidth = ClawWorkspaceLayout.leadingColumnWidth(for: proxy.size.width)

            HStack(alignment: .top, spacing: 16) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PhoneAgentCommandPanel(examples: examples)
                        ClawMissionRunPanel(reviewFocus: $reviewFocus)
                    }
                    .padding(.vertical, 16)
                    .padding(.leading, 16)
                }
                .frame(width: leftWidth)

                Divider()
                    .padding(.vertical, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PhoneAgentReviewColumn(reviewFocus: $reviewFocus)
                    }
                    .padding(.vertical, 16)
                    .padding(.trailing, 16)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
