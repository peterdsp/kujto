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

import * as vscode from "vscode";
import { spawn, ChildProcessWithoutNullStreams } from "child_process";
import * as path from "path";

const CHANNEL_NAME = "Kujto";
const DIAGNOSTIC_SOURCE = "kujto";

let output: vscode.OutputChannel | undefined;
let diagnostics: vscode.DiagnosticCollection | undefined;
let statusItem: vscode.StatusBarItem | undefined;
let activeProc: ChildProcessWithoutNullStreams | undefined;

export function activate(context: vscode.ExtensionContext) {
    output = vscode.window.createOutputChannel(CHANNEL_NAME);
    diagnostics = vscode.languages.createDiagnosticCollection(DIAGNOSTIC_SOURCE);
    statusItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 100);
    statusItem.text = "$(rocket) Kujto";
    statusItem.command = "kujto.context";
    statusItem.show();

    context.subscriptions.push(
        output,
        diagnostics,
        statusItem,
        vscode.commands.registerCommand("kujto.build", () => runOp("build", buildTimeout())),
        vscode.commands.registerCommand("kujto.run", () => runOp("run", buildTimeout(), ["--log"])),
        vscode.commands.registerCommand("kujto.test", () => runOp("test", testTimeout())),
        vscode.commands.registerCommand("kujto.context", () => runOp("context")),
        vscode.commands.registerCommand("kujto.simulatorList", () => runOp("simulator", undefined, ["list"])),
        vscode.commands.registerCommand("kujto.uiScreen", () => runOp("ui", undefined, ["screen"])),
        vscode.commands.registerCommand("kujto.stop", stopActiveOperation)
    );
}

export function deactivate() {
    if (activeProc && !activeProc.killed) activeProc.kill("SIGTERM");
}

function buildTimeout(): number {
    return getConfig<number>("buildTimeoutMs", 1_800_000);
}

function testTimeout(): number {
    return getConfig<number>("testTimeoutMs", 2_400_000);
}

function getConfig<T>(key: string, fallback: T): T {
    return vscode.workspace.getConfiguration("kujto").get<T>(key) ?? fallback;
}

function workspaceCwd(): string | undefined {
    const folders = vscode.workspace.workspaceFolders;
    return folders && folders[0] ? folders[0].uri.fsPath : undefined;
}

/// Spawns `kujto <op> [extra] --json [--timeout-ms]` from the workspace root,
/// streams stdout line-by-line, parses NDJSON events into the Output panel,
/// and turns `build_issue` / `test_failure` events into editor diagnostics.
function runOp(op: string, timeoutMs?: number, extra: string[] = []) {
    if (activeProc && !activeProc.killed) {
        vscode.window.showWarningMessage("A Kujto operation is already running. Use 'Kujto: Stop' first.");
        return;
    }
    const cwd = workspaceCwd();
    if (!cwd) {
        vscode.window.showErrorMessage("Open a workspace folder before running Kujto.");
        return;
    }
    const bin = getConfig<string>("binaryPath", "kujto");
    const language = getConfig<string>("language", "en");

    const args = [op, ...extra, "--json"];
    if (timeoutMs) args.push("--timeout-ms", String(timeoutMs));

    output?.show(true);
    output?.appendLine(`▶ ${bin} ${args.join(" ")}`);
    setStatus(`$(sync~spin) Kujto: ${op}`);

    diagnostics?.clear();
    const issuesByFile = new Map<string, vscode.Diagnostic[]>();

    const env = { ...process.env, KUJTO_LANG: language };
    const proc = spawn(bin, args, { cwd, env });
    activeProc = proc;

    let buffer = "";
    proc.stdout.on("data", (data) => {
        buffer += data.toString("utf8");
        let newlineIndex: number;
        while ((newlineIndex = buffer.indexOf("\n")) !== -1) {
            const line = buffer.slice(0, newlineIndex).trim();
            buffer = buffer.slice(newlineIndex + 1);
            if (!line) continue;
            handleNdjsonLine(line, cwd, issuesByFile);
        }
    });
    proc.stderr.on("data", (data) => {
        output?.append(data.toString("utf8"));
    });
    proc.on("close", (code) => {
        if (buffer.trim()) handleNdjsonLine(buffer.trim(), cwd, issuesByFile);
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

function setStatus(text: string) {
    if (statusItem) statusItem.text = text;
}

function handleNdjsonLine(line: string, cwd: string, issuesByFile: Map<string, vscode.Diagnostic[]>) {
    let event: any;
    try {
        event = JSON.parse(line);
    } catch {
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
            if (event.recovery) output?.appendLine(`  → ${event.recovery}`);
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

function recordIssue(event: any, cwd: string, byFile: Map<string, vscode.Diagnostic[]>) {
    if (!event.file) return;
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

function publishDiagnostics(byFile: Map<string, vscode.Diagnostic[]>) {
    diagnostics?.clear();
    for (const [filePath, diags] of byFile.entries()) {
        diagnostics?.set(vscode.Uri.file(filePath), diags);
    }
}

function formatIssue(event: any): string {
    const sev = event.severity || "error";
    const file = event.file || "?";
    const line = event.line ? `:${event.line}` : "";
    const col = event.column ? `:${event.column}` : "";
    return `${sev === "error" ? "✗" : "!"} ${sev}: ${file}${line}${col}: ${event.message}`;
}
