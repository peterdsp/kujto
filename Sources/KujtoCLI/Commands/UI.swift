import ArgumentParser
import Foundation
import KujtoCore

/// Phase 6: file-based UI session driver.
/// `ui session start`  launches the XCTest harness as a child process,
/// stamps `.kujto/runtime/ui/<id>/session.json` with the runner PID.
/// `ui find/tap/...`   submit a `cmd-<n>.json` and block on `result-<n>.json`.
/// `ui session stop`   kills the runner PID and clears the session file.
///
/// Setup the runner once: drop `integrations/xctest-runner/KujtoUISession.swift`
/// into your UI test target, then configure the test scheme name in
/// `.kujto/config.json` under `uiTestScheme`.

struct UICommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ui",
        abstract: "UI automation (screenshot, find, tap, type, assert) backed by an XCTest runner.",
        subcommands: [Screen.self, SessionGroup.self, Find.self, Tap.self, DoubleTap.self, TypeAction.self, Erase.self, Scroll.self, Swipe.self, Wait.self, OpenURL.self, Assert.self]
    )

    struct Screen: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "screen",
            abstract: "Capture screenshot via simctl; accessibility tree via the runner if a session is active."
        )
        @OptionGroup var global: GlobalOptions

        func run() {
            let emitter = global.makeEmitter()
            runOrExit(emitter) {
                let store = try ArtifactStore()
                try FileManager.default.createDirectory(at: store.screenshotsDir, withIntermediateDirectories: true)
                let path = store.screenshotsDir.appendingPathComponent("screen.png")

                let sim = SimulatorController()
                let config = try global.loadConfig()
                let udid = try sim.resolveUdid(name: config.simulatorName, udid: config.simulatorUdid)
                try sim.screenshot(udid: udid, output: path)

                // If a session is running, also ask the runner for an accessibility tree.
                let client = try UICLI.client(forSessionId: nil)
                if let session = try client?.readSession() {
                    let seq = try client!.nextSeq()
                    let result = try client!.submit(KujtoCore.UICommand(seq: seq, action: .screen))
                    emitter.emit(type: "ui_snapshot", [
                        "screenshot": .string(path.path),
                        "tree": result.tree.map { .string($0) } ?? .null,
                        "session_id": .string(session.id)
                    ])
                } else {
                    emitter.emit(type: "ui_snapshot", [
                        "screenshot": .string(path.path),
                        "tree": .null,
                        "tree_status": .string("no_active_session")
                    ])
                }
            }
        }
    }

    struct SessionGroup: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "session",
            abstract: "Manage the XCTest UI runner session.",
            subcommands: [Start.self, Stop.self, Status.self]
        )

        struct Start: ParsableCommand {
            static let configuration = CommandConfiguration(commandName: "start", abstract: "Launch the XCTest runner.")
            @OptionGroup var global: GlobalOptions

            @Option(name: .long, help: "Override the UI test scheme name.")
            var scheme: String?

            @Option(name: .long, help: "Bundle id of the app under test (defaults to the configured product).")
            var bundleId: String?

            @Option(name: .long, help: "Idle exit timeout in seconds (default 600).")
            var idleSeconds: Int?

            func run() {
                let emitter = global.makeEmitter()
                runOrExit(emitter) {
                    let config = try global.loadConfig()
                    guard let uiScheme = scheme ?? config.uiTestScheme else {
                        throw KujtoError(
                            code: .schemeNotFound,
                            message: LMsg(
                                sq: "Asnje skeme UI teste e konfiguruar. Ekzekuto `kujto config set --ui-test-scheme NAME`.",
                                en: "No UI test scheme configured. Run `kujto config set --ui-test-scheme NAME`."
                            )
                        )
                    }

                    let sim = SimulatorController()
                    let udid = try sim.resolveUdid(name: config.simulatorName, udid: config.simulatorUdid)
                    _ = try? sim.boot(udid: udid)

                    // Each session lives under .kujto/runtime/ui/<id>/.
                    let sessionId = "ui_" + UICLI.timestamp()
                    let dir = UISessionClient.defaultRoot().appendingPathComponent(sessionId)
                    let client = UISessionClient(directory: dir)
                    try client.ensureDirectory()

                    var args: [String] = []
                    if let workspace = config.workspace {
                        args.append(contentsOf: ["-workspace", workspace])
                    } else if let project = config.project {
                        args.append(contentsOf: ["-project", project])
                    }
                    args.append(contentsOf: [
                        "-scheme", uiScheme,
                        "-destination", "platform=iOS Simulator,id=\(udid)",
                        "test-without-building"
                    ])
                    // Only run the session driver test method so other UI
                    // tests in the target don't get pulled into the loop.
                    args.append(contentsOf: ["-only-testing:\(uiScheme)/KujtoUISession/testRunSession"])

                    var env = ProcessInfo.processInfo.environment
                    env["KUJTO_UI_SESSION_DIR"] = dir.path
                    if let bundleId = bundleId { env["KUJTO_UI_BUNDLE_ID"] = bundleId }
                    if let idle = idleSeconds { env["KUJTO_UI_IDLE_EXIT_S"] = String(idle) }

                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
                    process.arguments = ["xcodebuild"] + args
                    process.environment = env
                    // Discard output so we don't block the parent on a full
                    // pipe; the runner writes everything we care about to
                    // the session directory.
                    process.standardOutput = FileHandle(forWritingAtPath: "/dev/null")
                    process.standardError = FileHandle(forWritingAtPath: "/dev/null")
                    try process.run()

                    let session = UISessionClient.Session(
                        id: sessionId,
                        runnerPid: Int(process.processIdentifier),
                        bundleId: bundleId,
                        startedAt: UICLI.isoNow()
                    )
                    try client.writeSession(session)
                    // Mirror the latest session id under the parent dir so
                    // one-shot ui commands can locate it without a flag.
                    try UICLI.writeActiveSession(sessionId: sessionId)

                    emitter.emit(type: "ui_action", [
                        "kind": .string("session_start"),
                        "session_id": .string(sessionId),
                        "pid": .int(session.runnerPid),
                        "directory": .string(dir.path)
                    ])
                    if !global.json {
                        print("✓ UI session \(sessionId) started (pid \(session.runnerPid))")
                        print("  dir: \(dir.path)")
                    }
                }
            }
        }

        struct Stop: ParsableCommand {
            static let configuration = CommandConfiguration(commandName: "stop", abstract: "Kill the active UI runner.")
            @OptionGroup var global: GlobalOptions

            @Option(name: .long, help: "Session id (defaults to the active one).")
            var session: String?

            func run() {
                let emitter = global.makeEmitter()
                runOrExit(emitter) {
                    guard let client = try UICLI.client(forSessionId: session) else {
                        throw KujtoError(
                            code: .appLaunchFailed,
                            message: LMsg(sq: "Asnje sesion UI aktiv.", en: "No active UI session.")
                        )
                    }
                    let s = try client.readSession()
                    if let pid = s?.runnerPid { kill(pid_t(pid), SIGTERM) }
                    try? FileManager.default.removeItem(at: client.directory.appendingPathComponent("session.json"))
                    UICLI.clearActiveSession()
                    emitter.emit(type: "ui_action", [
                        "kind": .string("session_stop"),
                        "session_id": .string(s?.id ?? "")
                    ])
                }
            }
        }

        struct Status: ParsableCommand {
            static let configuration = CommandConfiguration(commandName: "status", abstract: "Show the active UI session.")
            @OptionGroup var global: GlobalOptions
            func run() {
                let emitter = global.makeEmitter()
                runOrExit(emitter) {
                    guard let client = try UICLI.client(forSessionId: nil),
                          let s = try client.readSession() else {
                        if !global.json { print("(no active UI session)") }
                        return
                    }
                    emitter.emit(type: "ui_action", [
                        "kind": .string("session_status"),
                        "session_id": .string(s.id),
                        "pid": .int(s.runnerPid),
                        "bundle_id": s.bundleId.map { .string($0) } ?? .null,
                        "started_at": .string(s.startedAt)
                    ])
                    if !global.json {
                        print("session: \(s.id)")
                        print("pid:     \(s.runnerPid)")
                        if let bid = s.bundleId { print("bundle:  \(bid)") }
                        print("dir:     \(client.directory.path)")
                    }
                }
            }
        }
    }

    struct Find: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "find", abstract: "Find a UI element by selector.")
        @OptionGroup var global: GlobalOptions
        @OptionGroup var sel: SelectorOptions
        func run() { UICLI.runOneShot(global: global, action: .find, sel: sel) }
    }

    struct Tap: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "tap", abstract: "Tap a UI element.")
        @OptionGroup var global: GlobalOptions
        @OptionGroup var sel: SelectorOptions
        func run() { UICLI.runOneShot(global: global, action: .tap, sel: sel) }
    }

    struct DoubleTap: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "double-tap", abstract: "Double-tap a UI element.")
        @OptionGroup var global: GlobalOptions
        @OptionGroup var sel: SelectorOptions
        func run() { UICLI.runOneShot(global: global, action: .doubleTap, sel: sel) }
    }

    struct TypeAction: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "type", abstract: "Type text into the focused field or a selector.")
        @OptionGroup var global: GlobalOptions
        @OptionGroup var sel: SelectorOptions
        @Argument(help: "Text to type.") var text: String
        func run() { UICLI.runOneShot(global: global, action: .type, sel: sel, text: text) }
    }

    struct Erase: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "erase", abstract: "Erase the contents of a field.")
        @OptionGroup var global: GlobalOptions
        @OptionGroup var sel: SelectorOptions
        func run() { UICLI.runOneShot(global: global, action: .erase, sel: sel) }
    }

    struct Scroll: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "scroll", abstract: "Scroll a view (up | down | left | right).")
        @OptionGroup var global: GlobalOptions
        @OptionGroup var sel: SelectorOptions
        @Option(name: .long, help: "Direction: up | down | left | right.") var direction: String = "up"
        func run() { UICLI.runOneShot(global: global, action: .scroll, sel: sel, direction: direction) }
    }

    struct Swipe: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "swipe", abstract: "Swipe a view (up | down | left | right).")
        @OptionGroup var global: GlobalOptions
        @OptionGroup var sel: SelectorOptions
        @Option(name: .long, help: "Direction.") var direction: String = "left"
        func run() { UICLI.runOneShot(global: global, action: .swipe, sel: sel, direction: direction) }
    }

    struct Wait: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "wait", abstract: "Wait for N seconds.")
        @OptionGroup var global: GlobalOptions
        @Argument(help: "Seconds to wait.") var seconds: Double = 1.0
        func run() { UICLI.runOneShot(global: global, action: .wait, sel: SelectorOptions(), seconds: seconds) }
    }

    struct OpenURL: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "open-url", abstract: "Open a deep link in the system browser.")
        @OptionGroup var global: GlobalOptions
        @Argument(help: "URL to open.") var url: String
        func run() { UICLI.runOneShot(global: global, action: .openURL, sel: SelectorOptions(), url: url) }
    }

    struct Assert: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "assert",
            abstract: "Assert UI state.",
            subcommands: [Visible.self, Hidden.self, Text.self]
        )

        struct Visible: ParsableCommand {
            static let configuration = CommandConfiguration(commandName: "visible", abstract: "Assert an element is visible.")
            @OptionGroup var global: GlobalOptions
            @OptionGroup var sel: SelectorOptions
            func run() { UICLI.runOneShot(global: global, action: .assertVisible, sel: sel) }
        }

        struct Hidden: ParsableCommand {
            static let configuration = CommandConfiguration(commandName: "hidden", abstract: "Assert an element is hidden.")
            @OptionGroup var global: GlobalOptions
            @OptionGroup var sel: SelectorOptions
            func run() { UICLI.runOneShot(global: global, action: .assertHidden, sel: sel) }
        }

        struct Text: ParsableCommand {
            static let configuration = CommandConfiguration(commandName: "text", abstract: "Assert text appears on screen.")
            @OptionGroup var global: GlobalOptions
            @Option(name: .long, help: "Expected text fragment.") var value: String
            func run() { UICLI.runOneShot(global: global, action: .assertText, sel: SelectorOptions(), value: value) }
        }
    }
}

