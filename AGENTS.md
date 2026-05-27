# Kujto, udhëzime për agjentët AI / Kujto, AI agent instructions

Ky skedar është burimi i së vërtetës për çdo agjent AI (Claude, Codex, Gemini, Copilot, Cursor) që punon në një repo i cili përdor **Kujto** si memorie.
This file is the source of truth for every AI agent (Claude, Codex, Gemini, Copilot, Cursor) operating in a repo that uses **Kujto** for memory.

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

### Rendi i leximit

1. Këtë skedar (`AGENTS.md`). Skedarët `CLAUDE.md`, `CODEX.md`, `GEMINI.md` janë symlink drejt këtij.
2. `memory/MEMORY.md` (indeksi).
3. Vetëm skedarët e memories që referohen nga indeksi dhe lidhen me detyrën.

### Rregulla të forta

1. **Pa vizë të gjatë.** Asnjë `—` në prozë, kod, commit, PR ose koment. Përdor presje, pikë, kllapa, dy pika ose vizë të zakonshme. Kjo është rregull identiteti.
2. **Pa veprime autonome të rrezikshme në git.** Pa commit, push, force-push, reset të fortë, rebase shkurtore ose anashkalim hook-esh pa miratim eksplicit nga njeriu.
3. **Memorie e versionuar, jo memorie chat-i.** E vërteta afatgjatë rri në `memory/`, jo në kontekstin e bisedës.
4. **Dy gjuhë, gjithmonë.** Çdo ndryshim në një file duhet të ruajë seksionet shqip dhe anglisht në sinkron. Shqipja e para.
5. **Korrektësia mbi shpejtësinë.** Lexo skedarët fqinjë, ndiq konventat ekzistuese, prefero diff-e minimale.
6. **Pa sekrete.** Pa kredenciale, token, log produksioni ose të dhëna sensitive të commitohen.

### Çfarë lexon Kujto-ja

```
memory/
  MEMORY.md         indeks
  core/             stil shkrimi, siguri, git, handoff
  domains/ios/      Swift, Xcode, snapshots, arkitektura, navigim
  workflows/        rendi i përgjigjeve, përshkrime PR, higjienë git
```

### Çfarë nuk lexon (deri sa t'i kërkohet)

- File që nuk referohen nga `MEMORY.md`.
- File që nuk lidhen me detyrën.

### Workflow para çdo ndryshimi kodi

1. Lexo `AGENTS.md`, `README.md`, `memory/MEMORY.md`.
2. Lexo skedarët fqinjë të kodit që po prek.
3. Ndiq modelet ekzistuese, jo modelet "ideale" nga jashtë.
4. Diff minimal. Pa rifaktorime të paftuara.

### Kur afrohet limiti i kontekstit

Shkruaj `memory/handoff_active.md` me gjendjen e tanishme dhe planin për të vazhduar. Detajet te `memory/core/handoff.md`.

---

## English

### Reading order

1. This file (`AGENTS.md`). The files `CLAUDE.md`, `CODEX.md`, `GEMINI.md` are symlinks to it.
2. `memory/MEMORY.md` (the index).
3. Only memory files referenced by the index and relevant to the task.

### Hard rules

1. **No em-dash.** No `—` in prose, code, commits, PRs, or comments. Use commas, periods, parens, colons, or a regular hyphen. This is an identity rule.
2. **No autonomous destructive git actions.** No commit, push, force-push, hard reset, rebase shortcut, or hook bypass without explicit human approval.
3. **Versioned memory, not chat memory.** Long-term truth lives in `memory/`, not in chat context.
4. **Two languages, always.** Every file change must keep the Albanian and English sections in sync. Albanian first.
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

### When context budget runs out

Write `memory/handoff_active.md` with the current state and a plan to continue. Details in `memory/core/handoff.md`.

---

<sub>Kujto · MIT · <a href="https://github.com/peterdsp/kujto">github.com/peterdsp/kujto</a></sub>
