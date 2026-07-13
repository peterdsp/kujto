import ArgumentParser
import Foundation
import KujtoCore

/// `kujto localize audit`: check an Xcode String Catalog (`.xcstrings`) for a
/// target locale, reporting missing translations, needs-review entries, and
/// placeholder mismatches. Aligns with Kujto's localization policy (English
/// source, Albanian `sq` as a locale).
struct LocalizeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "localize",
        abstract: "Localization tooling for String Catalogs (.xcstrings).",
        subcommands: [Audit.self]
    )

    struct Audit: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "audit",
            abstract: "Audit a .xcstrings catalog for a target locale."
        )
        @OptionGroup var global: GlobalOptions
        @Argument(help: "Path to the .xcstrings catalog.") var catalog: String
        @Option(name: .long, help: "Target locale to audit (default sq).") var locale: String = "sq"
        @Flag(name: .long, help: "Exit non-zero if any finding is reported.") var strict: Bool = false

        func run() {
            let emitter = global.makeEmitter()
            runOrExit(emitter) {
                let url = URL(fileURLWithPath: catalog)
                guard let data = try? Data(contentsOf: url) else {
                    throw KujtoError(
                        code: .missingRootFile,
                        message: LMsg(
                            sq: "Nuk munda te lexoj katalogun: \(catalog)",
                            en: "Could not read catalog: \(catalog)"
                        )
                    )
                }
                let findings = try LocalizationAudit.audit(catalogData: data, locale: locale)
                for f in findings {
                    if global.json {
                        emitter.emit(type: "localization_finding", [
                            "key": .string(f.key),
                            "locale": .string(f.locale),
                            "kind": .string(f.kind.rawValue),
                            "detail": f.detail.map { .string($0) } ?? .null
                        ])
                    } else {
                        var line = "\(f.kind.rawValue): \(f.key)"
                        if let detail = f.detail { line += " (\(detail))" }
                        print(line)
                    }
                }
                if !global.json {
                    print("\(findings.count) finding(s) for locale '\(locale)'.")
                }
                if strict && !findings.isEmpty { Foundation.exit(ExitCode.failure) }
            }
        }
    }
}
