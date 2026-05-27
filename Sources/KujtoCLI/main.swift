import Foundation

enum KujtoError: Error, CustomStringConvertible {
    case unknownArgument(String)
    case missingRootFile(String)
    case refusedSelfWire

    var description: String {
        switch self {
        case .unknownArgument(let value):
            return "Unknown argument: \(value)"
        case .missingRootFile(let value):
            return "Required Kujto file not found: \(value)"
        case .refusedSelfWire:
            return "Refusing to wire Kujto into itself."
        }
    }
}

struct Options {
    var target = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    var wireMemory = false
    var unwire = false
    var copyFiles = false
}

let root = URL(fileURLWithPath: #file)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

func printHelp() {
    print("""
    Kujto

    Usage:
      kujto wire [--target PATH] [--memory] [--copy]
      kujto unwire [--target PATH]
      kujto root

    Commands:
      wire     Link AGENTS.md aliases into a repository.
      unwire   Remove Kujto symlinks from a repository.
      root     Print the Kujto package checkout path.
    """)
}

func parseOptions(arguments: [String]) throws -> (String, Options) {
    guard let command = arguments.first else {
        return ("help", Options())
    }

    var options = Options()
    var index = 1

    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "--memory":
            options.wireMemory = true
        case "--copy":
            options.copyFiles = true
        case "--target":
            index += 1
            guard index < arguments.count else {
                throw KujtoError.unknownArgument("--target")
            }
            options.target = URL(fileURLWithPath: arguments[index])
        default:
            throw KujtoError.unknownArgument(argument)
        }
        index += 1
    }

    if command == "unwire" {
        options.unwire = true
    }

    return (command, options)
}

func require(_ relativePath: String) throws -> URL {
    let url = root.appendingPathComponent(relativePath)
    if !FileManager.default.fileExists(atPath: url.path) {
        throw KujtoError.missingRootFile(relativePath)
    }
    return url
}

func removeSymlink(named name: String, in target: URL) throws {
    let destination = target.appendingPathComponent(name)
    var isDirectory: ObjCBool = false

    guard FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory) else {
        print("skip \(name), not present")
        return
    }

    let values = try destination.resourceValues(forKeys: [.isSymbolicLinkKey])
    if values.isSymbolicLink == true {
        try FileManager.default.removeItem(at: destination)
        print("removed \(name)")
    } else {
        print("skip \(name), not a symlink")
    }
}

func linkOrCopy(source: URL, destination: URL, copyFiles: Bool) throws {
    var isDirectory: ObjCBool = false

    if FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory) {
        print("skip \(destination.lastPathComponent), already exists")
        return
    }

    if copyFiles {
        try FileManager.default.copyItem(at: source, to: destination)
        print("copied \(destination.lastPathComponent)")
    } else {
        try FileManager.default.createSymbolicLink(
            at: destination,
            withDestinationURL: source
        )
        print("linked \(destination.lastPathComponent)")
    }
}

func wire(options: Options) throws {
    let agents = try require("AGENTS.md")
    let memory = try require("memory")
    let target = options.target.standardizedFileURL

    if target.path == root.standardizedFileURL.path {
        throw KujtoError.refusedSelfWire
    }

    try FileManager.default.createDirectory(
        at: target,
        withIntermediateDirectories: true
    )

    for name in ["AGENTS.md", "CLAUDE.md", "CODEX.md", "GEMINI.md"] {
        try linkOrCopy(
            source: agents,
            destination: target.appendingPathComponent(name),
            copyFiles: options.copyFiles
        )
    }

    if options.wireMemory {
        try linkOrCopy(
            source: memory,
            destination: target.appendingPathComponent("memory"),
            copyFiles: options.copyFiles
        )
    }
}

func unwire(options: Options) throws {
    for name in ["AGENTS.md", "CLAUDE.md", "CODEX.md", "GEMINI.md", "memory"] {
        try removeSymlink(named: name, in: options.target)
    }
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    let (command, options) = try parseOptions(arguments: arguments)

    switch command {
    case "help", "-h", "--help":
        printHelp()
    case "root":
        print(root.path)
    case "wire":
        try wire(options: options)
    case "unwire":
        try unwire(options: options)
    default:
        throw KujtoError.unknownArgument(command)
    }
} catch {
    fputs("kujto: \(error)\n", stderr)
    exit(1)
}
