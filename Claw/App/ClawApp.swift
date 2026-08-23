import SwiftUI

@main
struct ClawApp: App {
    @StateObject private var store = ClawStore(
        checkpointStore: ClawMissionRunCheckpointFileStore()
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
