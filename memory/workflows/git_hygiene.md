# Higjiena git / Git hygiene

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

### Commit-et
- Te vegjel dhe te fokusuar. Nje qellim per commit.
- Subject ne kohen e tashme imperative: `shto X`, `rregullo Y`, `hiq Z`.
- Body opsionale, vetem nese arsyeja nuk eshte e qarte nga diff-i.
- Pa "wip", "stuff", "more changes". Bej squash para PR-it.

### Branches
- Emer i qarte: `feat/<task-id>-shkurter`, `fix/<bug>`, `chore/<emer>`.
- Branch nga `main` i fresket, jo nga nje feature branch tjeter (vec kur stivohet me qellim).
- Fshiji pas merge.

### Stacked PRs
- Kur task-u eshte i madh, ndaje ne 2-3 PR te stivuara.
- Cdo PR duhet te kompilohet dhe te kaloje testet i ndare.
- Reviewer cmon stivat me hapa te qarte, jo nje PR me 40 file.

### Cfare nuk commitohet
- Sekrete, kredenciale, token.
- Log produksioni, output debug.
- `DerivedData/`, `node_modules/`, build artifacts.
- `.DS_Store`, `*.xcuserstate`.
- `handoff_active.md`.

---

## English

### Commits
- Small and focused. One purpose per commit.
- Subject in imperative present: `add X`, `fix Y`, `remove Z`.
- Body optional, only if the reason is not clear from the diff.
- No "wip", "stuff", "more changes". Squash before PR.

### Branches
- Clear name: `feat/<task-id>-short`, `fix/<bug>`, `chore/<name>`.
- Branch from a fresh `main`, not from another feature branch (unless intentionally stacked).
- Delete after merge.

### Stacked PRs
- When a task is large, split into 2-3 stacked PRs.
- Each PR must build and pass tests independently.
- Reviewers value clean stacks more than a 40-file PR.

### Never commit
- Secrets, credentials, tokens.
- Production logs, debug output.
- `DerivedData/`, `node_modules/`, build artifacts.
- `.DS_Store`, `*.xcuserstate`.
- `handoff_active.md`.
