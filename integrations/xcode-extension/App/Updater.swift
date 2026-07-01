import SwiftUI

/// Bridges the app to Sparkle for the direct-distribution flavor and to the
/// Mac App Store's own update flow for the App Store flavor. The `DIRECT_BUILD`
/// compilation condition is set on the Release-Direct configuration only.
///
/// - App Store build: `Updater()` is a no-op wrapper. macOS's system
///   Software Update handles new versions.
/// - Direct build: `Updater()` wraps `SPUStandardUpdaterController` from
///   Sparkle, which reads `SUFeedURL` from Info.plist and checks the appcast.

#if DIRECT_BUILD
import Sparkle

@MainActor
final class Updater: ObservableObject {
    private let controller: SPUStandardUpdaterController

    init() {
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    func checkForUpdates() { controller.checkForUpdates(nil) }

    var canCheck: Bool { controller.updater.canCheckForUpdates }
    var lastUpdateCheck: Date? { controller.updater.lastUpdateCheckDate }
    var channelLabel: String { "Direct, Sparkle" }
}
#else

@MainActor
final class Updater: ObservableObject {
    init() {}
    func checkForUpdates() {
        // App Store build: point users at the App Store update surface.
        if let url = URL(string: "macappstore://apps.apple.com/app/id6786441748") {
            NSWorkspace.shared.open(url)
        }
    }
    var canCheck: Bool { true }
    var lastUpdateCheck: Date? { nil }
    var channelLabel: String { "App Store" }
}

import AppKit
#endif
