import Foundation

/// Resolved output of `xcodebuild -showBuildSettings -json` for one target.
/// We only keep the keys we actually need (the .app path and bundle id).
public struct ResolvedBuildSettings: Sendable {
    public let target: String
    public let builtProductsDir: String
    public let fullProductName: String       // e.g. "MyApp.app"
    public let productBundleIdentifier: String?
    public let executableName: String?       // e.g. "MyApp"

    public var appPath: String {
        (builtProductsDir as NSString).appendingPathComponent(fullProductName)
    }
}

public final class BuildSettingsResolver {
    private let runner: ProcessRunner

    public init(runner: ProcessRunner = ProcessRunner()) {
        self.runner = runner
    }

    /// Asks xcodebuild for the resolved build settings so we know the exact
    /// `.app` path and bundle id without guessing platform suffixes.
    public func resolve(config: KujtoConfig, simulatorUdid: String?) throws -> ResolvedBuildSettings {
        var args: [String] = []
        if let workspace = config.workspace {
            args.append(contentsOf: ["-workspace", workspace])
        } else if let project = config.project {
            args.append(contentsOf: ["-project", project])
        }
        guard let scheme = config.scheme else {
            throw KujtoError(
                code: .schemeNotFound,
                message: LMsg(
                    sq: "Asnje skeme e konfiguruar.",
                    en: "No scheme configured."
                )
            )
        }
        args.append(contentsOf: ["-scheme", scheme])
        args.append(contentsOf: ["-configuration", config.configuration ?? "Debug"])
        if let udid = simulatorUdid {
            args.append(contentsOf: ["-destination", "platform=iOS Simulator,id=\(udid)"])
        } else if let name = config.simulatorName {
            args.append(contentsOf: ["-destination", "platform=iOS Simulator,name=\(name)"])
        }
        let derived = config.derivedDataPath ?? ".kujto/DerivedData"
        args.append(contentsOf: ["-derivedDataPath", derived])
        args.append(contentsOf: ["-showBuildSettings", "-json"])

        let result = try runner.run("xcodebuild", arguments: args)
        guard result.exitCode == 0 else {
            throw KujtoError(
                code: .process,
                message: LMsg(
                    sq: "xcodebuild -showBuildSettings deshtoi (\(result.exitCode))",
                    en: "xcodebuild -showBuildSettings failed (\(result.exitCode))"
                )
            )
        }
        guard let data = result.stdout.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw KujtoError(
                code: .process,
                message: LMsg(
                    sq: "Dalja e xcodebuild nuk u kuptua si JSON",
                    en: "Could not decode xcodebuild output as JSON"
                )
            )
        }
        // xcodebuild emits an entry per target — pick the first build action
        // entry whose buildSettings actually carry a product (skip test bundles).
        for entry in arr {
            guard
                let action = entry["action"] as? String,
                action == "build",
                let target = entry["target"] as? String,
                let settings = entry["buildSettings"] as? [String: String],
                let dir = settings["BUILT_PRODUCTS_DIR"],
                let product = settings["FULL_PRODUCT_NAME"]
            else { continue }
            if !product.hasSuffix(".app") { continue }
            return ResolvedBuildSettings(
                target: target,
                builtProductsDir: dir,
                fullProductName: product,
                productBundleIdentifier: settings["PRODUCT_BUNDLE_IDENTIFIER"],
                executableName: settings["EXECUTABLE_NAME"]
            )
        }
        throw KujtoError(
            code: .buildFailed,
            message: LMsg(
                sq: "Nuk u gjet nje .app i ndertueshem ne dalje te xcodebuild",
                en: "No buildable .app found in xcodebuild output"
            )
        )
    }
}

/// Reads `CFBundleIdentifier` and `CFBundleExecutable` straight from an
/// installed bundle, as a fallback when build settings aren't around.
public func readBundleInfo(at appPath: String) throws -> (bundleId: String, executable: String) {
    let url = URL(fileURLWithPath: appPath).appendingPathComponent("Info.plist")
    let data = try Data(contentsOf: url)
    let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
    guard
        let bundleId = plist?["CFBundleIdentifier"] as? String,
        let executable = plist?["CFBundleExecutable"] as? String
    else {
        throw KujtoError(
            code: .appInstallFailed,
            message: LMsg(
                sq: "Info.plist nuk permban CFBundleIdentifier",
                en: "Info.plist missing CFBundleIdentifier"
            )
        )
    }
    return (bundleId, executable)
}
