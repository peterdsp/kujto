import Foundation

/// Centralised exit code matrix so CI runners (and humans) can switch on
/// numeric codes without parsing NDJSON. Aligned with the case study's
/// Phase 7 "deterministic exit codes" rule.
public enum ExitCode {
    /// Everything succeeded.
    public static let success: Int32 = 0
    /// Operation ran but reported a logical failure (build error, test
    /// failed, UI assertion failed). Distinct from internal errors so CI
    /// can fail the job without alerting on infra issues.
    public static let failure: Int32 = 1
    /// CLI misuse (missing flag, conflicting options).
    public static let usage: Int32 = 2
    /// Configuration is invalid (bad JSON, missing required keys).
    public static let invalidConfig: Int32 = 78
    /// An internal error happened (process crash, IO error).
    public static let internalError: Int32 = 70
    /// The wrapped command (xcodebuild, simctl, devicectl) was missing.
    public static let missingTool: Int32 = 127
    /// The user asked for a phase that hasn't shipped yet.
    public static let notImplemented: Int32 = 75
    /// A timeout fired before the wrapped command finished.
    public static let timeout: Int32 = 124

    /// Maps a typed error code to the matching exit code. The default for
    /// unmapped codes is `internalError`, never `success`, we never swallow
    /// errors silently.
    public static func forKujtoError(_ code: KujtoError.Code) -> Int32 {
        switch code {
        case .buildFailed, .testFailed, .uiAssertionFailed, .uiElementNotFound,
             .appInstallFailed, .appLaunchFailed:
            return failure
        case .unknownArgument, .missingRootFile:
            return usage
        case .invalidConfig:
            return invalidConfig
        case .notYetImplemented:
            return notImplemented
        case .timeout:
            return timeout
        case .deviceNotFound, .simulatorNotFound, .schemeNotFound, .configurationNotFound,
             .projectNotFound:
            return failure
        case .signingFailed, .deviceLocked, .deviceNotTrusted, .deviceIncompatible,
             .provisioningFailed, .noDevelopmentTeam:
            return failure
        case .simulatorBootFailed, .logStreamFailed:
            return internalError
        case .refusedSelfWire:
            return usage
        case .process:
            return internalError
        }
    }
}
