# Kujto x Glint: the superproduct design

> Status: validated design, ready for build sequencing.
> Date: 2026-07-20.
> Scope: fold Glint's git surface into Kujto, and provision an invisible private
> memory repo on first run so a user's memory, skills, agents, and rules follow
> them to every machine.

---

## Vision in one sentence

Kujto Studio becomes a native git client whose commit flow knows your repo's
rules, backed by an invisible private repo that carries your memory, skills,
agents, and rules to every machine you sign in on.

## The two halves of the ask

1. **Absorb Glint's surface.** Kujto gains a first-class, visible git client
   (status, diff, commit, history) built natively, wearing Glint's liquid-glass
   design language and seven-token themes.
2. **Provision a private memory repo on first run.** Kujto asks for the user's
   git provider, stands up a private `kujto-memory` repo on their own account,
   and syncs the global memory layer across machines. Sync must feel invisible.

## The two tensions we resolved

- **Stack gap.** Glint is Tauri plus Rust. Kujto is Swift and SwiftUI. We
  reimplement Glint's surface natively on libgit2 rather than embed a second
  runtime. Glint the standalone menu-bar app lives on; Kujto inherits its look
  and its git UX, not its code.
- **Identity gap.** Kujto's flagship stance is "local-only, nothing leaves your
  machine." Sync appears to contradict it. Resolution: the repo is the user's
  own private repo on their own account. Kujto runs no server and never sees the
  data. The stance becomes "local-first, synced through your remote, never our
  servers." That is honest and it is a stronger pitch.

---

## Architecture and module layout

Everything hangs off the existing `KujtoCore` engine. We add three modules and
one SwiftUI surface, all in the same binary. No Rust, no second runtime.

```
Sources/
  KujtoCore/            (exists) RuleIndex, MemoryMap, Wire, Scanner, NDJSON
  KujtoGit/             NEW  libgit2 wrapper (SwiftGit2): status, diff, stage,
                             commit, pull --rebase, push, credential bridge
  KujtoSync/            NEW  MemorySyncActor: watch, commit, rebase, push,
                             conflict detection, ProjectRegistry model
  KujtoAuth/            NEW  DeviceFlowClient (GitHub, GitLab, Gitea), Keychain
                             token store, provider adapters
integrations/xcode-extension/App/
  GitPanel/             NEW SwiftUI  Glint's surface, native (liquid glass plus
                             seven-token themes), status, diff, commit, history
  FirstRunWizard/       (extend)   add provider login and repo provisioning step
```

**Layering, top to bottom.** SwiftUI surfaces call `KujtoSync` and `KujtoAuth`
for orchestration, which call `KujtoGit` for git primitives and `KujtoCore` for
rules. `KujtoGit` is deliberately thin and pure: it knows nothing about memory or
rules, so Glint the standalone could later link the same module if the two
products converge.

**One binary rule.** libgit2 via SwiftGit2 (or a vendored xcframework) runs git
operations in-process, App Store clean, with no dependency on a system `git` that
may be absent. `KujtoGit` exposes an async API. `KujtoSync` is an actor so the
background loop never races the UI.

**Design language.** Glint's `themes.js` seven-token model ports into a Swift
`Theme` struct and a SwiftUI style layer. The tint, accent, and glass tokens
become SwiftUI `Color` sets. Vibrancy stays on `NSVisualEffectView`, which Kujto
already uses.

---

## First-run provisioning flow

The wizard gains a provisioning step. The golden path is invisible; the escape
hatch is one click away.

**Happy path (GitHub Device Flow).**

1. Wizard step "Carry your memory everywhere" offers **Connect Git provider**.
   Default button: GitHub.
2. `DeviceFlowClient` calls `POST /login/device/code`, gets a `user_code` and a
   `verification_uri`. Kujto shows the code in a glass card and opens the browser
   to `github.com/login/device`.
3. Kujto polls `POST /login/oauth/access_token` until approved. On success the
   scoped token goes straight into Keychain. It is never written to disk, never
   shown to an agent.
4. Kujto checks for an existing `kujto-memory` repo via the API. If absent it
   creates it private. If present (second machine) it skips creation.
5. `KujtoSync` clones it to `~/.kujto/memory-sync/`, then runs the rehydrate
   pass: it symlinks `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`,
   `~/.gemini/GEMINI.md` to the synced `AGENTS.md`, and offers to re-wire the
   projects in the registry.

