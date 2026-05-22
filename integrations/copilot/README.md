# GitHub Copilot · Integrim / Integration

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

GitHub Copilot lexon `.github/copilot-instructions.md` ne secilen repo. Kujto nuk e mbi-shkruan ate file (sepse repo te ndryshme kane konventa te ndryshme), por sjell nje shabllon te gatshem.

### Instalim manual
```bash
mkdir -p .github
cat > .github/copilot-instructions.md <<'EOF'
# Instruksione per Copilot / Copilot instructions

Ky projekt ndjek rregullat e Kujto-s: https://github.com/peterdsp/kujto

- Pa vize te gjate ne asnje dalje.
- Pa veprime autonome destruktive ne git.
- Shqipja e para ne file dygjuhesh.

Lexo `AGENTS.md` ne root per detajet.
EOF
```

### Pse jo symlink
Copilot lexon nga `.github/`, jo nga home. Cdo repo kontrollon vete file-in. Kujto i lidh repos permes `AGENTS.md` qe instruksioni mund t'i referohet.

---

## English

GitHub Copilot reads `.github/copilot-instructions.md` in each repo. Kujto does not overwrite that file (different repos have different conventions), but ships a ready template.

### Manual install
```bash
mkdir -p .github
cat > .github/copilot-instructions.md <<'EOF'
# Copilot instructions

This project follows Kujto's rules: https://github.com/peterdsp/kujto

- No em-dash in any output.
- No autonomous destructive git actions.
- Albanian first in bilingual files.

Read `AGENTS.md` at the root for details.
EOF
```

### Why not symlink
Copilot reads from `.github/`, not from home. Each repo owns the file. Kujto wires repos via `AGENTS.md`, which the instruction file references.
