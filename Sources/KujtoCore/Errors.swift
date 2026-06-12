import Foundation

/// Typed error model from the case study. Every error carries a stable code
/// plus a bilingual message and an optional recovery hint.
public struct KujtoError: Error, CustomStringConvertible {
    public enum Code: String, Sendable {
        case projectNotFound = "project_not_found"
        case schemeNotFound = "scheme_not_found"
        case configurationNotFound = "configuration_not_found"
        case simulatorNotFound = "simulator_not_found"
        case simulatorBootFailed = "simulator_boot_failed"
        case deviceNotFound = "device_not_found"
        case deviceLocked = "device_locked"
        case deviceNotTrusted = "device_not_trusted"
        case deviceIncompatible = "device_incompatible"
        case provisioningFailed = "provisioning_failed"
        case noDevelopmentTeam = "no_development_team"
        case signingFailed = "signing_failed"
        case buildFailed = "build_failed"
        case testFailed = "test_failed"
        case appInstallFailed = "app_install_failed"
        case appLaunchFailed = "app_launch_failed"
        case logStreamFailed = "log_stream_failed"
        case uiElementNotFound = "ui_element_not_found"
        case uiAssertionFailed = "ui_assertion_failed"
        case timeout = "timeout"
        case unknownArgument = "unknown_argument"
        case missingRootFile = "missing_root_file"
        case refusedSelfWire = "refused_self_wire"
        case notYetImplemented = "not_yet_implemented"
        case invalidConfig = "invalid_config"
        case process = "process_error"
    }

    public let code: Code
    public let message: LMsg
    public let recovery: LMsg?

    public init(code: Code, message: LMsg, recovery: LMsg? = nil) {
        self.code = code
        self.message = message
        self.recovery = recovery
    }

    public var description: String {
        var out = "[\(code.rawValue)] \(message.value)"
        if let recovery = recovery {
            out += "\n  -> \(recovery.value)"
        }
        return out
    }

    public func ndjson() -> NDJSONEvent {
        var fields: [String: NDJSONValue] = [
            "type": .string("error"),
            "code": .string(code.rawValue),
            "message": .string(message.value)
        ]
        if let recovery = recovery {
            fields["recovery"] = .string(recovery.value)
        }
        return NDJSONEvent(fields: fields)
    }
}
