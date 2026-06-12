import Foundation
import KujtoCore

/// Shared helper used by the few subcommands that still wrap unfinished
/// phases (currently only Phase 7's editor extension surface). Emits a
/// typed error so agents see `not_yet_implemented` with a stable recovery
/// hint and exits with code 75 (EX_TEMPFAIL).
func notYetImplemented(phase: String, command: String, emitter: EventEmitter) -> Never {
    emitter.emitError(KujtoError(
        code: .notYetImplemented,
        message: LMsg(
            sq: "`kujto \(command)` jo ende e implementuar (Faza \(phase) e udherrefyesit).",
            en: "`kujto \(command)` not yet implemented (case study Phase \(phase))."
        ),
        recovery: LMsg(
            sq: "Shih docs/orchard-cli.md per pamjen e komandes dhe gjurmen e implementimit.",
            en: "See docs/orchard-cli.md for the command surface and implementation trail."
        )
    ))
    Foundation.exit(75)
}
