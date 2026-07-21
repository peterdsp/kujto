<div align="center">

<img src="site/assets/kujto-icon-1024.png" width="128" height="128" alt="Kujto Studio">

# Kujto Studio

### The local memory layer that stops AI agents and developers from breaking your codebase rules.

Reads your repo's memory, then shows the rules that apply before you touch a file.
Architecture, risks, related tests, and the agent context to inject, in one panel.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue?logo=apple)](https://www.apple.com/macos/)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange?logo=swift)](https://swift.org/)
[![Tests](https://img.shields.io/badge/tests-45%20passing-brightgreen)](https://github.com/peterdsp/kujto/actions)
[![Site](https://img.shields.io/badge/Site-kujto.peterdsp.dev-black)](https://kujto.peterdsp.dev)
[![Stars](https://img.shields.io/github/stars/peterdsp/kujto?style=social)](https://github.com/peterdsp/kujto/stargazers)

[Product](#product) · [Install](#install) · [CLI](#cli) · [Memory format](#memory-format) · [Development](#development) · [Roadmap](#roadmap)

</div>

---

## Product

Every repo has hidden rules. New agents forget them. New developers miss them. Old decisions live in PRs, README files, Slack threads, `AGENTS.md`, `CLAUDE.md`, and a dozen scattered docs. Kujto Studio scans that mess and turns it into a living memory map.

**The killer screen is not a chat.** You select `HomeReducer.swift` or `CheckoutFeature.swift`, and Kujto Studio shows:

- The architecture rules that apply, ranked by specificity of the glob match
- Risk tags (payment, auth, onboarding), the tests to run, related modules
- A **confidence verdict**: safe, needs context, or danger zone
- The agent context to inject into Claude, Codex, or Cursor with one click

**Four surfaces, one engine.** The same memory index drives all of these:

| Surface | Status |
| --- | --- |
| **Standalone Mac app** (SwiftUI) | Builds; first-run wizard + Settings + status detection shipped |
| **Xcode Source Editor extension** | Builds; `Editor > Kujto > Show Rules for This File` |
| **VS Code / Cursor extension** | [`integrations/vscode/`](integrations/vscode/), publishes to the Marketplace |
| **`kujto` CLI** | Ships today; six memory commands (see below) |

Local-only indexing. Nothing leaves your machine.

---

## Git client and memory sync

Kujto Studio now carries a native git client, its surface and liquid-glass design language drawn from [Glint](https://github.com/peterdsp/glint), reimplemented in SwiftUI on libgit2. It is not a bolt-on: the memory engine and the git client fuse at the commit.

- **Rules light up the commit.** Stage a diff and Kujto resolves each file through the rule index right there: risk tags, the rules that apply, the tests to run, and a confidence verdict (safe, needs context, danger zone) before you commit. Advisory, never blocking.
- **History knows your rules.** The history view flags the commits that touched a governance file and expands to show which rules changed, the other half of Governance Rewind.
- **Your memory follows you.** On first run, connect a git provider (GitHub device flow, or GitLab / Gitea) and Kujto provisions a private `kujto-memory` repo on your own account. Your rules, skills, agents, and a registry of your projects sync through it, so a new machine rehydrates your whole working set.

The privacy stance holds: local-first, synced through your own remote, never our servers. Sync is opt-in, and a secret guard refuses to commit anything that looks like a credential.

---

## Install

Kujto Studio is on the [Mac App Store](https://apps.apple.com/app/id6786441748) for €19.99 one time, or direct from [Ko-fi](https://ko-fi.com/s/826e2c8d19) for €17.99 (same app, Sparkle auto-update, cheaper). The `kujto` CLI is free and MIT.

### CLI, one line

```bash
curl -fsSL https://raw.githubusercontent.com/peterdsp/kujto/main/bin/install.sh | bash
```

This wires Kujto's `AGENTS.md` into every supported agent's home directory (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md`, etc.) via symlinks. No duplication.

### Mac app, from source

Requires Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
git clone https://github.com/peterdsp/kujto.git
cd kujto/integrations/xcode-extension
xcodegen generate
open KujtoStudio.xcodeproj
```

In Xcode, pick your Team in `Signing & Capabilities` for both the `KujtoStudio` app target and the `KujtoRulesExtension` target, then run. The first launch shows a four-step welcome wizard that detects the CLI, the Xcode extension, and any installed VS Code or Cursor extension.

### VS Code and Cursor

VS Code extensions run in every VS Code fork including Cursor. From [`integrations/vscode/`](integrations/vscode/), package with `npx vsce package` or publish with `npx vsce publish`.

---

## CLI

Six memory commands, plus the original wire/unwire surface. Every command supports `--json` for machine-readable NDJSON output.

```bash
kujto rules App/Sources/Home/HomeReducer.swift
#   > TCA (The Composable Architecture)
#       memory/domains/ios/architectures/tca.md  (matched **/*Reducer.swift)

kujto map
#   Memory map: /path/to/repo
#     AGENTS.md: yes    MEMORY.md: yes
#     memory files: 41  skills: 3
#     scoped rules (4): TCA, Navigation, Snapshot testing, Prototyping
#     base memory (40 files, read every session)

kujto lint
#   ! [warning] memory/domains/ios/architectures/tca.md: applies_to glob
#     **/*Reducer.swift matches no file in the repo.  (unmatched_glob)

kujto agents
#   ! AGENTS.md: foreign
#   ✓ CLAUDE.md: linked -> AGENTS.md
#   ✓ CODEX.md:  linked -> AGENTS.md
#   ✓ GEMINI.md: linked -> AGENTS.md
```

Full command list:

| Command | What it does |
| --- | --- |
| `kujto rules <file>` | Rules that apply to a file, ranked by glob specificity |
| `kujto map` | Memory map: scoped rules, base memory, risk tags |
| `kujto lint` | Missing governance files, unmatched globs, broken `[[wiki]]` links |
| `kujto agents` | Wire status per agent (`linked`, `foreign`, `not_present`) |
| `kujto wire` / `kujto unwire` | Symlink or remove `AGENTS.md`/`CLAUDE.md`/`CODEX.md`/`GEMINI.md` |
| `kujto root` | Print the Kujto installation root |
| `kujto context` | Inspect the current Xcode workspace/scheme |
| `kujto build` / `run` / `test` / `logs` / `clean` | Xcode toolchain orchestrator (NDJSON events) |
| `kujto simulator` / `device` / `ui` | Simulator control, device install, UI automation |
| `kujto simulator appearance` / `location` / `status-bar` / `push` / `privacy` / `clipboard` / `container` / `create` / `delete` | Device-state controls (light/dark, GPS, status bar, push, permissions, pasteboard, container path, lifecycle) |
| `kujto doctor` | Environment health check (xcrun, xcodebuild, simulators, git) |
| `kujto localize audit <catalog.xcstrings>` | Audit a String Catalog for missing/needs-review/placeholder-mismatch translations |

---

## Memory format

The keystone of Kujto Studio is **file-scoped rules**. Memory and skill files carry frontmatter that maps them to source paths:

```yaml
---
applies_to:
  - "**/*Reducer.swift"
  - "**/Checkout*/**"
risk: payment
---

# TCA architecture

Effects must be cancellable on `onDisappear`.
Never mutate state from a view.
Payment reducers need a shadow log entry: see [[payment_audit_log]].
```

Rules without `applies_to` are **base memory**, read every session (the `MEMORY.md` index, writing style, safety rules). Rules with `applies_to` are **scoped**: they only surface when a matching file is inspected. `[[wiki_link]]` references to other memory files are validated by `kujto lint`.

### Repository layout

```
Sources/
  KujtoCore/          RuleIndex, MemoryMap, MemoryLinter, AgentExport, Wire
  KujtoCLI/           Command definitions for the kujto binary
Tests/
  KujtoCoreTests/     45 tests covering the entire engine
memory/
  MEMORY.md           the index; read after AGENTS.md
  core/               writing style, safety, git, handoff
  domains/ios/        Swift, TCA, snapshots, navigation, 12 architecture guides
  domains/web/        Mburoja: full web-security playbook (XSS, CSRF, SSRF, JWT, ...)
  workflows/          answer order, PR descriptions, git hygiene
skills/               named procedures (prototyping loop, Mburoja audit, ...)
integrations/
  xcode-extension/    the Mac app, the Source Editor extension, the shared bridge
  vscode/             the VS Code / Cursor extension
  claude/ codex/ gemini/ copilot/ cursor/
                      per-agent wiring adapters
site/                 kujto.peterdsp.dev source
bin/                  install.sh, wire.sh, simulator.sh, skills/install-skills.sh
```

---

## Development

```bash
# CLI + engine
xcrun swift build
xcrun swift test        # 45 tests, all green

# Mac app + Xcode extension
cd integrations/xcode-extension
xcodegen generate
xcrun xcodebuild -project KujtoStudio.xcodeproj -scheme KujtoStudio \
  -destination "platform=macOS" build

# Preview the marketing site
cd site && python3 -m http.server 8000 && open http://localhost:8000
```

The CI pipeline runs `swift build`, `swift test`, ShellCheck, a no-em-dash guard, an `applies_to` frontmatter validator, and a commit-message trailer policy on every push to `main`.

### Contributing

The base language is English. The no-em-dash rule is an identity rule enforced by CI. See [CONTRIBUTING.md](CONTRIBUTING.md) for the PR process and style rules. Never mention AI assistants in commit messages; the `trailer-policy` CI job will fail the build.

---

## Roadmap

Shipped:

- **Native git client** inside Studio, with the rules-in-commit fusion and the history-and-rules cross-link
- **Invisible memory sync** to a private repo you own, with conflict resolution and a secret guard
- **Provider adapters** for GitHub, GitLab, and Gitea via OAuth device flow
- **Project registry and rehydrate** so a new machine restores your working set

Next:

- **TCA reducer graph** (paid tier): SwiftSyntax pass mapping State, Action, dependency clients, and navigation
- **Spotlight indexing** of memory and rules
- **App Intents** for Shortcuts (`Summarize repo rules`, `Prepare agent context`)
- **Team memory templates**: share and version conventions across a team without duplicating memory

---

## License

[MIT](LICENSE). Built by [@peterdsp](https://github.com/peterdsp).

<sub>Kujto is Albanian for "remember." The product is named for what it does: keep the memory of your codebase in front of every editor and every agent, before they touch the file.</sub>
