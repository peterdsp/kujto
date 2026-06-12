import Foundation

/// Bilingual messaging. Kujto identity rule: Shqip first, English mirrored.
/// Detect language from `KUJTO_LANG` env or persisted config (`lang` key).
public enum Lang: String, Sendable {
    case sq
    case en

    public static var current: Lang = detect()

    private static func detect() -> Lang {
        if let env = ProcessInfo.processInfo.environment["KUJTO_LANG"]?.lowercased() {
            if env.hasPrefix("sq") || env == "shqip" || env == "al" { return .sq }
            if env.hasPrefix("en") { return .en }
        }
        return .en
    }
}

/// One-shot bilingual string. Pick the right side based on `Lang.current`.
public struct LMsg: Sendable {
    public let sq: String
    public let en: String

    public init(sq: String, en: String) {
        self.sq = sq
        self.en = en
    }

    public var value: String {
        switch Lang.current {
        case .sq: return sq
        case .en: return en
        }
    }
}
