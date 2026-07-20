import SwiftUI

/// Turns the theme's hex tokens into SwiftUI colors for the views. Parsing is
/// separated from the pure `Theme` model so the model stays testable without
/// SwiftUI.
public extension Color {
    /// Parses `#RRGGBB` or `#RRGGBBAA`. Falls back to clear on a malformed hex.
    init(hex: String) {
        var string = hex
        if string.hasPrefix("#") { string.removeFirst() }
        guard let value = UInt64(string, radix: 16) else {
            self = .clear
            return
        }
        let r, g, b, a: Double
        if string.count == 8 {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        } else {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

/// Named color accessors so views read `theme.accentColor` rather than parsing
/// hex at every call site.
public extension Theme {
    var tintColor: Color { Color(hex: tokens.tint) }
    var accentColor: Color { Color(hex: tokens.accent) }
    var textPrimaryColor: Color { Color(hex: tokens.textPrimary) }
    var textSecondaryColor: Color { Color(hex: tokens.textSecondary) }
    var surfaceColor: Color { Color(hex: tokens.surface) }
    var borderColor: Color { Color(hex: tokens.border) }
    var shadowColor: Color { Color(hex: tokens.shadow) }
}
