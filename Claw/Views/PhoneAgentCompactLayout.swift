import SwiftUI

struct PhoneAgentCompactLayout: View {
    let examples: [String]
    @Binding var reviewFocus: ClawMissionRunReviewFocus?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PhoneAgentCommandPanel(examples: examples)

                ClawMissionRunPanel(reviewFocus: $reviewFocus)

                PhoneAgentPlanPanel()

                ClawMobileBridgePanel()

                ClawGatewaySessionPanel()

                PhoneAgentPermissionMatrix()

                PhoneAgentExecutionPanel()
            }
            .padding(16)
        }
    }
}
