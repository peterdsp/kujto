import SwiftUI
#if canImport(AppKit)
import AppKit

/// The real liquid glass: an `NSVisualEffectView` behind the transparent
/// SwiftUI content, the same recipe Glint uses. The theme's `isDark` picks the
/// material family; the tint token is layered over it by the panel.
public struct GlassBackground: NSViewRepresentable {
    public let isDark: Bool

    public init(isDark: Bool) {
        self.isDark = isDark
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        return view
    }

    public func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
    }
}
#else
/// Non-macOS fallback so the package still compiles; a plain tinted rectangle.
public struct GlassBackground: View {
    public let isDark: Bool
    public init(isDark: Bool) { self.isDark = isDark }
    public var body: some View {
        (isDark ? Color.black : Color.white).opacity(0.2)
    }
}
#endif