struct SelectorOptions: ParsableArguments {
    @Option(name: .long, help: "Accessibility label.") var label: String?
    @Option(name: .long, help: "Accessibility identifier.") var identifier: String?
    @Option(name: .long, help: "Element role (button, textfield, statictext, cell, ...).") var role: String?
    @Option(name: .long, help: "Substring of label/value.") var text: String?
    @Option(name: .long, help: "Bound index when multiple matches exist.") var index: Int?
    @Option(name: .long, help: "Per-command UI submit timeout in milliseconds.") var uiTimeoutMs: Int?

    init() {}
}

/// Helpers shared by every one-shot UI command. Lives outside the command
/// structs so each Parser type stays a thin shell over option parsing.
enum UICLI {
    static let activePointerFile = ".kujto/runtime/ui/active-session"

    static func client(forSessionId sessionId: String?) throws -> UISessionClient? {
        if let id = sessionId, !id.isEmpty {
            return UISessionClient(directory: UISessionClient.defaultRoot().appendingPathComponent(id))
        }
        let pointer = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(activePointerFile)
        guard let id = (try? String(contentsOf: pointer))?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
            return nil
        }
        return UISessionClient(directory: UISessionClient.defaultRoot().appendingPathComponent(id))
    }

    static func writeActiveSession(sessionId: String) throws {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(activePointerFile)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try sessionId.write(to: url, atomically: true, encoding: .utf8)
    }

    static func clearActiveSession() {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(activePointerFile)
        try? FileManager.default.removeItem(at: url)
    }

    static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: Date())
    }

    static func isoNow() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: Date())
    }

    /// Submits one command to the active session and emits a `ui_action`
    /// event. Exits with code 1 if the runner reports failure so CI can
    /// pivot off the exit code without parsing NDJSON.
    static func runOneShot(
        global: GlobalOptions,
        action: UIAction,
        sel: SelectorOptions,
        text: String? = nil,
        value: String? = nil,
        url: String? = nil,
        direction: String? = nil,
        seconds: Double? = nil
    ) {
        let emitter = global.makeEmitter()
        runOrExit(emitter) {
            guard let client = try client(forSessionId: nil) else {
                throw KujtoError(
                    code: .uiElementNotFound,
                    message: LMsg(
                        sq: "Asnje sesion UI aktiv.",
                        en: "No active UI session."
                    ),
                    recovery: LMsg(
                        sq: "Ekzekuto 'kujto ui session start --scheme YourUITestsScheme' me runnerin e instaluar.",
                        en: "Run 'kujto ui session start --scheme YourUITestsScheme' with the runner installed."
                    )
                )
            }
            let seq = try client.nextSeq()
            let cmd = KujtoCore.UICommand(
                seq: seq,
                action: action,
                selector: hasAnySelector(sel) ? UISelector(
                    label: sel.label,
                    identifier: sel.identifier,
                    role: sel.role,
                    text: sel.text,
                    index: sel.index
                ) : nil,
                text: text,
                value: value,
                url: url,
                direction: direction,
                seconds: seconds,
                timeoutMs: sel.uiTimeoutMs
            )
            let result = try client.submit(cmd, timeoutMs: sel.uiTimeoutMs ?? 15000)

            var fields: [String: NDJSONValue] = [
                "type": .string("ui_action"),
                "action": .string(action.rawValue),
                "seq": .int(seq),
                "success": .bool(result.success)
            ]
            if let err = result.error { fields["error"] = .string(err) }
            if let screenshot = result.screenshot { fields["screenshot"] = .string(screenshot) }
            if let tree = result.tree { fields["tree"] = .string(tree) }
            if let m = result.matched {
                var match: [String: NDJSONValue] = [:]
                if let l = m.label { match["label"] = .string(l) }
                if let i = m.identifier { match["identifier"] = .string(i) }
                if let t = m.elementType { match["element_type"] = .string(t) }
                if let r = m.frame {
                    match["frame"] = .object([
                        "x": .double(r.x),
                        "y": .double(r.y),
                        "width": .double(r.width),
                        "height": .double(r.height)
                    ])
                }
                fields["matched"] = .object(match)
            }
            emitter.emit(NDJSONEvent(fields: fields))
            if !result.success { Foundation.exit(1) }
        }
    }

    private static func hasAnySelector(_ s: SelectorOptions) -> Bool {
        s.label != nil || s.identifier != nil || s.role != nil || s.text != nil || s.index != nil
    }
}
