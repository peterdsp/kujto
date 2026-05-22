# Si të kontribuosh / How to contribute

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

Faleminderit që po sjell një ndryshim te Kujto. Lexo këto rregulla para hapjes së një PR.

### Rregulla absolute

1. **Pa vizë të gjatë.** As në kod, as në commit, as në PR, as në docs. CI do ta refuzojë.
2. **Të dyja gjuhët në sinkron.** Çdo ndryshim teksti te një file duhet të prekë seksionin shqip dhe atë anglisht. PR me një gjuhë të vetme refuzohet.
3. **Shqipja e para.** Në çdo file që ka të dyja gjuhët, shqipja vjen para anglishtes.

### Procesi i PR

1. Bëj fork dhe një branch të ri me emër përshkrues (`feat/`, `fix/`, `docs/`).
2. Bëj ndryshimet. Mbaji të vogla dhe të fokusuara.
3. Ekzekuto skriptet e linting lokalisht (`bash bin/ci/check.sh` kur të shtohet).
4. Hap PR. Përshkrimi duhet të thotë **pse**, jo vetëm **çfarë**.
5. CI duhet të kalojë.

### Stili

- Markdown me rreshta të shkurtër, headers të qartë.
- Shell me `#!/usr/bin/env bash`, `set -euo pipefail`, dhe `shellcheck` clean.
- Mesazhet e commit-it në kohën e tashme imperative (`add`, `fix`, `remove`), shumë e shkurtër në subject.

### Çfarë jemi në kërkim

- Adapter për agjentë të rinj (Aider, Continue, etj.).
- Snippets memorie për fusha të reja (Android, React Native, backend).
- Përkthime në gjuhë të treta (italisht, greqisht), por **vetëm** nëse premtohet mirëmbajtja.

### Çfarë nuk pranojmë

- Ndryshime kozmetike pa vlerë.
- File që e bëjnë repo-n më pak portativ.
- Përdorimi i vizës së gjatë në çfarëdo forme.

---

## English

Thanks for bringing a change to Kujto. Read these rules before opening a PR.

### Absolute rules

1. **No em-dash.** Not in code, not in commits, not in PRs, not in docs. CI will reject it.
2. **Both languages in sync.** Any text change to a file must touch both the Albanian and the English section. PRs with only one language are rejected.
3. **Albanian first.** In every file that has both languages, Albanian comes before English.

### PR process

1. Fork and create a branch with a descriptive name (`feat/`, `fix/`, `docs/`).
2. Make the changes. Keep them small and focused.
3. Run linting scripts locally (`bash bin/ci/check.sh` once added).
4. Open the PR. The description should say **why**, not just **what**.
5. CI must pass.

### Style

- Markdown with short lines, clear headers.
- Shell with `#!/usr/bin/env bash`, `set -euo pipefail`, and `shellcheck` clean.
- Commit messages in imperative present tense (`add`, `fix`, `remove`), very short subject.

### What we want

- Adapters for new agents (Aider, Continue, etc.).
- Memory snippets for new domains (Android, React Native, backend).
- Translations to other languages (Italian, Greek), but **only** if maintenance is promised.

### What we do not accept

- Cosmetic changes with no value.
- Files that make the repo less portable.
- Any use of the em-dash.
