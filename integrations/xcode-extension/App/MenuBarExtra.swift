import SwiftUI
import KujtoSync

/// A discreet menu bar item that shows the current repo's memory health at a
/// glance, and gives one-click access to the four main destinations of the
/// Studio window. Toggled from Settings > General.
struct KujtoMenuBar: View {
    @ObservedObject var model: StudioModel
    @ObservedObject private var sync = MemorySyncService.shared
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
