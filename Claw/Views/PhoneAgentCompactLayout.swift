import SwiftUI

struct PhoneAgentCompactLayout: View {
    let examples: [String]
    @Binding var reviewFocus: ClawMissionRunReviewFocus?
    @Binding var presentation: ClawWorkspacePresentationState
    @Binding var continuationEditor: ClawContinuationEditorInputState
    @Binding var taskArgumentEditor: ClawTaskArgumentEditorContext?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PhoneAgentCommandPanel(examples: examples) { presentation.selectedDetail = $0 }

                ClawMissionRunPanel(
                    reviewFocus: $reviewFocus, continuationEditor: $continuationEditor,
                    taskArgumentEditor: $taskArgumentEditor
                )

                PhoneAgentReviewColumn(
                    reviewFocus: $reviewFocus, presentation: $presentation,
                    taskArgumentEditor: $taskArgumentEditor
                )
            }
            .padding(16)
        }
    }
}
