import SwiftUI

/// Kujto Studio, the standalone Mac app. Hosts the SwiftUI shell plus the
/// first-run welcome wizard and Settings scene. All state lives on a single
/// StudioModel shared through .environmentObject.
@main
struct KujtoStudioApp: App {
    @StateObject private var model = StudioModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 820, minHeight: 520)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Show Welcome...") {
                    NotificationCenter.default.post(name: .showKujtoWelcome, object: nil)
                }
                .keyboardShortcut("W", modifiers: [.command, .shift])
            }
        }
        Settings { SettingsView(model: model) }
    }
}

extension Notification.Name {
    static let showKujtoWelcome = Notification.Name("dev.peterdsp.kujto.showWelcome")
}
