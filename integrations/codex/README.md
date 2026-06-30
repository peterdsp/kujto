# OpenAI Codex CLI · Integrim / Integration

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

`install.sh` lidh `AGENTS.md` te `~/.codex/AGENTS.md`. Codex CLI lexon `AGENTS.md` ne shtepi dhe ne repo.

```bash
~/kujto/install.sh
```

Per repo:

```bash
cd path/to/your/repo
~/kujto/bin/sync/wire.sh
```

Pa konfigurim shtese. Skedaret e Kujto-s i nenshtrohen automatikisht profilit te perdoruesit.

### Skills
`install.sh` lidh skills-et e Kujto-s te `~/.codex/prompts/kujto-<name>.md`. Thirri si slash-command, psh `/kujto-prototyping`. I njejti `SKILL.md` qe perdor Claude, i njejti memory base. Detaje te [skills/README.md](../../skills/README.md).

---

## English

`install.sh` symlinks `AGENTS.md` to `~/.codex/AGENTS.md`. Codex CLI reads `AGENTS.md` both from home and from a repo.

```bash
~/kujto/install.sh
```

For a repo:

```bash
cd path/to/your/repo
~/kujto/bin/sync/wire.sh
```

No further config needed. Kujto's files are picked up by the user's profile automatically.

### Skills
`install.sh` symlinks Kujto skills into `~/.codex/prompts/kujto-<name>.md`. Invoke them as slash commands, e.g. `/kujto-prototyping`. The same `SKILL.md` Claude uses, the same memory base. Detail in [skills/README.md](../../skills/README.md).
