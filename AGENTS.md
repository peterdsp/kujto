# Kujto, AI agent instructions

This file is the source of truth for every AI agent (Claude, Codex, Gemini, Copilot, Cursor) operating in a repo that uses **Kujto** for memory.

---

### Reading order

1. This file (`AGENTS.md`). The files `CLAUDE.md`, `CODEX.md`, `GEMINI.md` are symlinks to it.
2. `memory/MEMORY.md` (the index).
3. Only memory files referenced by the index and relevant to the task.

### Hard rules

1. **No em-dash.** No `—` in prose, code, commits, PRs, or comments. Use commas, periods, parens, colons, or a regular hyphen. This is an identity rule.
2. **No autonomous destructive git actions.** No commit, push, force-push, hard reset, rebase shortcut, or hook bypass without explicit human approval.
3. **Versioned memory, not chat memory.** Long-term truth lives in `memory/`, not in chat context.
4. **English is the base language.** Docs, memory, comments, commits, PRs, and governance are written in English. User-facing app strings are localized through the String Catalog (`.xcstrings`), where Albanian is a locale, not inline duplicated prose. Do not reintroduce side-by-side bilingual sections in new files.
5. **Correctness over speed.** Read neighbouring files, follow existing conventions, prefer minimal diffs.
6. **No secrets.** No credentials, tokens, production logs, or sensitive data may be committed.

### What Kujto reads

```
memory/
  MEMORY.md         index
  core/             writing style, safety, git, handoff
  domains/ios/      Swift, Xcode, snapshots, architectures, navigation
  workflows/        answer order, PR descriptions, git hygiene
```

### What it does not read (until asked)

- Files not referenced by `MEMORY.md`.
- Files unrelated to the task.

### Workflow before any code change

1. Read `AGENTS.md`, `README.md`, `memory/MEMORY.md`.
2. Read neighbouring files of the code you are touching.
3. Follow existing patterns, not idealised patterns from outside.
4. Minimal diff. No unsolicited refactors.

### Localization

App user-facing strings live in a String Catalog (`.xcstrings`), source language English, with Albanian (`sq`) as a locale. Use `String(localized:)` or SwiftUI `Text` with English source keys; do not hardcode translated strings or duplicate prose across languages.

### Migration note

The repo is moving from inline bilingual files to English base plus app localization. Existing bilingual docs and memory files are migrated to English opportunistically as they are touched, not in one sweep.

### When context budget runs out

Write `memory/handoff_active.md` with the current state and a plan to continue. Details in `memory/core/handoff.md`.

---

<sub>Kujto · MIT · <a href="https://github.com/peterdsp/kujto">github.com/peterdsp/kujto</a></sub>
