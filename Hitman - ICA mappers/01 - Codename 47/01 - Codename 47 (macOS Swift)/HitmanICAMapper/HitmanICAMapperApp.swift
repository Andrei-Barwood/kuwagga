import SwiftUI

@main
struct HitmanICAMapperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(Theme.darkBG)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 920, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
