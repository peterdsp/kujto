# How to contribute

Thanks for bringing a change to Kujto. Read these rules before opening a PR.

### Absolute rules

1. **No em-dash.** Not in code, not in commits, not in PRs, not in docs. CI will reject it.
2. **English base language.** Docs, memory, comments, commits, and PRs are written in English. Do not add side-by-side bilingual sections to files.
3. **Localize, do not duplicate.** User-facing app strings go through the String Catalog (`.xcstrings`) with Albanian as a locale, not inline translated prose.

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
- App localizations (Italian, Greek) through the String Catalog, but **only** if maintenance is promised.

### What we do not accept

- Cosmetic changes with no value.
- Files that make the repo less portable.
- Any use of the em-dash.
