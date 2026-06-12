//
// KujtoUISession.swift
//
// Drop this file into your project's UI test target (the one with the
// "Includes UI Tests" capability). Configure the test scheme so this
// test method can be invoked by xcodebuild:
//
//     xcodebuild test \
//       -workspace YourApp.xcworkspace \
//       -scheme YourAppUITests \
//       -destination 'platform=iOS Simulator,id=<UDID>' \
//       -only-testing:YourAppUITests/KujtoUISession/testRunSession
//
// Pass these environment variables when invoking the test runner:
//
//     KUJTO_UI_SESSION_DIR  absolute path to the session directory
//                           (typically <repo>/.kujto/runtime/ui/<id>)
//     KUJTO_UI_BUNDLE_ID    bundle id of the app under test (optional;
//                           if set, the session launches it on start)
//     KUJTO_UI_IDLE_EXIT_S  seconds of inactivity before the session
//                           exits cleanly (default 600)
//
// Wire protocol: identical to Sources/KujtoCore/UISession.swift on the
// CLI side. We read cmd-<seq>.json files, dispatch to XCUIApplication,
// and write result-<seq>.json next to them.

import XCTest
import Foundation

final class KujtoUISession: XCTestCase {

    func testRunSession() throws {
        let env = ProcessInfo.processInfo.environment
        guard let sessionPath = env["KUJTO_UI_SESSION_DIR"], !sessionPath.isEmpty else {
            XCTFail("KUJTO_UI_SESSION_DIR is not set")
            return
        }
        let sessionURL = URL(fileURLWithPath: sessionPath)
        try FileManager.default.createDirectory(at: sessionURL, withIntermediateDirectories: true)

        let bundleId = env["KUJTO_UI_BUNDLE_ID"]
        let idleExitSeconds = TimeInterval(env["KUJTO_UI_IDLE_EXIT_S"].flatMap(Double.init) ?? 600)

        let app: XCUIApplication
        if let bundleId = bundleId, !bundleId.isEmpty {
            app = XCUIApplication(bundleIdentifier: bundleId)
            app.launch()
        } else {
            app = XCUIApplication()
            app.launch()
        }

        let started = Date()
        var lastActivity = Date()
        var seenSeqs = Set<Int>()

        // Drain loop: poll the session directory for new cmd files and
        // execute them in numeric order. Stops after idleExitSeconds of
        // silence so a forgotten session doesn't keep simulators warm.
        while Date().timeIntervalSince(lastActivity) < idleExitSeconds {
            let pending = pendingCommands(at: sessionURL, exclude: seenSeqs)
            if pending.isEmpty {
                Thread.sleep(forTimeInterval: 0.05)
                continue
            }
            for cmdURL in pending {
                guard let cmd = decodeCommand(at: cmdURL) else { continue }
                seenSeqs.insert(cmd.seq)
                let result = dispatch(cmd, app: app)
                writeResult(result, in: sessionURL)
                lastActivity = Date()
            }
        }

        let total = Date().timeIntervalSince(started)
        NSLog("[KujtoUISession] idle for \(idleExitSeconds)s, exiting after \(Int(total))s")
    }

    // MARK: - Session file discovery

