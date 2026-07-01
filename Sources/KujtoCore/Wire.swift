import Foundation

/// Ports the original Kujto wire/unwire logic from the old `main.swift` into a
/// reusable service that command structs can call. Behavior preserved: same
/// symlink set, same refusal to wire into the Kujto repo itself.
public final class WireService {
    public struct Options {
        public var target: URL
        public var wireMemory: Bool
        public var copyFiles: Bool

        public init(
            target: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
            wireMemory: Bool = false,
            copyFiles: Bool = false
        ) {
            self.target = target
            self.wireMemory = wireMemory
            self.copyFiles = copyFiles
        }
    }

    public let root: URL
    private let emitter: EventEmitter

    public init(root: URL, emitter: EventEmitter) {
        self.root = root
        self.emitter = emitter
    }

    public func wire(_ options: Options) throws {
        let agents = try require("AGENTS.md")
        let memory = try require("memory")
        let target = options.target.standardizedFileURL

        if target.path == root.standardizedFileURL.path {
            throw KujtoError(
                code: .refusedSelfWire,
                message: LMsg(
                    sq: "Po refuzoj te lidh Kujto-n ne vetvete.",
                    en: "Refusing to wire Kujto into itself."
                )
            )
        }

        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

        for name in ["AGENTS.md", "CLAUDE.md", "CODEX.md", "GEMINI.md", ".cursorrules"] {
            try linkOrCopy(
                source: agents,
                destination: target.appendingPathComponent(name),
                copyFiles: options.copyFiles
            )
        }

        // Copilot reads `.github/copilot-instructions.md`. Ensure the
        // `.github/` directory exists first so the symlink target is valid.
        let githubDir = target.appendingPathComponent(".github")
        try FileManager.default.createDirectory(at: githubDir, withIntermediateDirectories: true)
        try linkOrCopy(
            source: agents,
            destination: githubDir.appendingPathComponent("copilot-instructions.md"),
            copyFiles: options.copyFiles
        )

        if options.wireMemory {
            try linkOrCopy(
                source: memory,
                destination: target.appendingPathComponent("memory"),
                copyFiles: options.copyFiles
            )
        }
    }

    public func unwire(at target: URL) throws {
        for name in ["AGENTS.md", "CLAUDE.md", "CODEX.md", "GEMINI.md", ".cursorrules", "memory"] {
            try removeSymlink(named: name, in: target)
        }
        try removeSymlink(named: ".github/copilot-instructions.md", in: target)
    }

    // MARK: - helpers

    private func require(_ relativePath: String) throws -> URL {
        let url = root.appendingPathComponent(relativePath)
        if !FileManager.default.fileExists(atPath: url.path) {
            throw KujtoError(
                code: .missingRootFile,
                message: LMsg(
                    sq: "Skedari i kerkuar i Kujto-s nuk u gjet: \(relativePath)",
                    en: "Required Kujto file not found: \(relativePath)"
                )
            )
        }
        return url
    }

    private func linkOrCopy(source: URL, destination: URL, copyFiles: Bool) throws {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory) {
            emitter.emit(type: "wire_skip", ["name": .string(destination.lastPathComponent)])
            return
        }
        if copyFiles {
            try FileManager.default.copyItem(at: source, to: destination)
            emitter.emit(type: "wire_copied", ["name": .string(destination.lastPathComponent)])
        } else {
            try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: source)
            emitter.emit(type: "wire_linked", ["name": .string(destination.lastPathComponent)])
        }
    }

    private func removeSymlink(named name: String, in target: URL) throws {
        let destination = target.appendingPathComponent(name)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory) else {
            emitter.emit(type: "wire_skip", ["name": .string(name), "reason": .string("not_present")])
            return
        }
        let values = try destination.resourceValues(forKeys: [.isSymbolicLinkKey])
        if values.isSymbolicLink == true {
            try FileManager.default.removeItem(at: destination)
            emitter.emit(type: "wire_removed", ["name": .string(name)])
        } else {
            emitter.emit(type: "wire_skip", ["name": .string(name), "reason": .string("not_a_symlink")])
        }
    }
}
