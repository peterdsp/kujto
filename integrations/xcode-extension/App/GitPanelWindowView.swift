import SwiftUI
import KujtoCore
import KujtoGit
import KujtoStudioUI

/// Hosts the native git panel (Glint's surface) in its own window, following
/// the repo the user has chosen in the Studio. It is deliberately decoupled
/// from `StudioModel`'s internals: it loads its own `RuleIndex` from the repo
/// so the rules-in-commit fusion lights up without reaching into private state.
///
/// `KujtoStudioUI` defines its own `Theme`; the app also has an `enum Theme`.
/// Every `KujtoStudioUI` type is qualified here so the two never collide.
struct GitPanelWindowView: View {
    @ObservedObject var model: StudioModel
    @State private var panel: KujtoStudioUI.GitPanelModel?

    var body: some View {
        Group {
            if let panel {
                KujtoStudioUI.GitPanelView(model: panel)
            } else {
                noRepo
            }
        }
        .frame(minWidth: 380, minHeight: 460)
        .onAppear { rebuild() }
        .onChange(of: model.rootPath) { _, _ in rebuild() }
    }

    private var noRepo: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Choose a repository in Kujto Studio first.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    /// Rebuilds the panel model for the current repo. The inspector is best
    /// effort: a repo whose memory does not load yet still gets a working git
    /// panel, just without the rules strip.
    private func rebuild() {
        guard let rootPath = model.rootPath else {
            panel = nil
            return
        }
        let root = URL(fileURLWithPath: rootPath)
        let client = ShellGitClient()
        let index = try? RuleIndex.load(root: root)
        let inspector = index.map { KujtoStudioUI.CommitInspector(index: $0, root: root) }
        let history = index.map { KujtoStudioUI.HistoryLinker(client: client, index: $0, root: root) }
        panel = KujtoStudioUI.GitPanelModel(
            repo: root,
            client: client,
            theme: KujtoStudioUI.Themes.default,
            inspector: inspector,
            historyLinker: history)
    }
}
