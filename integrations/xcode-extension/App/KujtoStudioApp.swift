import SwiftUI

/// Minimal container app. Its only job for the extension MVP is to let the
/// user pick a repo root and share it through the App Group. This is also the
/// seed of the future Kujto Studio shell.
@main
struct KujtoStudioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 420, minHeight: 240)
        }
    }
}
