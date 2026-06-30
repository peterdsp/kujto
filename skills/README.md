# Skills · Kujto

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

> Skills jane procedura (si). Memory jane fakte dhe referenca (çfarë).
> Skills are procedures (how). Memory is facts and references (what).

---

## Shqip

### Çfarë jane

Nje skill eshte nje dosje me nje `SKILL.md` qe ka frontmatter (`name`, `description`) dhe nje trup dygjuhesh. Skill-i nuk e dyfishon dijen: ai e thote agjentit te lexoje file-t perkatese nga e njejta memory base qe ngarkon `AGENTS.md`. Nje burim, shume agjente.

### Skills aktuale

| Skill | Aktivizimi | Lexon nga memory |
|---|---|---|
| `prototyping` | Zbulim ekrani/animacioni heret ne zhvillim | [[prototyping_with_agents]], [[prototyping_loop]] |
| `mburoja-audit` | "audit me Mburoja", PR qe prek auth/upload/redirect | [domains/web/](../memory/domains/web/) |

### Instalim

```bash
~/kujto/bin/skills/install-skills.sh            # install ne agjentet e pranishem
~/kujto/bin/skills/install-skills.sh --list     # listo skills-et burim
~/kujto/bin/skills/install-skills.sh --uninstall
```

`install.sh` e therr kete automatikisht. Symlink-et:

- Claude Code: `~/.claude/skills/kujto-<name>` -> `skills/<name>/`
- Codex CLI: `~/.codex/prompts/kujto-<name>.md` -> `skills/<name>/SKILL.md` (thirre me `/kujto-<name>`)

### Shto nje skill te ri

1. Krijo `skills/<name>/SKILL.md` me frontmatter dhe seksione Shqip + English.
2. Ne trup, thuaji agjentit cilat file `memory/` te lexoje. Mos e kopjo dijen.
3. Riekzekuto installerin. Pa vize te gjate, te dyja gjuhet ne sinkron.

---

## English

### What they are

A skill is a folder with a `SKILL.md` holding frontmatter (`name`, `description`) and a bilingual body. A skill does not duplicate knowledge: it tells the agent to read the relevant files from the same memory base that `AGENTS.md` loads. One source, many agents.

### Current skills

| Skill | Trigger | Reads from memory |
|---|---|---|
| `prototyping` | Screen/animation discovery early in development | [[prototyping_with_agents]], [[prototyping_loop]] |
| `mburoja-audit` | "audit with Mburoja", PRs touching auth/upload/redirect | [domains/web/](../memory/domains/web/) |

### Install

```bash
~/kujto/bin/skills/install-skills.sh            # install into present agents
~/kujto/bin/skills/install-skills.sh --list     # list source skills
~/kujto/bin/skills/install-skills.sh --uninstall
```

`install.sh` calls this automatically. The symlinks:

- Claude Code: `~/.claude/skills/kujto-<name>` -> `skills/<name>/`
- Codex CLI: `~/.codex/prompts/kujto-<name>.md` -> `skills/<name>/SKILL.md` (invoke with `/kujto-<name>`)

### Add a new skill

1. Create `skills/<name>/SKILL.md` with frontmatter and Albanian + English sections.
2. In the body, tell the agent which `memory/` files to read. Do not copy the knowledge.
3. Re-run the installer. No em-dash, both languages in sync.
