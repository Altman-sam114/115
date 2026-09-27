import SwiftUI

struct ClawDestinationView: View {
    let destination: MainTab
    @Binding var showingImporter: Bool
    @Binding var importError: String?
    @Binding var reviewFocus: ClawMissionRunReviewFocus?

    var body: some View {
        switch destination {
        case .phoneAgent:
            PhoneAgentView(reviewFocus: $reviewFocus)
        case .link:
            LinkDashboardView(showingImporter: $showingImporter, importError: $importError)
        case .chat:
            ChatWorkspaceView()
        case .skills:
            SkillLibraryView()
        case .ranking:
            RankingView()
        }
    }
}
