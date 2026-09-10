import SwiftUI

@main
struct EmodollsStudioApp: App {
    @StateObject private var theme = ThemeController()
    @StateObject private var session = Session()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .emodollsTheme()
                .environmentObject(theme)
                .environmentObject(session)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 760, height: 860)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
