import SwiftUI
import AppKit

/// Design language for Kujto Studio.
///
/// Editorial: warm off-whites in light mode, warm dark in dark mode, true
/// black in OLED. Typography carries hierarchy; chips and colored badges
/// are used sparingly. Purple accent is scarce, reserved for the single
/// primary action per screen.
///
/// Implementation note: every colour is a dynamic `NSColor` that reads a
/// module-global `Theme.currentMode`. Changing that mode + forcing the view
/// tree to re-render (via `.id(mode)` at the root) is enough to swap themes
/// without touching any call site.
enum Theme {
    enum Mode: String, CaseIterable {
        case light, dark, oled
    }

    /// Which palette every colour resolves against. Updated by ContentView's
    /// appearance resolver. Colours are computed properties, so each SwiftUI
    /// read returns a fresh `Color` based on the current mode - no NSColor
    /// dynamic-provider caching pitfalls.
    static var currentMode: Mode = .light

    // Ground and paper.
    static var canvas: Color    { pick(light: 0xFAF7F2, dark: 0x1D1B20, oled: 0x000000) }
    static var card: Color      { pick(light: 0xFFFFFF, dark: 0x26232A, oled: 0x0A0A0A) }
    static var cardMuted: Color { pick(light: 0xF4EFE7, dark: 0x302D34, oled: 0x141414) }
    static var hairline: Color  {
        pickAlpha(light: (0x1D1B20, 0.08), dark: (0xFFFFFF, 0.12), oled: (0xFFFFFF, 0.15))
    }

    // Ink.
    static var ink: Color { pick(light: 0x1D1B20, dark: 0xF5F0EA, oled: 0xFAFAFA) }
    static var inkSecondary: Color {
        pickAlpha(light: (0x1D1B20, 0.62), dark: (0xFFFFFF, 0.65), oled: (0xFFFFFF, 0.70))
    }
    static var inkTertiary: Color {
        pickAlpha(light: (0x1D1B20, 0.42), dark: (0xFFFFFF, 0.45), oled: (0xFFFFFF, 0.48))
    }

    // Accent. Slightly lifted for dark/oled so it doesn't sink.
    static var accent: Color     { pick(light: 0x7C6CF0, dark: 0x9B8DF5, oled: 0x9B8DF5) }
    static var accentSoft: Color { pick(light: 0xEDE8FE, dark: 0x2C2841, oled: 0x14122C) }

    // Muted signal colours.
    static var danger: Color      { pick(light: 0xB8503F, dark: 0xE88374, oled: 0xE88374) }
    static var dangerSoft: Color  { pick(light: 0xF8E9E4, dark: 0x3A2621, oled: 0x1E0F0C) }
    static var warning: Color     { pick(light: 0xC58A32, dark: 0xE8AE5F, oled: 0xE8AE5F) }
    static var warningSoft: Color { pick(light: 0xF7EEDD, dark: 0x3A2E1D, oled: 0x1E1710) }
    static var success: Color     { pick(light: 0x5B8562, dark: 0x7FAE85, oled: 0x7FAE85) }
    static var successSoft: Color { pick(light: 0xEAF1EB, dark: 0x1E2E22, oled: 0x0A1810) }

    // Welcome hero glow.
    static var glowPink: Color  { pick(light: 0xFAD0E4, dark: 0x503048, oled: 0x2C1420) }
    static var glowLilac: Color { pick(light: 0xD9CCF7, dark: 0x352D5C, oled: 0x1C1730) }

    static let cardRadius: CGFloat = 18
    static let chipRadius: CGFloat = 999

    /// Soft radial accent for empty and hero states only, never behind data.
    static var heroGlow: some View {
        RadialGradient(
            colors: [glowLilac.opacity(0.55), glowPink.opacity(0.35), .clear],
            center: .bottom,
            startRadius: 0,
            endRadius: 420
        )
    }

    // MARK: - Palette helpers

    private static func pick(light: UInt32, dark: UInt32, oled: UInt32) -> Color {
        switch currentMode {
        case .light: return Color(hex: light)
        case .dark:  return Color(hex: dark)
        case .oled:  return Color(hex: oled)
        }
    }

    private static func pickAlpha(
        light: (UInt32, Double),
        dark:  (UInt32, Double),
        oled:  (UInt32, Double)
    ) -> Color {
        let value: (UInt32, Double)
        switch currentMode {
        case .light: value = light
        case .dark:  value = dark
        case .oled:  value = oled
        }
        return Color(hex: value.0).opacity(value.1)
    }
}

/// User's appearance preference, stored in AppStorage. `.system` follows the
/// OS; the other three force a specific mode.
enum KujtoAppearancePreference: String, CaseIterable, Identifiable {
    case system, light, dark, oled
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Follow system"
        case .light:  return "Light"
        case .dark:   return "Dark"
        case .oled:   return "OLED"
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green:   CGFloat((hex >> 8)  & 0xFF) / 255,
            blue:    CGFloat(hex & 0xFF) / 255,
            alpha:   alpha
        )
    }
}

// MARK: - Editorial primitives (unchanged, but pick up the new palette)

struct EditorialHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String?

    init(eyebrow: String, title: String, subtitle: String? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(Theme.inkTertiary)
            Text(title)
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
    }
}

struct PaperCard<Content: View>: View {
    enum Weight { case standard, muted }

    var weight: Weight = .standard
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(fill, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 0.5)
            )
    }

    private var fill: Color {
        switch weight {
        case .standard: return Theme.card
        case .muted:    return Theme.cardMuted
        }
    }
}

struct SoftPill: View {
    enum Tone { case neutral, accent, success, warning, danger }

    let text: String
    var tone: Tone = .neutral

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(background, in: Capsule())
    }

    private var foreground: Color {
        switch tone {
        case .neutral: return Theme.inkSecondary
        case .accent:  return Theme.accent
        case .success: return Theme.success
        case .warning: return Theme.warning
        case .danger:  return Theme.danger
        }
    }

    private var background: Color {
        switch tone {
        case .neutral: return Theme.cardMuted
        case .accent:  return Theme.accentSoft
        case .success: return Theme.successSoft
        case .warning: return Theme.warningSoft
        case .danger:  return Theme.dangerSoft
        }
    }
}
