# Kujto Studio roadmap

> Status: proposed. Kujto Studio is a separate product, not a line item on the main README roadmap.

---

### Vision in one sentence

Kujto Studio is the local memory layer that stops AI agents and developers from breaking a repo's hidden rules. Not another AI chat.

### Surfaces

Kujto Studio runs standalone as a Mac app, and also plugs into editors. All surfaces call the same `KujtoCore` / `RuleIndex` engine:

- Standalone SwiftUI Mac app (the home base).
- Xcode Source Editor extension (`integrations/xcode-extension/`).
- VS Code, Cursor, and any VS Code fork (`integrations/vscode/`).
- The `kujto` CLI.

### The killer screen: "Before You Touch This File"

The user selects a file (e.g. `HomeReducer.swift`, `CheckoutFeature.swift`, `PaymentClient.swift`). Studio shows:

- The architecture rules that apply.
- Ownership boundaries (who owns it).
- Related tests and the ones to run.
- Known traps and generated-file warnings.
- Dependencies and related modules.
- The PR checklist and the agent instructions to inject.
- A confidence score: "safe", "needs context", "danger zone".

### What we reuse (not greenfield)

- **`KujtoCore`**: project discovery, build/test, simulator, device, UI, NDJSON, config. This is the app engine.
- **The memory system**: the `MEMORY.md` index, `[[name]]` links, the skills format, the CI guards.
- **`Wire`**: the mechanism that syncs `AGENTS.md` to the agents.

### The one missing primitive that unlocks everything: file-scoped rules

Today memory is global: every file is read every session, nothing is scoped to a path. The "Before You Touch This File" screen needs the opposite. Memory and skill files carry frontmatter:

```yaml
applies_to:
  - "**/*Reducer.swift"
  - "**/Checkout*/**"
risk: payment
```

`RuleIndex` resolves a file path to the matching rules, ranked by glob specificity (`resolve(file:)`). For surfaces that only have buffer text and not a path (the Xcode Source Editor extension), `resolveByContent(_:)` matches CamelCase signal tokens derived from the same globs. One keystone, two entry points.

### What to add (status today)

| Capability | Today | What to add |
| ---------- | ----- | ----------- |
| File to rules resolver | done (`RuleIndex`) | scoring tuning as rules grow |
| Content resolver (no path) | done (`resolveByContent`) | optional `signals:` frontmatter override |
| Repo scanner / memory map | partial (project discovery only) | Scanner ingesting AGENTS.md, MEMORY.md, READMEs, package graph, tests |
| Swift code analysis | none | SwiftSyntax pass: reducer graph, State/Action, dependency clients, navigation, effects |
| Mac app target | scaffold (extension container) | Full SwiftUI app: sidebar + map + inspector |
| "Before You Touch This File" inspector | none | The killer screen, fed by RuleIndex + scanner |
| Memory linter / stale detection | CI guards only | Detect drift: a rule names a file/symbol that no longer exists |
| Multi-agent sync from UI | CLI `wire` | Wrap Wire in an app panel |
| Confidence score | none | Heuristic: rule freshness + match strength + test coverage |

### Apple-native layer (the award angle)

These separate "Markdown tool" from "Apple-platform app":

- Xcode Source Editor extension: "show rules for this file" (scaffolded at `integrations/xcode-extension/`).
- Menu bar helper: "open repo memory".
- Spotlight: Core Spotlight indexing of memory and rules.
- Shortcuts / App Intents: "summarize repo rules", "lint memory", "prepare agent context".
- Local-only: no repo upload, an explicit privacy stance.

### Localization

UI strings go through a String Catalog (`.xcstrings`), source language English, with Albanian (`sq`) as a locale. No inline bilingual prose.

### Build order (MVP, deterministic, no AI chat)

1. **`RuleIndex` in KujtoCore** + `applies_to` frontmatter + CI guard. Done.
2. **Content resolver** for the Xcode extension. Done.
3. **Scanner** that builds the memory map model from a repo.
4. **SwiftUI shell**: repo picker, sidebar, file inspector wired to RuleIndex. The demo: click a file, see the rules.
5. **Memory linter** (stale detection) reusing the CI-guard discipline.
6. **Agent export panel** wrapping Wire.
7. *Then* the SwiftSyntax TCA graph (paid tier), menu bar, Spotlight, Shortcuts.

### Free and paid

- **Free**: scan one repo, view the map, validate AGENTS.md, basic linting, manual export for one agent.
- **Paid**: unlimited repos, TCA reducer graph, stale memory detection, multi-agent sync, Xcode extension, PR risk reports, architecture drift detection, team memory templates, encrypted local backups.

### Decisions before code

- `Package.swift` today builds a library + executable, not a `.xcodeproj` app. The full app needs a target (likely a separate Xcode project depending on `KujtoCore` as a local package). The extension container app under `integrations/xcode-extension/App/` is the seed of that shell.

### UI direction

Modern AI-chat-app aesthetic for polish: rounded cards, soft depth, generous spacing, calm palette. Take the visual language, not a chat-first layout (the product is an inspector and map, not a chat).