    private func pendingCommands(at sessionURL: URL, exclude seen: Set<Int>) -> [URL] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: sessionURL, includingPropertiesForKeys: nil) else {
            return []
        }
        var pairs: [(Int, URL)] = []
        for entry in entries where entry.lastPathComponent.hasPrefix("cmd-") {
            let stripped = entry.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "cmd-", with: "")
            guard let seq = Int(stripped), !seen.contains(seq) else { continue }
            // Skip if matching result already exists (idempotency).
            let resultURL = sessionURL.appendingPathComponent("result-\(seq).json")
            if fm.fileExists(atPath: resultURL.path) { continue }
            pairs.append((seq, entry))
        }
        return pairs.sorted { $0.0 < $1.0 }.map { $0.1 }
    }

    private func decodeCommand(at url: URL) -> KujtoCommand? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(KujtoCommand.self, from: data)
    }

    private func writeResult(_ result: KujtoResult, in dir: URL) {
        let url = dir.appendingPathComponent("result-\(result.seq).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(result) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Action dispatch

    private func dispatch(_ cmd: KujtoCommand, app: XCUIApplication) -> KujtoResult {
        let timeout: TimeInterval = Double(cmd.timeoutMs ?? 5000) / 1000.0
        switch cmd.action {
        case "screen":
            return capture(cmd: cmd, app: app)
        case "find":
            return findOnly(cmd: cmd, app: app, timeout: timeout)
        case "tap":
            return performTap(cmd: cmd, app: app, timeout: timeout, double: false)
        case "double_tap":
            return performTap(cmd: cmd, app: app, timeout: timeout, double: true)
        case "type":
            return performType(cmd: cmd, app: app, timeout: timeout)
        case "erase":
            return performErase(cmd: cmd, app: app, timeout: timeout)
        case "scroll", "swipe":
            return performSwipe(cmd: cmd, app: app, timeout: timeout)
        case "wait":
            Thread.sleep(forTimeInterval: cmd.seconds ?? 1.0)
            return KujtoResult(seq: cmd.seq, action: cmd.action, success: true)
        case "assert_visible":
            return assertVisible(cmd: cmd, app: app, timeout: timeout)
        case "assert_hidden":
            return assertHidden(cmd: cmd, app: app, timeout: timeout)
        case "assert_text":
            return assertText(cmd: cmd, app: app, timeout: timeout)
        case "open_url":
            if let url = cmd.url {
                XCUIDevice.shared.system.open(URL(string: url)!)
                return KujtoResult(seq: cmd.seq, action: cmd.action, success: true)
            }
            return KujtoResult(seq: cmd.seq, action: cmd.action, success: false, error: "missing url")
        default:
            return KujtoResult(seq: cmd.seq, action: cmd.action, success: false, error: "unknown action")
        }
    }

    private func capture(cmd: KujtoCommand, app: XCUIApplication) -> KujtoResult {
        let snap = app.screenshot()
        let dir = (ProcessInfo.processInfo.environment["KUJTO_UI_SESSION_DIR"]).map { URL(fileURLWithPath: $0) }
        let path = dir?.appendingPathComponent("screen-\(cmd.seq).png").path
        if let path = path { try? snap.pngRepresentation.write(to: URL(fileURLWithPath: path)) }
        let tree = serializeTree(app)
        let treePath = dir?.appendingPathComponent("tree-\(cmd.seq).json").path
        if let treePath = treePath,
           let data = try? JSONSerialization.data(withJSONObject: tree, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: treePath))
        }
        return KujtoResult(seq: cmd.seq, action: cmd.action, success: true, screenshot: path, tree: treePath)
    }

    private func findOnly(cmd: KujtoCommand, app: XCUIApplication, timeout: TimeInterval) -> KujtoResult {
        guard let element = resolve(cmd.selector, in: app) else {
            return KujtoResult(seq: cmd.seq, action: cmd.action, success: false, error: "no matching element")
        }
        let exists = element.waitForExistence(timeout: timeout)
        if exists {
            return KujtoResult(seq: cmd.seq, action: cmd.action, success: true, matched: describe(element))
        }
        return KujtoResult(seq: cmd.seq, action: cmd.action, success: false, error: "element not found before timeout")
    }

    private func performTap(cmd: KujtoCommand, app: XCUIApplication, timeout: TimeInterval, double: Bool) -> KujtoResult {
        guard let element = resolve(cmd.selector, in: app) else {
            return KujtoResult(seq: cmd.seq, action: cmd.action, success: false, error: "no matching element")
        }
        guard element.waitForExistence(timeout: timeout) else {
            return KujtoResult(seq: cmd.seq, action: cmd.action, success: false, error: "element not found before timeout")
        }
        if double { element.doubleTap() } else { element.tap() }
        return KujtoResult(seq: cmd.seq, action: cmd.action, success: true, matched: describe(element))
    }

    private func performType(cmd: KujtoCommand, app: XCUIApplication, timeout: TimeInterval) -> KujtoResult {
        guard let text = cmd.text else {
            return KujtoResult(seq: cmd.seq, action: cmd.action, success: false, error: "missing text")
        }
        let element: XCUIElement
        if let selector = cmd.selector, let resolved = resolve(selector, in: app) {
            element = resolved
            guard element.waitForExistence(timeout: timeout) else {
                return KujtoResult(seq: cmd.seq, action: cmd.action, success: false, error: "field not found")
            }
            element.tap()
        } else {
            element = app
        }
        element.typeText(text)
        return KujtoResult(seq: cmd.seq, action: cmd.action, success: true)
    }

    private func performErase(cmd: KujtoCommand, app: XCUIApplication, timeout: TimeInterval) -> KujtoResult {
        guard let selector = cmd.selector, let element = resolve(selector, in: app) else {
            return KujtoResult(seq: cmd.seq, action: cmd.action, success: false, error: "selector required")
        }
        guard element.waitForExistence(timeout: timeout) else {
            return KujtoResult(seq: cmd.seq, action: cmd.action, success: false, error: "field not found")
        }
        if let value = element.value as? String {
            element.tap()
            let chars = String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count)
            element.typeText(chars)
        }
        return KujtoResult(seq: cmd.seq, action: cmd.action, success: true)
    }

    private func performSwipe(cmd: KujtoCommand, app: XCUIApplication, timeout: TimeInterval) -> KujtoResult {
        let target: XCUIElement
        if let selector = cmd.selector, let resolved = resolve(selector, in: app) {
            guard resolved.waitForExistence(timeout: timeout) else {
                return KujtoResult(seq: cmd.seq, action: cmd.action, success: false, error: "element not found")
            }
            target = resolved
        } else {
            target = app
        }
        switch (cmd.direction ?? "up").lowercased() {
        case "up": target.swipeUp()
        case "down": target.swipeDown()
        case "left": target.swipeLeft()
        case "right": target.swipeRight()
        default: return KujtoResult(seq: cmd.seq, action: cmd.action, success: false, error: "unknown direction")
        }
        return KujtoResult(seq: cmd.seq, action: cmd.action, success: true)
    }

    private func assertVisible(cmd: KujtoCommand, app: XCUIApplication, timeout: TimeInterval) -> KujtoResult {
        guard let element = resolve(cmd.selector, in: app) else {
            return KujtoResult(seq: cmd.seq, action: cmd.action, success: false, error: "no matching element")
        }
        let visible = element.waitForExistence(timeout: timeout) && element.isHittable
        if visible {
            return KujtoResult(seq: cmd.seq, action: cmd.action, success: true, matched: describe(element))
        }
        return KujtoResult(seq: cmd.seq, action: cmd.action, success: false, error: "not visible")
    }

    private func assertHidden(cmd: KujtoCommand, app: XCUIApplication, timeout: TimeInterval) -> KujtoResult {
        guard let element = resolve(cmd.selector, in: app) else {
            return KujtoResult(seq: cmd.seq, action: cmd.action, success: true)
        }
        // Wait briefly to give the UI time to remove the element.
        Thread.sleep(forTimeInterval: min(timeout, 0.5))
        if element.exists && element.isHittable {
            return KujtoResult(seq: cmd.seq, action: cmd.action, success: false, error: "still visible")
        }
        return KujtoResult(seq: cmd.seq, action: cmd.action, success: true)
    }

    private func assertText(cmd: KujtoCommand, app: XCUIApplication, timeout: TimeInterval) -> KujtoResult {
        guard let expected = cmd.value else {
            return KujtoResult(seq: cmd.seq, action: cmd.action, success: false, error: "missing expected text")
        }
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", expected)
        let element = app.descendants(matching: .any).matching(predicate).firstMatch
        let visible = element.waitForExistence(timeout: timeout)
        if visible {
            return KujtoResult(seq: cmd.seq, action: cmd.action, success: true, matched: describe(element))
        }
        return KujtoResult(seq: cmd.seq, action: cmd.action, success: false, error: "text '\(expected)' not found")
    }

    // MARK: - Selector resolution

    private func resolve(_ selector: KujtoSelector?, in app: XCUIApplication) -> XCUIElement? {
        guard let s = selector else { return app }
        let scope = scopeQuery(role: s.role, app: app)
        var query: XCUIElementQuery = scope
        if let id = s.identifier, !id.isEmpty {
            query = query.matching(identifier: id)
        }
        if let label = s.label, !label.isEmpty {
            query = query.matching(NSPredicate(format: "label == %@", label))
        }
        if let text = s.text, !text.isEmpty {
            query = query.matching(NSPredicate(format: "label CONTAINS[c] %@ OR value CONTAINS[c] %@", text, text))
        }
        let element: XCUIElement
        if let index = s.index {
            element = query.element(boundBy: index)
        } else {
            element = query.firstMatch
        }
        return element
    }

    private func scopeQuery(role: String?, app: XCUIApplication) -> XCUIElementQuery {
        switch role?.lowercased() {
        case "button": return app.buttons
        case "textfield", "text_field": return app.textFields
        case "securetextfield", "secure_text_field": return app.secureTextFields
        case "statictext", "label": return app.staticTexts
        case "switch": return app.switches
        case "image": return app.images
        case "cell": return app.cells
        case "navigationbar": return app.navigationBars
        case "tabbar": return app.tabBars
        case "any", nil: return app.descendants(matching: .any)
        default: return app.descendants(matching: .any)
        }
    }

    private func describe(_ element: XCUIElement) -> KujtoMatch {
        let frame = element.frame
        return KujtoMatch(
            label: element.label.isEmpty ? nil : element.label,
            identifier: element.identifier.isEmpty ? nil : element.identifier,
            elementType: String(describing: element.elementType),
            frame: KujtoRect(x: Double(frame.minX), y: Double(frame.minY), width: Double(frame.width), height: Double(frame.height))
        )
    }

    private func serializeTree(_ root: XCUIElement) -> [String: Any] {
        let frame = root.frame
        return [
            "type": String(describing: root.elementType),
            "label": root.label,
            "identifier": root.identifier,
            "value": (root.value as? String) ?? "",
            "frame": [
                "x": Double(frame.minX),
                "y": Double(frame.minY),
                "width": Double(frame.width),
                "height": Double(frame.height)
            ]
        ]
    }
}

// MARK: - Wire types (mirrored from Sources/KujtoCore/UISession.swift)
// Kept local so the test bundle has no dependency on KujtoCore. Field
// shapes are identical, so JSON travels between them transparently.

private struct KujtoSelector: Codable {
    var label: String?
    var identifier: String?
    var role: String?
    var text: String?
    var index: Int?
}

private struct KujtoCommand: Codable {
    var seq: Int
    var action: String
    var selector: KujtoSelector?
    var text: String?
    var value: String?
    var url: String?
    var direction: String?
    var seconds: Double?
    var timeoutMs: Int?
}

private struct KujtoRect: Codable {
    var x: Double, y: Double, width: Double, height: Double
}

private struct KujtoMatch: Codable {
    var label: String?
    var identifier: String?
    var elementType: String?
    var frame: KujtoRect?
}

private struct KujtoResult: Codable {
    var seq: Int
    var action: String
    var success: Bool
    var matched: KujtoMatch?
    var error: String?
    var screenshot: String?
    var tree: String?
}
