import SwiftUI

struct PhoneAgentCompactLayout: View {
    let examples: [String]
    @Binding var reviewFocus: ClawMissionRunReviewFocus?
    @Binding var presentation: ClawWorkspacePresentationState
    @Binding var continuationEditor: ClawContinuationEditorInputState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PhoneAgentCommandPanel(examples: examples) { presentation.selectedDetail = $0 }

                ClawMissionRunPanel(reviewFocus: $reviewFocus, continuationEditor: $continuationEditor)

                PhoneAgentReviewColumn(reviewFocus: $reviewFocus, presentation: $presentation)
            }
            .padding(16)
        }
    }
}