**Escape hatch (bring your own remote).** "Advanced, use my own repo" reveals a
URL field. Kujto validates reachability using the system git credential helper or
SSH agent already on the machine, so no token is typed into Kujto. This covers
GitLab, Gitea, self-hosted, or a repo the user pre-made.

**Skip path.** "Not now" keeps Kujto fully local (today's behavior). A Settings
toggle enables sync later. Sync is opt-in; the privacy stance holds.

**First-machine versus Nth-machine** is auto-detected by repo existence. Same
wizard, the copy adapts ("Creating your memory repo" versus "Found your memory,
pulling it in").

---

## The synced data model

The private repo is a small, human-readable Markdown tree the user can open on
the provider's web UI and understand at a glance. Nothing binary, nothing secret.

```
kujto-memory/                 (private repo, user's own account)
  AGENTS.md                   global agent identity (the root rules)
  MEMORY.md                   index of the memory files below
  core/                       style, safety, git hygiene, handoff
  skills/                     the user's personal named procedures
  agents/                     per-agent wiring config (which tools, which globs)
  rules/                      global file-scoped rules (applies_to frontmatter)
  registry.json               the project registry
  .kujto/
    machines.json             known machines (id, hostname, last-sync)
    manifest.json             schema version, sync format version
```

**`registry.json`** is the "what was I working on" manifest:

```json
{
  "projects": [
    { "name": "Syrmos", "remote": "git@github.com:peterdsp/syrmos.git",
      "wiredAgents": ["claude", "codex"], "localPathHint": "~/git/personal/Syrmos",
      "ruleOverrides": ["rules/no-em-dash.md"] }
  ]
}
```

On a new machine Kujto reads this and offers: "Re-clone and re-wire your 6
projects?" It never auto-clones without a click. Cloning a whole working set
silently would be presumptuous, and paths differ per machine, hence
`localPathHint` and not an absolute path.

**Boundaries, what never enters this repo** (reusing Kujto's documented rule):
no secrets, tokens, or certs; no often-changing config; no unrequested personal
data. The Keychain token stays on-device per machine and is never committed. A
guard in `KujtoSync` scans staged content for secret patterns before every
auto-commit and refuses to push if it smells a token.

**Schema versioning.** `manifest.json` carries a `syncFormatVersion` so a newer
Kujto can migrate an older repo forward and warn an older Kujto away from a newer
repo rather than corrupt it.

---

## The invisible sync engine

`KujtoSync` is a single actor owning one serialized loop, so pushes and pulls
never interleave. It never blocks the UI and never surprises the user.

**The loop, per memory change.**

1. **Watch.** An `FSEvents` or `DispatchSource` watcher on the memory dir fires on
   write. Debounce about 3 seconds so a burst of edits (or a skill writing
   several files) becomes one commit.
2. **Guard.** The secret-scanner pass runs on the staged diff. Any hit aborts,
   surfaces a red "won't sync: looks like a secret in `core/foo.md`" card, and
   leaves the repo dirty for the user.
3. **Commit.** Auto-message from the diff, for example
   `memory: update rules/tca.md, skills/prototyping.md (2 files)`. The machine id
   from `machines.json` goes in the commit trailer.
4. **Rebase.** `git pull --rebase`. Clean 99 percent of the time (small Markdown,
   different files or lines). On a true same-line clash it pauses, raises the
   "keep both?" card (reusing Generative Memory's proposal UI), and does not push
   until resolved.
5. **Push.** Fast-forward push. On a non-fast-forward (another machine pushed
   mid-loop) it returns to step 4 once, then retries.

**Triggers beyond the watcher:** app launch (pull first), app foreground,
network regained, and a 5-minute heartbeat as a floor. All coalesce into the same
actor queue.

**Offline and failure.** No network: the loop keeps committing locally and
quietly retries push later. Auth expired: one non-nagging menu-bar dot and a
"reconnect" affordance; local memory keeps working. Nothing about being offline
degrades the core product. Sync is a background comfort, not a dependency.

**Status surface.** A subtle menu-bar glyph: synced, syncing, offline, or
needs-attention. No modal ever fires for routine sync. Modals are reserved for
the same-line conflict and the secret-guard block.

---

## The Glint git surface and the rules-in-commit fusion

This is the superproduct moment. The git panel is Glint's UX, native. The fusion
is `RuleIndex` firing inside the commit flow.

**The git panel (Glint's surface, SwiftUI).**

- **Repo picker.** The current project plus the registry's known repos.
- **Changes view.** `KujtoGit.status()` grouped into staged and unstaged, with
  per-file diff in the liquid-glass diff styling ported from Glint's tokens.
- **Commit box.** Message field, stage toggles, commit button.
- **History.** `KujtoGit.log()` graph, themeable, feeding the Governance link
  below.
- Menu-bar panel behavior (toggle on click, dismiss on blur) inherited from
  Glint's interaction model.

**The fusion (hero feature): rules light up the commit.** When files are staged,
`KujtoSync` and `RuleIndex` resolve each changed path, and the commit box grows a
"Before you commit" strip:

- Per file: risk tags (payment, auth, onboarding), the applying rules ranked, and
  the tests to run.
- An aggregate confidence verdict for the whole commit: safe, needs context, or
  danger zone.
- A danger-zone banner, for example "You are committing to `PaymentClient.swift`,
  payment rules apply, run these 3 tests," with the rules one tap away.
- One-tap "inject agent context": the same context Kujto already prepares, now
  seeded from exactly the files in this commit, copyable into Claude, Codex, or
  Cursor.

The verdict is advisory, never blocking. It informs, it does not gate. A
danger-zone commit still goes through; Kujto is memory, not a bouncer. This
reuses `RuleIndex.resolve(file:)` and the confidence heuristic already on the
roadmap. No new engine, just a new place it renders.

**History and rules cross-link (follow-on).** Click a rule to see the commits
that shaped it; click a commit to see which rules it touched. This deepens the
existing Governance Rewind and ships after the v1 hero.

---

## Security and privacy

The stance that must not crack:

- Tokens live in Keychain, per machine, never committed, never in logs, never
  shown to any agent.
- The secret-guard pre-commit scan is the backstop against a user accidentally
  syncing a `.env`-shaped rule. It is the same discipline as Kujto's existing CI
  guards, moved into the sync loop.
- OAuth uses fine-grained tokens scoped to the single `kujto-memory` repo where
  the provider supports it, minimizing blast radius.
- Marketing line shifts cleanly: "local-first, synced through your remote, never
  our servers." No server exists to breach.

---

## Testing

Extends the existing 45-test suite.

- `KujtoGit`: status, diff, stage, commit, and rebase against fixture repos in a
  temp dir.
- `KujtoSync`: the conflict matrix. Different-file, different-line, and same-line
  (must raise the card), non-fast-forward retry, offline-then-online, and the
  secret-guard block.
- `KujtoAuth`: device-flow polling states (pending, slow-down, approved, denied,
  expired) against a mocked provider.
- Rehydrate: fresh-machine clone, where symlink wiring is idempotent and never
  clobbers a non-symlink file (mirroring `wire.sh`'s existing guard).

---

## Licensing

The model mirrors Glint's own build split. There is no free-forever feature tier.
It is trial-or-license, and it is everything-or-nothing.

- **App Store build.** Everything is paid. Apple gates the purchase. No trial, no
  license logic in the app. Buy once, all features unlock.
- **Ko-fi and direct build.** A 7-day free trial of everything, then a paid
  license unlocks everything. Built with the same trial-plus-license-gate feature
  flag Glint already uses (`default = ["updater"]` with the license gate on;
  `appstore` feature strips trial and gate). Kujto's Swift equivalent is a build
  configuration, not a Cargo feature, but the shape is identical.

Every capability in this design (the git panel, rules-in-commit, provisioning,
sync, the project registry and multi-machine rehydrate) is available under both
builds once unlocked. Nothing is held back behind an internal upsell.

---

## Build order

Each step is demoable on its own.

1. `KujtoGit` on SwiftGit2, plus tests.
2. Git panel SwiftUI (Glint surface, no sync yet). "Kujto has a git client."
3. `RuleIndex` to commit-box fusion. The hero demo.
4. `KujtoAuth` device flow plus first-run provisioning.
5. `KujtoSync` loop (global layer). The invisible round-trip across two machines.
6. `registry.json` plus rehydrate. "Sit at any machine, it is all there."
7. History-and-rules cross-link; GitLab and Gitea adapters.

---

## Open questions for implementation

- SwiftGit2 versus a vendored libgit2 xcframework: pick during step 1 based on
  App Store notarization friction.
- Whether the git panel ships inside the main window as a sidebar tab or as a
  detachable menu-bar panel first. Glint's native home is the menu bar; Kujto's
  is the window. Prototype both in step 2.
- Fine-grained token support varies by provider. Confirm the minimum scope that
  still allows private-repo creation on GitHub, and the equivalent on GitLab and
  Gitea, during step 4.
