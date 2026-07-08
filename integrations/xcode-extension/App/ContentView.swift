import SwiftUI
import AppKit
import KujtoCore

/// Root shell. The Codex is the app; ContentView only routes between the
/// first-run welcome wizard and the Codex, and applies the appearance
/// preference (light / dark / OLED / follow system).
struct ContentView: View {
    @EnvironmentObject private var model: StudioModel
    @AppStorage("kujto.hasOnboarded") private var hasOnboarded: Bool = false
    @AppStorage("kujto.appearance") private var appearanceRaw: String = KujtoAppearancePreference.system.rawValue
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var showWelcome = false

    private var preference: KujtoAppearancePreference {
        KujtoAppearancePreference(rawValue: appearanceRaw) ?? .system
    }

    /// The resolved concrete mode. System picks light or dark based on the
    /// environment; the explicit choices pass through.
    private var effectiveMode: Theme.Mode {
        switch preference {
        case .system: return systemColorScheme == .dark ? .dark : .light
        case .light:  return .light
        case .dark:   return .dark
        case .oled:   return .oled
        }
    }

    /// The SwiftUI colour scheme to force. OLED counts as dark for the
    /// system controls (buttons, text fields) - Kujto's own colours provide
    /// the true-black variant on top.
    private var forcedScheme: ColorScheme? {
        switch preference {
        case .system: return nil
        case .light:  return .light
        case .dark, .oled: return .dark
        }
    }

    var body: some View {
        // Sync Theme.currentMode BEFORE body renders. Computed colours read
        // Theme.currentMode; if this ran in .onAppear (which fires after
        // the first frame) the initial render would flash the wrong palette.
        Theme.currentMode = effectiveMode
        return content
            .id(effectiveMode)
            .preferredColorScheme(forcedScheme)
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if hasOnboarded {
                CodexView(model: model)
            } else {
                // First-run welcome renders inline instead of as a sheet.
                // Presenting a sheet during the launch-time layout drove a
                // SwiftUI main-menu invalidation loop that could pin CPU and
                // balloon memory until the OS killed the app.
                WelcomeView(model: model)
            }
        }
        .sheet(isPresented: $showWelcome) { WelcomeView(model: model) }
        .onAppear { model.loadSavedRoot() }
        .onReceive(NotificationCenter.default.publisher(for: .showKujtoWelcome)) { _ in
            showWelcome = true
        }
    }
}

// LintIssue needs to stay Hashable for the Codex's ForEach - the conformance
// was originally added when the panel first shipped and is still needed.
extension LintIssue: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(file); hasher.combine(code); hasher.combine(message)
    }
}
