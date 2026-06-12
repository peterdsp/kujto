# Kujto in CI and editors

Phase 7 (CI hardening) and Phase 8 (editor extension) of the case study.
Bilingual notes for the deterministic surface that automation depends on.

## Shqip

### Kodet e daljes

Kujto perdor nje matrice fikse te kodeve te daljes, ndaj CI runners mund te
degezojne pa zberthyer NDJSON-in.

| Kodi | Kuptimi |
| ---- | ------- |
| 0   | Sukses |
| 1   | Deshtim logjik (build, test, UI assertion) |
| 2   | Perdorim i gabuar (flag i munguar) |
| 70  | Gabim i brendshem |
| 75  | Faza nuk eshte implementuar |
| 78  | Konfigurim i pavlefshem |
| 124 | Doli jashte kohes (`--timeout-ms`) |
| 127 | Vegla qe duhej te ekzekutohej nuk ekziston |

### Skedari CI

Shih `.github/workflows/ios-kujto.yml`. Cdo komande qe del nga makina
duhet te kete `--timeout-ms` te shtypur, `--json`, dhe te shkruhet ne
nje skedar `.ndjson` qe perdoret me vone per artifakte.

### Shtojca per VS Code dhe Cursor

Te gjeni nen `integrations/vscode/`. Komandat e regjistruara:

```
Kujto: Build / Run / Test / Show Context / List Simulators / Capture UI / Stop
```

## English

### Exit code matrix

| Code | Meaning |
| ---- | ------- |
| 0   | Success |
| 1   | Logical failure (build, test, UI assertion) |
| 2   | Misuse (missing or conflicting flags) |
| 70  | Internal error |
| 75  | Phase not yet implemented |
| 78  | Invalid config |
| 124 | Timed out via `--timeout-ms` |
| 127 | Wrapped tool not found |

The matrix lives in `Sources/KujtoCore/ExitCode.swift` and is unit-tested
in `Tests/KujtoCoreTests/ExitCodeTests.swift`. The mapping is intentionally
narrow so CI can switch on the number without parsing NDJSON.

### CI workflow

`.github/workflows/ios-kujto.yml` is the reference runner:

- Builds Kujto from source.
- Calls `kujto build` / `kujto test` with `--json --timeout-ms`.
- Tees the NDJSON stream to a file (`build.ndjson`, `test.ndjson`).
- Summarises `build_issue`, `test_failure`, and `error` events into the
  GitHub job summary.
- Uploads `.kujto/artifacts/` plus the NDJSON traces as a workflow
  artifact.

The pattern is the case study's CI/CD section translated into a working
file: every command is non-interactive, every command has a timeout, and
the artifact store is the source of truth after the job ends.

### VS Code / Cursor extension

`integrations/vscode/` contains a self-contained TypeScript extension that
shells out to `kujto --json` and:

- Streams NDJSON line by line through an Output channel.
- Promotes `build_issue` and `test_failure` events into editor
  diagnostics with the file/line that the CLI emits.
- Exposes a small command palette surface (Build / Run / Test / Context /
  Simulators / UI screen / Stop).
- Mirrors `KUJTO_LANG` through a settings toggle so the user can flip
  between Albanian and English error messages without touching the CLI.

Install (developer mode):

```sh
cd integrations/vscode
npm install
npm run compile
code --install-extension .
```

The extension only consumes the CLI; the case study's recommendation
("Delay the editor extension until the CLI contract is stable") holds —
this code is a thin shell.
