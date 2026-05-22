# Cursor · Integrim / Integration

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

Cursor lexon `.cursor/rules/*.mdc` brenda repo-s. Kujto sjell nje rule te gatshem qe i referohet AGENTS.md.

### Instalim manual

```bash
mkdir -p .cursor/rules
cat > .cursor/rules/kujto.mdc <<'EOF'
---
description: Rregullat e Kujto-s per kete repo
alwaysApply: true
---

Ndiq rregullat e Kujto-s:

- Pa vize te gjate ne asnje dalje.
- Pa veprime autonome destruktive ne git.
- Shqipja e para ne file dygjuhesh.

Detajet ne AGENTS.md ne root.
EOF
```

### Per app-store dhe MCP
Cursor lejon MCP konfigurim ne `.cursor/mcp.json`. Kujto nuk percakton MCP-te (specifike per perdorues), por nuk ka konflikt me to.

---

## English

Cursor reads `.cursor/rules/*.mdc` inside a repo. Kujto ships a ready rule that references AGENTS.md.

### Manual install

```bash
mkdir -p .cursor/rules
cat > .cursor/rules/kujto.mdc <<'EOF'
---
description: Kujto rules for this repo
alwaysApply: true
---

Follow Kujto's rules:

- No em-dash in any output.
- No autonomous destructive git actions.
- Albanian first in bilingual files.

Details in AGENTS.md at the root.
EOF
```

### MCP
Cursor allows MCP config in `.cursor/mcp.json`. Kujto does not define MCPs (user-specific), but does not conflict with them.
