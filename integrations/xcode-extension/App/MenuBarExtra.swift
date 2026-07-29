import SwiftUI
import KujtoSync

/// A discreet menu bar item that shows the current repo's memory health at a
/// glance, and gives one-click access to the four main destinations of the
/// Studio window. Toggled from Settings > General.
struct KujtoMenuBar: View {
    @ObservedObject var model: StudioModel
    @ObservedObject private var sync = MemorySyncService.shared
    @ObservedObject private var accounts = AccountsService.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let root = model.rootPath {
            Text((root as NSString).lastPathComponent).font(.system(size: 11))
        } else {
            Text("No repo chosen").font(.system(size: 11)).foregroundStyle(.secondary)
        }
        if sync.isRunning {
            Text("Memory sync: \(sync.status.rawValue)").font(.system(size: 11)).foregroundStyle(.secondary)
        }
        Divider()
        accountsSection
        Divider()
        Button("Open Kujto Studio") { activateWindow() }
        Button("Show Memory Map") { openDestination(.agents) }.disabled(model.rootPath == nil)
        Button("Show Lint (\(model.lintIssues.count))") { openDestination(.lint) }.disabled(model.rootPath == nil)
        Button("Show Agents (\(model.linkedAgentCount)/\(model.agents.count))") { openDestination(.agents) }
            .disabled(model.rootPath == nil)
        Button("Show Git") { openWindow(id: "git-panel"); activateWindow() }
            .disabled(model.rootPath == nil)
        Divider()
        Button("Quit Kujto Studio") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    /// The account selector: the active account with its usage, then every
    /// other account as a one-click switch. Kept flat (no submenu) so changing
    /// account is a single gesture from the menu bar.
    @ViewBuilder
    private var accountsSection: some View {
        if let active = accounts.active {
            Text("Account: \(active.label)").font(.system(size: 11))
            if let usage = accounts.usage(for: active) {
                Text(usage.summary).font(.system(size: 11)).foregroundStyle(.secondary)
                if !usage.modelBreakdown.isEmpty {
                    let top = usage.modelBreakdown.prefix(2).map { slice in
                        var name = slice.model
                        if name.hasPrefix("claude-") { name = String(name.dropFirst(7)) }
                        let pct = usage.totalTokens > 0
                            ? Int(Double(slice.totalTokens) / Double(usage.totalTokens) * 100)
                            : 0
                        return "\(name) \(pct)%"
                    }.joined(separator: ", ")
                    Text(top).font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        } else {
            Text("No account selected").font(.system(size: 11)).foregroundStyle(.secondary)
        }

        ForEach(accounts.roster.profiles.filter { $0.id != accounts.roster.activeID }) { profile in
            Button("Switch to \(profile.label)\(profile.isReady ? "" : " (incomplete)")") {
                accounts.activate(profile.id,
                                  repoRoot: model.rootPath.map { URL(fileURLWithPath: $0) })
            }
            .disabled(!profile.isReady)
        }

        Button("Manage accounts...") {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            activateWindow()
        }
    }

    private func openDestination(_ destination: StudioModel.Destination) {
        model.destination = destination
        activateWindow()
    }

    private func activateWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
