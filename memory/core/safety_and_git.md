# Siguria dhe git / Safety and git

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

### Veprime te ndaluara pa miratim eksplicit
- `git commit` autonom.
- `git push`, `git push --force`.
- `git reset --hard`, `git checkout -- .`, `git clean -f`.
- `git rebase` ne degen kryesore.
- Anashkalim hook-esh (`--no-verify`, `--no-gpg-sign`).
- Heqje degesh me commit-e te papublikuara.

### Veprime te lejuara
- `git status`, `git diff`, `git log`.
- `git add` per skedare specifike.
- Krijim dege me emer te qarte.
- Stage-im ndryshimesh per rishikim nga njeriu.

### Sekretet
- Asnje token, cele API, password, certifikate ose log produksioni te commitohet.
- Verifiko `.gitignore` para ndryshimeve qe prekin skedare konfigurimi.
- Nese gjen sekret te commituar historikisht, raporto, mos e fshij vetem.

### Co-author trailers
Pa `Co-Authored-By` per agjente AI ne commit-et e ketij repo, vec nese perdoruesi e kerkon shprehimisht.

---

## English

### Forbidden without explicit approval
- Autonomous `git commit`.
- `git push`, `git push --force`.
- `git reset --hard`, `git checkout -- .`, `git clean -f`.
- `git rebase` on the main branch.
- Hook bypasses (`--no-verify`, `--no-gpg-sign`).
- Branch deletion when commits are not yet pushed.

### Allowed
- `git status`, `git diff`, `git log`.
- `git add` for specific files.
- Creating branches with clear names.
- Staging changes for human review.

### Secrets
- No token, API key, password, certificate, or production log may be committed.
- Verify `.gitignore` before changes that touch config files.
- If you discover a historically committed secret, report it, do not silently strip it.

### Co-author trailers
No `Co-Authored-By` lines for AI agents in this repo's commits unless the user explicitly requests them.
