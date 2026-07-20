import Foundation

/// Glint's seven-token theme model, ported to Swift. Same structure, swapped
/// tokens: light or dark, the glass never changes, only the tint and accent do.
/// Kept as hex strings so the model is pure and testable; the views turn them
/// into SwiftUI colors.
public struct ThemeTokens: Sendable, Equatable {
    /// The vibrancy tint painted behind the glass.
    public let tint: String
    /// The accent for primary actions and selection.
    public let accent: String
    /// Primary text on the glass.
    public let textPrimary: String
    /// Secondary and muted text.
    public let textSecondary: String
    /// Raised card and control surface.
    public let surface: String
    /// Hairline borders and separators.
    public let border: String
    /// Drop-shadow color under raised cards.
    public let shadow: String

    public init(tint: String, accent: String, textPrimary: String, textSecondary: String,
                surface: String, border: String, shadow: String) {
        self.tint = tint
        self.accent = accent
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.surface = surface
        self.border = border
        self.shadow = shadow
    }

    /// The seven token values in a fixed order, for validation and iteration.
    public var all: [String] { [tint, accent, textPrimary, textSecondary, surface, border, shadow] }
}

/// A named theme. `isDark` drives the underlying vibrancy material; the tokens
/// tint it.
public struct Theme: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let isDark: Bool
    public let tokens: ThemeTokens

    public init(id: String, name: String, isDark: Bool, tokens: ThemeTokens) {
        self.id = id
        self.name = name
        self.isDark = isDark
        self.tokens = tokens
    }
}

/// The built-in theme set, matching Glint's five: Aurora, Midnight, Sunset,
/// Forest, Graphite. Drop a new `Theme` in here and it appears in the picker.
public enum Themes {
    public static let aurora = Theme(
        id: "aurora", name: "Aurora", isDark: true,
        tokens: ThemeTokens(tint: "#0B1E3B", accent: "#5AC8FA", textPrimary: "#F5F8FF",
                            textSecondary: "#9FB3D0", surface: "#12294D", border: "#25406B", shadow: "#00050F"))

    public static let midnight = Theme(
        id: "midnight", name: "Midnight", isDark: true,
        tokens: ThemeTokens(tint: "#101014", accent: "#7C5CFF", textPrimary: "#F2F2F7",
                            textSecondary: "#9A9AA8", surface: "#1B1B22", border: "#2C2C36", shadow: "#000000"))

    public static let sunset = Theme(
        id: "sunset", name: "Sunset", isDark: false,
        tokens: ThemeTokens(tint: "#FFF1E6", accent: "#FF7A59", textPrimary: "#3A2318",
                            textSecondary: "#8A6C5B", surface: "#FFFFFF", border: "#F0D9C8", shadow: "#E7C4AC"))

    public static let forest = Theme(
        id: "forest", name: "Forest", isDark: true,
        tokens: ThemeTokens(tint: "#0E1F17", accent: "#4ADE80", textPrimary: "#EAF7EF",
                            textSecondary: "#8FB5A0", surface: "#152A20", border: "#274536", shadow: "#00110A"))

    public static let graphite = Theme(
        id: "graphite", name: "Graphite", isDark: false,
        tokens: ThemeTokens(tint: "#ECECEE", accent: "#3D3D42", textPrimary: "#1A1A1E",
                            textSecondary: "#6B6B73", surface: "#F7F7F8", border: "#DDDDE1", shadow: "#C5C5CB"))

    /// Every built-in theme, in picker order.
    public static let all: [Theme] = [aurora, midnight, sunset, forest, graphite]

    /// The default on first run.
    public static let `default` = midnight

    /// Look up a theme by id, falling back to the default.
    public static func byID(_ id: String) -> Theme {
        all.first { $0.id == id } ?? `default`
    }
}
