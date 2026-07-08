import SwiftUI

/// Kujto Studio, the standalone Mac app. Hosts the SwiftUI shell plus the
/// first-run welcome wizard and Settings scene. All state lives on a single
/// StudioModel shared through .environmentObject.
@main
struct KujtoStudioApp: App {
    @StateObject private var model = StudioModel()
    @StateObject private var updater = Updater()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 820, minHeight: 520)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") { updater.checkForUpdates() }
                    .disabled(!updater.canCheck)
                Divider()
                Button("Show Welcome...") {
                    NotificationCenter.default.post(name: .showKujtoWelcome, object: nil)
                }
                .keyboardShortcut("W", modifiers: [.command, .shift])
            }
        }
        Settings { SettingsView(model: model, updater: updater) }

        // NOTE: `MenuBarExtra`'s `isInserted:` overload is intentionally NOT
        // used. On macOS 26.5, coupling it to an `@AppStorage`-backed binding
        // drives an infinite main-menu invalidation loop that pins CPU and
        // balloons memory until the OS kills the app.
        MenuBarExtra("Kujto", image: "QeleshMenubar") {
            KujtoMenuBar(model: model)
        }
        .menuBarExtraStyle(.menu)
    }
}

extension Notification.Name {
    static let showKujtoWelcome = Notification.Name("dev.peterdsp.kujto.showWelcome")
}
