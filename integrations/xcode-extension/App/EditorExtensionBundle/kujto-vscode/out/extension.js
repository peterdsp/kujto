"use strict";
// Kujto VS Code / Cursor extension
//
// Surfaces the Kujto CLI inside the editor:
//
//   - Commands for build / run / test / context / simulator list / ui screen
//   - NDJSON-aware Output channel
//   - Inline diagnostics from `build_issue` and `test_failure` events
//   - Status bar entry that reflects the most recent operation
//
// The extension never re-implements anything the CLI already does. It
// shells out to `kujto --json` and reacts to events line by line.
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.activate = activate;
exports.deactivate = deactivate;
const vscode = __importStar(require("vscode"));
const child_process_1 = require("child_process");
const path = __importStar(require("path"));
const CHANNEL_NAME = "Kujto";
const DIAGNOSTIC_SOURCE = "kujto";
let output;
let diagnostics;
let statusItem;
let activeProc;
function activate(context) {
    output = vscode.window.createOutputChannel(CHANNEL_NAME);
    diagnostics = vscode.languages.createDiagnosticCollection(DIAGNOSTIC_SOURCE);
    statusItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 100);
    statusItem.text = "$(rocket) Kujto";
    statusItem.command = "kujto.context";
    statusItem.show();
    context.subscriptions.push(output, diagnostics, statusItem, vscode.commands.registerCommand("kujto.build", () => runOp("build", buildTimeout())), vscode.commands.registerCommand("kujto.run", () => runOp("run", buildTimeout(), ["--log"])), vscode.commands.registerCommand("kujto.test", () => runOp("test", testTimeout())), vscode.commands.registerCommand("kujto.context", () => runOp("context")), vscode.commands.registerCommand("kujto.simulatorList", () => runOp("simulator", undefined, ["list"])), vscode.commands.registerCommand("kujto.uiScreen", () => runOp("ui", undefined, ["screen"])), vscode.commands.registerCommand("kujto.stop", stopActiveOperation), vscode.commands.registerCommand("kujto.showRules", showRulesForActiveFile), vscode.commands.registerCommand("kujto.showMap", () => runSnapshot("map")), vscode.commands.registerCommand("kujto.showLint", () => runSnapshot("lint")), vscode.commands.registerCommand("kujto.showAgents", () => runSnapshot("agents")));
}
function deactivate() {
    if (activeProc && !activeProc.killed)
        activeProc.kill("SIGTERM");
}
function buildTimeout() {
    return getConfig("buildTimeoutMs", 1_800_000);
}
function testTimeout() {
    return getConfig("testTimeoutMs", 2_400_000);
}
function getConfig(key, fallback) {
    return vscode.workspace.getConfiguration("kujto").get(key) ?? fallback;
}
function workspaceCwd() {
    const folders = vscode.workspace.workspaceFolders;
    return folders && folders[0] ? folders[0].uri.fsPath : undefined;
}
/// Spawns `kujto <op> [extra] --json [--timeout-ms]` from the workspace root,
/// streams stdout line-by-line, parses NDJSON events into the Output panel,
/// and turns `build_issue` / `test_failure` events into editor diagnostics.
function runOp(op, timeoutMs, extra = []) {
    if (activeProc && !activeProc.killed) {
        vscode.window.showWarningMessage("A Kujto operation is already running. Use 'Kujto: Stop' first.");
        return;
    }
    const cwd = workspaceCwd();
    if (!cwd) {
        vscode.window.showErrorMessage("Open a workspace folder before running Kujto.");
        return;
    }
    const bin = getConfig("binaryPath", "kujto");
    const language = getConfig("language", "en");
    const args = [op, ...extra, "--json"];
    if (timeoutMs)
        args.push("--timeout-ms", String(timeoutMs));
    output?.show(true);
    output?.appendLine(`▶ ${bin} ${args.join(" ")}`);
    setStatus(`$(sync~spin) Kujto: ${op}`);
    diagnostics?.clear();
    const issuesByFile = new Map();
    const env = { ...process.env, KUJTO_LANG: language };
    const proc = (0, child_process_1.spawn)(bin, args, { cwd, env });
    activeProc = proc;
    let buffer = "";
    proc.stdout.on("data", (data) => {
        buffer += data.toString("utf8");
        let newlineIndex;
        while ((newlineIndex = buffer.indexOf("\n")) !== -1) {
            const line = buffer.slice(0, newlineIndex).trim();
            buffer = buffer.slice(newlineIndex + 1);
            if (!line)
                continue;
            handleNdjsonLine(line, cwd, issuesByFile);
        }
    });
    proc.stderr.on("data", (data) => {
        output?.append(data.toString("utf8"));
    });
    proc.on("close", (code) => {
        if (buffer.trim())
            handleNdjsonLine(buffer.trim(), cwd, issuesByFile);
        publishDiagnostics(issuesByFile);
        activeProc = undefined;
        const ok = code === 0;
        output?.appendLine(ok ? `✓ ${op} succeeded` : `✗ ${op} exited with code ${code}`);
        setStatus(ok ? `$(check) Kujto: ${op}` : `$(error) Kujto: ${op} failed`);
    });
    proc.on("error", (err) => {
        output?.appendLine(`error: ${err.message}`);
        setStatus(`$(error) Kujto: ${op} crashed`);
    });
}
function stopActiveOperation() {
    if (!activeProc || activeProc.killed) {
        vscode.window.showInformationMessage("No active Kujto operation.");
        return;
    }
    activeProc.kill("SIGTERM");
    setStatus("$(stop) Kujto: stopping…");
}
function setStatus(text) {
    if (statusItem)
        statusItem.text = text;
}
function handleNdjsonLine(line, cwd, issuesByFile) {
    let event;
    try {
        event = JSON.parse(line);
    }
    catch {
        output?.appendLine(line);
        return;
    }
    switch (event.type) {
        case "build_issue":
            recordIssue(event, cwd, issuesByFile);
            output?.appendLine(formatIssue(event));
            break;
        case "test_failure":
            recordIssue({ ...event, severity: "error" }, cwd, issuesByFile);
            output?.appendLine(`✗ test ${event.name}: ${event.message}`);
            break;
        case "operation_started":
            output?.appendLine(`▶ ${event.operation}`);
            break;
        case "operation_finished":
            output?.appendLine(`${event.success ? "✓" : "✗"} ${event.operation} (${event.duration_ms}ms)`);
            break;
        case "error":
            output?.appendLine(`error[${event.code}]: ${event.message}`);
            if (event.recovery)
                output?.appendLine(`  → ${event.recovery}`);
            break;
        case "app_log":
            output?.appendLine(`[${event.level}] ${event.message}`);
            break;
        case "simulator_event":
        case "device_event":
            output?.appendLine(`• ${event.kind || "event"}: ${event.name || event.udid}`);
            break;
        default:
            output?.appendLine(line);
    }
}
function recordIssue(event, cwd, byFile) {
    if (!event.file)
        return;
    const filePath = path.isAbsolute(event.file) ? event.file : path.join(cwd, event.file);
    const line = Math.max(0, Number(event.line || 1) - 1);
    const column = Math.max(0, Number(event.column || 1) - 1);
    const range = new vscode.Range(line, column, line, column + 1);
    const severity = event.severity === "warning"
        ? vscode.DiagnosticSeverity.Warning
        : vscode.DiagnosticSeverity.Error;
    const diag = new vscode.Diagnostic(range, event.message || "(no message)", severity);
    diag.source = DIAGNOSTIC_SOURCE;
    const existing = byFile.get(filePath) ?? [];
    existing.push(diag);
    byFile.set(filePath, existing);
}
function publishDiagnostics(byFile) {
    diagnostics?.clear();
    for (const [filePath, diags] of byFile.entries()) {
        diagnostics?.set(vscode.Uri.file(filePath), diags);
    }
}
/// Captures the full stdout of `kujto <args>` into a promise. Used by the
/// snapshot commands (rules, map, lint, agents) that consume a single JSON
/// event rather than a stream.
function runCapturing(args) {
    return new Promise((resolve, reject) => {
        const cwd = workspaceCwd();
        if (!cwd)
            return reject(new Error("Open a workspace folder before running Kujto."));
        const bin = getConfig("binaryPath", "kujto");
        const proc = (0, child_process_1.spawn)(bin, [...args, "--json"], { cwd, env: { ...process.env } });
        let out = "", err = "";
        proc.stdout.on("data", (d) => out += d.toString("utf8"));
        proc.stderr.on("data", (d) => err += d.toString("utf8"));
        proc.on("error", reject);
        proc.on("close", (code) => code === 0 ? resolve(out.trim()) : reject(new Error(err || `kujto exited ${code}`)));
    });
}
async function showRulesForActiveFile() {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
        vscode.window.showInformationMessage("Open a file first.");
        return;
    }
    const cwd = workspaceCwd();
    if (!cwd)
        return;
    const relPath = path.relative(cwd, editor.document.uri.fsPath);
    try {
        const raw = await runCapturing(["rules", relPath]);
        const parsed = JSON.parse(raw);
        const matches = parsed.matches ?? [];
        output?.show(true);
        output?.appendLine(`Rules for ${relPath}:`);
        if (matches.length === 0) {
            output?.appendLine("  No file-scoped rules match. Base memory still applies.");
            return;
        }
        for (const m of matches) {
            const risk = m.risk && m.risk.length ? `  [risk: ${m.risk.join(", ")}]` : "";
            output?.appendLine(`  • ${m.title}${risk}`);
            output?.appendLine(`      ${m.path}  (matched ${m.glob})`);
        }
        const pick = await vscode.window.showQuickPick(matches.map((m) => ({ label: m.title, description: m.glob, detail: m.path })), { placeHolder: "Open the memory rule..." });
        if (pick) {
            const doc = await vscode.workspace.openTextDocument(path.join(cwd, pick.detail));
            await vscode.window.showTextDocument(doc);
        }
    }
    catch (e) {
        vscode.window.showErrorMessage(`Kujto: ${e.message}`);
    }
}
async function runSnapshot(op) {
    try {
        const raw = await runCapturing([op]);
        output?.show(true);
        output?.appendLine(`kujto ${op}:`);
        output?.appendLine(JSON.stringify(JSON.parse(raw), null, 2));
    }
    catch (e) {
        vscode.window.showErrorMessage(`Kujto: ${e.message}`);
    }
}
function formatIssue(event) {
    const sev = event.severity || "error";
    const file = event.file || "?";
    const line = event.line ? `:${event.line}` : "";
    const col = event.column ? `:${event.column}` : "";
    return `${sev === "error" ? "✗" : "!"} ${sev}: ${file}${line}${col}: ${event.message}`;
}
//# sourceMappingURL=extension.js.map