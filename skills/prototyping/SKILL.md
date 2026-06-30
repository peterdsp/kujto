---
name: kujto-prototyping
description: AL Loop prototipimi me agjente per UI iOS/SwiftUI, shko gjeresisht, remix, sample data, stress-test, tuning panel. / EN Agent-driven prototyping loop for iOS/SwiftUI UI, go wide, remix, real content, edge cases, tuning panels. Use when exploring a new screen, view, or animation early in development.
applies_to:
  - "**/*View.swift"
  - "**/*Screen.swift"
---

# Kujto skill: Prototipim me agjente / Prototyping with agents

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

> Ky skill eshte procedura (si). Njohuria (çfarë) rri ne memory base.
> This skill is the procedure (how). The knowledge (what) lives in the memory base.

---

## Shqip

### Burimi i memories

Para se te veprosh, lexo nga e njejta memory base qe ngarkon `AGENTS.md`:

1. `memory/MEMORY.md` (indeksi).
2. `memory/domains/ios/prototyping_with_agents.md` (detajet, shembujt).
3. `memory/workflows/prototyping_loop.md` (loop-i i shkurter).

Nese repo eshte i lidhur me `wire.sh`, keto file jane ne `memory/` te repo-s. Ndryshe jane ne checkout-in e Kujto-s qe `AGENTS.md` e pointon.

### Kur te aktivizohet

Heret ne zhvillim, kur perdoruesi do te zbuloje dizajnin e nje ekrani, view, ose moment animacioni. Jo kur kerkesat jane fikse.

### Procedura

1. **Specifiko.** Nxirr nga perdoruesi veçoritë konkrete dhe sinjalet e stilit. Pa prompt te paqarte.
2. **Shko gjeresisht.** Gjenero shume variacione, secili me `#Preview` te emertuar dhe unik.
3. **Vlereso.** Pyet perdoruesin çfarë i pelqen ne secilin.
4. **Remix.** Kombino elementet e zgjedhura. Perserit 1-4.
5. **Mbushe.** Sample data realiste ne nje file te vetem te riperdorshem.
6. **Stress-test.** Variacione per edge cases: tekst i gjate/shkurter, koleksione bosh, lista pa kufi.
7. **Akordo.** Per animacione, ndertoj nje tuning panel me faza te emertuara dhe layout side by side.

### Rregulla

- Gjykimi i perdoruesit vendos, jo agjenti. Mos delego mendimin kritik.
- Diff minimal kur kalon ne kod prodhimi. Ndiq `memory/domains/ios/swift_conventions.md`.
- Pa vize te gjate. Pa veprime git shkaterruese pa miratim.

---

## English

### Memory source

Before acting, read from the same memory base that `AGENTS.md` loads:

1. `memory/MEMORY.md` (the index).
2. `memory/domains/ios/prototyping_with_agents.md` (detail, examples).
3. `memory/workflows/prototyping_loop.md` (the short loop).

If the repo is wired with `wire.sh`, these files are in the repo's `memory/`. Otherwise they are in the Kujto checkout that `AGENTS.md` points to.

### When to trigger

Early in development, when the user wants to discover the design of a screen, view, or animation moment. Not when requirements are fixed.

### The procedure

1. **Specify.** Pull concrete features and stylistic cues from the user. No vague prompt.
2. **Go wide.** Generate many variations, each with a named, unique `#Preview`.
3. **Evaluate.** Ask the user what they like in each.
4. **Remix.** Combine the chosen elements. Repeat 1-4.
5. **Fill.** Realistic sample data in a single reusable file.
6. **Stress-test.** Variations for edge cases: long/short text, empty collections, unbounded lists.
7. **Tune.** For animation, build a tuning panel with named phases and a side-by-side layout.

### Rules

- The user's judgement decides, not the agent. Do not delegate critical thinking.
- Minimal diff when moving to production code. Follow `memory/domains/ios/swift_conventions.md`.
- No em-dash. No destructive git actions without approval.
