import Foundation

/// One issue found in a String Catalog for a given target locale.
public struct LocalizationFinding: Sendable, Equatable {
    public enum Kind: String, Sendable {
        case missing            // no translation for the locale at all
        case needsReview        // present but marked needs_review / new
        case placeholderMismatch // format specifiers differ from the source
    }

    public let key: String
    public let locale: String
    public let kind: Kind
    public let detail: String?

    public init(key: String, locale: String, kind: Kind, detail: String? = nil) {
        self.key = key
        self.locale = locale
        self.kind = kind
        self.detail = detail
    }
}

/// Audits an Xcode String Catalog (`.xcstrings`) for a target locale, the
/// Swift-native counterpart to the skill's `localization_audit.py`. Reinforces
/// Kujto's localization policy: English source, Albanian (`sq`) as a locale.
///
/// Reported issues per key:
///  - `missing`: the key has no `stringUnit` for the locale (and isn't opted
///    out via `shouldTranslate: false`).
///  - `needsReview`: the translation exists but its state is `needs_review`
///    or `new`.
///  - `placeholderMismatch`: the translated value's format specifiers
///    (`%@`, `%lld`, `%1$@`, ...) don't match the source string's.
public enum LocalizationAudit {
    public static func audit(catalogData: Data, locale: String) throws -> [LocalizationFinding] {
        guard
            let root = try? JSONSerialization.jsonObject(with: catalogData) as? [String: Any],
            let strings = root["strings"] as? [String: Any]
        else {
            throw KujtoError(
                code: .invalidConfig,
                message: LMsg(
                    sq: "Katalogu i vargjeve nuk eshte i vlefshem (.xcstrings)",
                    en: "Invalid string catalog (.xcstrings)"
                )
            )
        }
        let sourceLanguage = root["sourceLanguage"] as? String ?? "en"
        var findings: [LocalizationFinding] = []

        // Auditing the source language against itself is a no-op.
        guard locale != sourceLanguage else { return findings }

        for key in strings.keys.sorted() {
            guard let entry = strings[key] as? [String: Any] else { continue }
            // Keys explicitly opted out of translation are not "missing".
            if let shouldTranslate = entry["shouldTranslate"] as? Bool, shouldTranslate == false {
                continue
            }

            let localizations = entry["localizations"] as? [String: Any] ?? [:]
            let sourceValue = stringUnitValue(localizations[sourceLanguage]) ?? key

            guard let localeNode = localizations[locale] as? [String: Any] else {
                findings.append(LocalizationFinding(key: key, locale: locale, kind: .missing))
                continue
            }

            // Pluralized / device variations aren't a flat stringUnit; we can't
            // compare a single value, so we only confirm presence for them.
            guard let unit = localeNode["stringUnit"] as? [String: Any] else {
                continue
            }

            let state = unit["state"] as? String
            if state == "needs_review" || state == "new" {
                findings.append(LocalizationFinding(
                    key: key, locale: locale, kind: .needsReview,
                    detail: state
                ))
            }

            if let value = unit["value"] as? String {
                let src = formatSpecifiers(in: sourceValue)
                let dst = formatSpecifiers(in: value)
                if src != dst {
                    findings.append(LocalizationFinding(
                        key: key, locale: locale, kind: .placeholderMismatch,
                        detail: "source \(src) vs \(locale) \(dst)"
                    ))
                }
            }
        }
        return findings
    }

    private static func stringUnitValue(_ node: Any?) -> String? {
        guard let node = node as? [String: Any],
              let unit = node["stringUnit"] as? [String: Any],
              let value = unit["value"] as? String else { return nil }
        return value
    }

    /// Extracts printf-style format specifiers, normalized and sorted so two
    /// strings with the same placeholders (in any order) compare equal. `%%`
    /// is an escaped percent, not a specifier, so it's dropped.
    static func formatSpecifiers(in s: String) -> [String] {
        let pattern = "%(?:\\d+\\$)?[-+ 0#]*\\d*(?:\\.\\d+)?(?:ll|hh|[lhqLztj])?[@dDiuUxXoObcsfeEgGaApn%]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        var out: [String] = []
        for match in regex.matches(in: s, range: range) {
            guard let r = Range(match.range, in: s) else { continue }
            let token = String(s[r])
            if token == "%%" { continue }
            out.append(token)
        }
        return out.sorted()
    }
}
