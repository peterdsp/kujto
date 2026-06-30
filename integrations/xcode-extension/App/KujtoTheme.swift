import SwiftUI

/// Design language for Kujto Studio, distilled from the AI-chat-app kits in
/// the user's Figma references: light airy surfaces, generous rounding, pill
/// chips, and a restrained pink-to-lilac accent glow reserved for hero and
/// empty states. Working data surfaces stay calm so the tool reads as serious.
enum Theme {
    static let canvas = Color(hex: 0xF5F5F5)
    static let card = Color.white
    static let accent = Color(hex: 0x7C6CF0)
    static let glowPink = Color(hex: 0xFAD0E4)
    static let glowLilac = Color(hex: 0xD9CCF7)

    static let cardRadius: CGFloat = 16
    static let chipRadius: CGFloat = 8

    /// Soft radial accent for empty and hero states only, never behind data.
    static var heroGlow: some View {
        RadialGradient(
            colors: [glowLilac.opacity(0.55), glowPink.opacity(0.35), .clear],
            center: .bottom,
            startRadius: 0,
            endRadius: 420
        )
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

/// Translucent pill chip, mirroring the kit's suggestion chips.
struct ChipStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .medium))
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.chipRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.chipRadius).stroke(.black.opacity(0.06)))
    }
}

extension View {
    func chip() -> some View { modifier(ChipStyle()) }
}
