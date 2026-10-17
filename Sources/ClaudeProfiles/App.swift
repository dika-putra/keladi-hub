import SwiftUI

@main
struct ClaudeProfilesApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        MenuBarExtra("Claude Profiles", systemImage: "person.2.circle") {
            ContentView().environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }
}
