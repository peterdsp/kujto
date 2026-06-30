import SwiftUI
import AppKit

struct ContentView: View {
    @State private var selectedPath: String = SharedConfig.resolveRootPathForDisplay() ?? ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Kujto")
                .font(.largeTitle).bold()
            Text("Pick the repo whose memory the Xcode extension should read.")
                .foregroundStyle(.secondary)

            HStack {
                Button("Choose repo...") { pickRepo() }
                if !selectedPath.isEmpty {
                    Text(selectedPath)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }

            Spacer()
            Text("In Xcode: Editor > Kujto > Show Rules for This File.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
    }

    private func pickRepo() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            SharedConfig.saveRoot(url)
            selectedPath = url.path
        }
    }
}

private extension SharedConfig {
    /// Display-only read that does not start security-scoped access.
    static func resolveRootPathForDisplay() -> String? {
        UserDefaults(suiteName: appGroup)?.string(forKey: "ruleRootPath")
    }
}
