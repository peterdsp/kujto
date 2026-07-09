# Kujto Studio for VS Code and Cursor

Kujto Studio surfaces the `kujto` CLI inside VS Code and Cursor. It spawns
`kujto <op> --json`, parses NDJSON events, and turns `build_issue` and
`test_failure` events into inline editor diagnostics. All the heavy lifting
still lives in the CLI; the extension is a thin shell.

## Requirements

- VS Code 1.85.0 or newer, including VS Code forks such as Cursor.
- The `kujto` CLI on `PATH`, or a configured `kujto.binaryPath` setting.
- A local workspace folder. Virtual and untrusted workspaces are not supported
  because the extension runs a local CLI against the workspace.

## Install from VSIX

```sh
cd integrations/vscode
npm install
npm run vsce:package
code --install-extension kujto-vscode-0.1.0.vsix
```

For Cursor, install the generated VSIX through the Extensions view.

## Developer mode

Open this folder in VS Code or Cursor and press F5 to launch an Extension
Development Host. For a faster command-line loop:

```sh
cd integrations/vscode
npm install
npm run compile
```

## Marketplace publishing

This package is ready for `vsce`:

```sh
cd integrations/vscode
npm install
npm run vsce:package
npm run vsce:publish
```

Publishing requires access to the `peterdsp` Visual Studio Marketplace
publisher. Do not store Personal Access Tokens or Microsoft Entra tokens in
the repo. See [PUBLISHING.md](PUBLISHING.md) for the release checklist.

## Commands

| Command | What it does |
| ------- | ------------ |
| `Kujto: Build` | Runs `kujto build --json --timeout-ms <buildTimeoutMs>`, streams diagnostics. |
| `Kujto: Run (with logs)` | Runs `kujto run --log --json`, streams app logs into the Output panel. |
| `Kujto: Test` | Runs `kujto test --json --timeout-ms <testTimeoutMs>`, surfaces failures as diagnostics. |
| `Kujto: Show Context` | Runs `kujto context --json`. |
| `Kujto: List Simulators` | Runs `kujto simulator list`. |
| `Kujto: Capture UI Screen` | Runs `kujto ui screen`. |
| `Kujto: Stop Running App` | Sends SIGTERM to the active operation. |

## Settings

| Setting | Default | Effect |
| ------- | ------- | ------ |
| `kujto.binaryPath` | `kujto` | Override the path to the Kujto binary. |
| `kujto.language` | `en` | Sets `KUJTO_LANG` so errors come back in `sq` or `en`. |
| `kujto.buildTimeoutMs` | `1800000` | Hard timeout for build operations. |
| `kujto.testTimeoutMs` | `2400000` | Hard timeout for test operations. |

## Problem matcher

`kujto-ndjson` is registered as a problem matcher so you can wire Kujto into
custom `tasks.json` entries:

```json
{
  "label": "Kujto Build",
  "type": "shell",
  "command": "kujto build --json --timeout-ms 1800000",
  "problemMatcher": "$kujto-ndjson"
}
```

## How it works

The extension reads NDJSON line by line. For each line it dispatches on
`type`:

- `build_issue` / `test_failure` → inline `vscode.Diagnostic`
- `app_log` → Output panel line
- `operation_started` / `operation_finished` → status bar update
- `error` → Output panel error with bilingual message and recovery hint

The CLI contract is the source of truth; if you upgrade Kujto the extension
keeps working as long as the NDJSON shape holds. No private channel, no
shared state, no telemetry.
