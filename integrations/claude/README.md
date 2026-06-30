# Claude Code · Integrim / Integration

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

### Global
`install.sh` lidh `AGENTS.md` te `~/.claude/CLAUDE.md`. Pas instalimit, Claude Code do t'i marre rregullat e Kujto-s ne cdo sesion.

```bash
~/kujto/install.sh
```

### Per repo
Brenda nje repo:

```bash
cd path/to/your/repo
~/kujto/bin/sync/wire.sh
```

Kjo krijon `CLAUDE.md` ne repo qe pointon te AGENTS.md i Kujto-s, keshtu agjentet e perdoruesve te tjere e shohin te njejtin rregull.

### Skills
`install.sh` lidh skills-et e Kujto-s te `~/.claude/skills/kujto-<name>`. Claude Code i zbulon automatikisht dhe i aktivizon nga pershkrimi. Detaje te [skills/README.md](../../skills/README.md).

### Sugjerime
- Mos shkruaj instruksione duplikuese ne `CLAUDE.md` lokal. Edito `memory/` ne Kujto, jo file-in lokal.
- Per kontekst specifik te projektit, shto nje `.claude/project.md` te shkurter qe i referohet `memory/MEMORY.md`.

---

## English

### Global
`install.sh` symlinks `AGENTS.md` to `~/.claude/CLAUDE.md`. After install, Claude Code picks up Kujto's rules in every session.

```bash
~/kujto/install.sh
```

### Per-repo
Inside a repo:

```bash
cd path/to/your/repo
~/kujto/bin/sync/wire.sh
```

This creates a `CLAUDE.md` in the repo that points to Kujto's AGENTS.md, so other contributors' agents see the same rule set.

### Skills
`install.sh` symlinks Kujto skills into `~/.claude/skills/kujto-<name>`. Claude Code auto-discovers them and triggers by description. Detail in [skills/README.md](../../skills/README.md).

### Tips
- Do not duplicate instructions in the local `CLAUDE.md`. Edit `memory/` in Kujto, not the local file.
- For project-specific context, add a short `.claude/project.md` that references `memory/MEMORY.md`.
