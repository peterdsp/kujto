# Propozim: skills per Kujto / Proposal: skills for Kujto

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

> Status: i implementuar. Shih [skills/README.md](../skills/README.md) per gjendjen aktuale. Ky dokument mban arsyetimin e dizajnit.
> Status: implemented. See [skills/README.md](../skills/README.md) for the current state. This document keeps the design rationale.

---

## Shqip

### Problemi

Sot Kujto ka **memorie** (fakte dhe referenca qe lexohen ne çdo sesion) por jo **skills** (procedura te emertuara qe ngarkohen vetem kur aktivizohen). Disa njohuri jane procedurale dhe me te mira si skill: loop prototipimi, audit Mburoja, regjistrim snapshot-esh, ngritje simulatori. Sot keto rrine si memory file ose si trigger informal ("audit me Mburoja").

### Çfarë eshte nje skill

Nje skill eshte nje dosje me nje `SKILL.md` qe ka:
- **emer** dhe **pershkrim** (kur te aktivizohet), te dyja dygjuheshe.
- nje procedure te qarte, opsionalisht me skripte ose shabllone ndihmese.
- ngarkim me kerkese, jo gjithmone ne kontekst.

Kjo perputhet me konceptin e Claude Code skills dhe me tonin ekzistues te Mburoja-s ("trigger: audit me Mburoja").

### Layout i propozuar

```
skills/
  prototyping/
    SKILL.md          loop-i: shko gjeresisht, remix, mbushe, stress-test, akordo
  mburoja-audit/
    SKILL.md          trigger ekzistues, i formalizuar si skill
  snapshot-record/
    SKILL.md          regjistrim batch snapshot-esh (lidhet me snapshots.sh ne roadmap)
  simulator-boot/
    SKILL.md          mbeshtjell simulator.sh me udhezime per agjentin
```

### Ndarja skill vs memory

- **Memory** = çfarë eshte e vertete (konventa, fakte, referenca). Lexohet gjere.
- **Skill** = si te besh nje gje (procedure me hapa, trigger, vegla). Lexohet kur lidhet.
- Nje skill mund te referoje memory me `[[name]]`. Psh skill `prototyping` referon [[prototyping_with_agents]] dhe [[prototyping_loop]].

### Çfarë do duhej

1. Format `SKILL.md` me frontmatter (emer, pershkrim, gjuhe), dygjuhesh.
2. Mekanizem aktivizimi qe agjentet e mbeshtesin (Claude Code skills tashme; per Codex/Gemini, listim ne `AGENTS.md`).
3. CI guard: no em-dash, seksione dygjuheshe, frontmatter i vlefshem (njesoj si guard-et ekzistues).
4. Indeks ne `MEMORY.md` ose nje `skills/SKILLS.md` paralel.

### Rekomandim

Mos e ndertom tani te gjithen. Hapi i pare: konverto loop-in e prototipimit dhe Mburoja-n ne dy skill prove, mbaj memory file ekzistuese si burim, mat vleren. Nese ndihmon, zgjeroje ne v0.2.

### Lidhje

- [[prototyping_with_agents]], [[prototyping_loop]]: kandidati i pare per skill.
- Mburoja: [domains/web/README.md](../memory/domains/web/README.md), kandidati i dyte.

---

## English

### The problem

Today Kujto has **memory** (facts and references read every session) but not **skills** (named procedures loaded only when triggered). Some knowledge is procedural and better as a skill: the prototyping loop, a Mburoja audit, snapshot recording, simulator boot. Today these live as memory files or as an informal trigger ("audit with Mburoja").

### What a skill is

A skill is a folder with a `SKILL.md` that has:
- a **name** and **description** (when to trigger), both bilingual.
- a clear procedure, optionally with helper scripts or templates.
- on-demand loading, not always in context.

This matches the Claude Code skills concept and Kujto's existing Mburoja tone ("trigger: audit with Mburoja").

### Proposed layout

```
skills/
  prototyping/
    SKILL.md          the loop: go wide, remix, fill, stress-test, tune
  mburoja-audit/
    SKILL.md          the existing trigger, formalized as a skill
  snapshot-record/
    SKILL.md          batch snapshot recording (ties to snapshots.sh on the roadmap)
  simulator-boot/
    SKILL.md          wraps simulator.sh with agent guidance
```

### Skill vs memory split

- **Memory** = what is true (conventions, facts, references). Read broadly.
- **Skill** = how to do a thing (stepwise procedure, trigger, tools). Read when relevant.
- A skill can reference memory with `[[name]]`. E.g. the `prototyping` skill references [[prototyping_with_agents]] and [[prototyping_loop]].

### What it would take

1. A `SKILL.md` format with frontmatter (name, description, language), bilingual.
2. An activation mechanism agents support (Claude Code skills already; for Codex/Gemini, list in `AGENTS.md`).
3. A CI guard: no em-dash, bilingual sections, valid frontmatter (same as the existing guards).
4. An index in `MEMORY.md` or a parallel `skills/SKILLS.md`.

### Recommendation

Do not build all of it now. First step: convert the prototyping loop and Mburoja into two trial skills, keep the existing memory files as the source, and measure the value. If it helps, expand it in v0.2.

### Links

- [[prototyping_with_agents]], [[prototyping_loop]]: the first skill candidate.
- Mburoja: [domains/web/README.md](../memory/domains/web/README.md), the second candidate.
