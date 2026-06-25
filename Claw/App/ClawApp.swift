import SwiftUI

@main
struct ClawApp: App {
    @StateObject private var store = ClawStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
