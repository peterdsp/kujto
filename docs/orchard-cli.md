# Apple Toolchain Orchestration in Kujto

Bilingual notes that map the clean-room case study
(`flowdeck_terminal_to_terminal_clone_case_study.md`) onto the actual code
inside this repo. Shqip first, English mirrored.

## Shqip

### Cfare eshte implementuar (Fazat 1–8 te plota)

| Komanda | Status | Faza |
| ------- | ------ | ---- |
| `kujto wire/unwire/root` | i plote | - |
| `kujto context` | i plote | 1 |
| `kujto config show/get/set` | i plote (te ndare + lokal) | 1 |
| `kujto build` | i plote (parser gabimesh, NDJSON) | 2 |
| `kujto clean` | i plote (derived data, artifacts, runtime) | 2 |
| `kujto run` | i plote (build, install, launch, ndjekje log opsionale) | 3 |
| `kujto logs` | i plote (predikate per process + subsystem) | 3 |
| `kujto apps` | i plote (.kujto/runtime/apps.json) | 3 |
| `kujto stop` | i plote (terminate + heqje rekordi) | 3 |
| `kujto test` | i plote (`-resultBundlePath` + xcresulttool) | 4 |
| `kujto simulator list/boot/shutdown/erase/screenshot` | i plote | 5 |
| `kujto device list` | i plote (`devicectl --json-output`) | 5 |
| `kujto device install/launch` | i plote me hartim gabimesh (i bllokuar, pa besim, provisioning, no team, i papajtueshem) | 5 |
| `kujto ui session start/stop/status` | i plote (XCTest runner) | 6 |
| `kujto ui screen` | screenshot + pema accessibility kur runneri eshte aktiv | 6 |
| `kujto ui find/tap/double-tap/type/erase/scroll/swipe/wait/open-url/assert visible/hidden/text` | i plote (protokol skedaresh) | 6 |
| `--timeout-ms` ne build/run/test/logs + matrica e kodeve te daljes | i plote | 7 |
| `.github/workflows/ios-kujto.yml` | i plote | 7 |
| `integrations/vscode/` | i plote (TypeScript, problem matcher, diagnostics) | 8 |

### Konfigurimi

```
.kujto/
  config.json         te ndare, commit-safe
  config.local.json   per kete makine, .gitignore
  DerivedData/        prodhuar nga xcodebuild
  artifacts/
    runs/<id>/
      events.ndjson
      build.log
      screenshots/
      result.xcresult
  runtime/
    apps.json         aplikacionet e nisura nga `kujto run`
```

### NDJSON

`--json` ne cdo komande prodhon nje JSON objekt per rresht. Tipet bazike:
`operation_started`, `operation_finished`, `build_issue`, `test_failure`,
`app_log`, `simulator_event`, `device_event`, `ui_snapshot`, `app_record`,
`config_saved`, `clean`, `wire_linked`/`wire_skip`/`wire_removed`, `error`.

### Gjuha

`KUJTO_LANG=sq` ose `KUJTO_LANG=en`. Cdo gabim ka mesazh shqip dhe anglisht.

## English

### What ships today (Phases 1–8 fully)

| Command | Status | Phase |
| ------- | ------ | ----- |
| `kujto wire/unwire/root` | complete | - |
| `kujto context` | complete | 1 |
| `kujto config show/get/set` | complete (shared + local) | 1 |
| `kujto build` | complete (NDJSON, issue parser) | 2 |
| `kujto clean` | complete (derived data + artifacts + runtime) | 2 |
| `kujto run` | complete (build, install, launch, optional log stream) | 3 |
| `kujto logs` | complete (process + subsystem predicate, ndjson style) | 3 |
| `kujto apps` | complete (reads `.kujto/runtime/apps.json`) | 3 |
| `kujto stop` | complete (terminate + remove record) | 3 |
| `kujto test` | complete (`-resultBundlePath` + xcresulttool) | 4 |
| `kujto simulator list/boot/shutdown/erase/screenshot` | complete | 5 |
| `kujto device list` | complete (devicectl `--json-output`) | 5 |
| `kujto device install/launch` | complete with typed signing/lock/trust/profile/team/incompatibility mapping | 5 |
| `kujto ui session start/stop/status` | complete (XCTest runner orchestration) | 6 |
| `kujto ui screen` | screenshot + accessibility tree when a session is active | 6 |
| `kujto ui find/tap/double-tap/type/erase/scroll/swipe/wait/open-url/assert visible/hidden/text` | complete (file-based protocol) | 6 |
| `--timeout-ms` on build/run/test/logs + exit code matrix | complete | 7 |
| `.github/workflows/ios-kujto.yml` reference workflow | complete | 7 |
| `integrations/vscode/` extension (TypeScript) | complete (problem matcher, diagnostics, status bar) | 8 |

### Config + artifact layout

```
.kujto/
  config.json         shared, commit-safe
  config.local.json   machine-specific, .gitignore
  DerivedData/        produced by xcodebuild
  artifacts/
    runs/<id>/
      events.ndjson
      build.log
      screenshots/
      result.xcresult
  runtime/
    apps.json         apps launched by `kujto run`
```

### NDJSON event types

`--json` on any command produces one JSON object per line. Stable types:
`operation_started`, `operation_finished`, `build_issue`, `test_failure`,
`app_log`, `simulator_event`, `device_event`, `ui_snapshot`, `app_record`,
`config_saved`, `clean`, `wire_linked` / `wire_skip` / `wire_removed`,
`error`.

### Language

Set `KUJTO_LANG=sq` or `KUJTO_LANG=en`. Every error carries both forms.

### Implementation trail

- `Sources/KujtoCore/` — Lang, Errors, NDJSON, ProcessRunner, Config,
  Project, Simulator, BuildSettings, Build, AppLauncher, LogStreamer,
  TestRunner, DeviceController, Runtime (apps.json), Artifacts, Wire.
- `Sources/KujtoCLI/` — `main.swift` + `Kujto.swift` (root command),
  `Commands/` (one file per subcommand).
- `Tests/KujtoCoreTests/` — NDJSON encoder, build-issue parser, config
  merge, runtime store round-trip.

### Phase roadmap

1. CLI skeleton, config, NDJSON, discovery — **done**.
2. Build runner + issue parser + artifact directory + clean — **done**.
3. Run + logs + apps + stop — **done**.
4. Tests + xcresult parser — **done**.
5. Simulator + device list / install / launch with typed signing errors — **done**.
6. UI automation via the file-based XCTest runner (`integrations/xctest-runner/KujtoUISession.swift`) — **done**.
7. CI hardening: `--timeout-ms`, exit code matrix (`docs/ci.md`), `.github/workflows/ios-kujto.yml` — **done**.
8. Editor extension (`integrations/vscode/`) — **done**.
