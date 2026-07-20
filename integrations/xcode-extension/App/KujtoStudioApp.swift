import SwiftUI
import SwiftData

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
        .modelContainer(RiskLedgerContainer.shared)
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
        // Memory-Lens: a Kujto-owned floating window that follows the focused
        // file. A real window, not a global overlay, so it needs no
        // Accessibility or Screen Recording permission.
        Window("Memory Lens", id: "memory-lens") {
            MemoryLensView(model: model)
        }
        .defaultSize(width: 360, height: 520)

        // The native git panel (Glint's surface) plus the rules-in-commit
        // fusion, following the repo chosen in the Studio.
        Window("Git", id: "git-panel") {
            GitPanelWindowView(model: model)
        }
        .defaultSize(width: 420, height: 600)

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
