---
name: kujto-mburoja-audit
description: AL Audit sigurie web me Mburoja para shkrimit te kodit te ri ose merge te PR qe prekin auth, upload, redirect, query string. / EN Web security audit with Mburoja before writing new code or merging PRs that touch auth, upload, redirect, or query strings. Use when the user says "audit with Mburoja", "mburoja review", or asks for a security pass on web code.
---

# Kujto skill: Audit Mburoja / Mburoja audit

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

> Ky skill eshte procedura (si). Playbook-u (çfarë) rri ne memory base.
> This skill is the procedure (how). The playbook (what) lives in the memory base.

---

## Shqip

### Burimi i memories

Lexo nga e njejta memory base qe ngarkon `AGENTS.md`:

1. `memory/MEMORY.md` (indeksi).
2. `memory/domains/web/README.md` (kur ta perdoresh, parime, indeks temash).
3. Vetëm file-t Mburoja qe lidhen me kodin ne fjale (psh `xss.md`, `jwt.md`, `ssrf.md`, `sql_injection.md`).

### Kur te aktivizohet

- Perdoruesi thote "audit me Mburoja" ose "mburoja review".
- Para shkrimit te kodit te ri web, ose para merge te nje PR qe prek auth, upload, redirect, ose query string.

### Procedura

1. **Skopo.** Identifiko çfarë kodi preket: input, auth, query, upload, redirect, token.
2. **Hap vetem temat e duhura.** Mos lexo te 15 file-t. Hap ato qe lidhen me siperfaqen e prekur.
3. **Kontrollo kunder playbook-ut.** Per secilen teme, krahaso kodin me parimet dhe bypass-et e listuar.
4. **Raporto.** Liste e gjetjeve me severity (low/medium/high), file:line, dhe rregullimi i propozuar.
5. **Mos rregullo pa miratim** kur ndryshimi prek sjellje sigurie ose API publike.

### Rregulla

- Pa false positives te pakontrolluar. Verifiko çdo gjetje kunder kodit real.
- Pa sekrete ne raport. Pa token, kredenciale, log produksioni.
- Pa vize te gjate.

---

## English

### Memory source

Read from the same memory base that `AGENTS.md` loads:

1. `memory/MEMORY.md` (the index).
2. `memory/domains/web/README.md` (when to use, principles, topic index).
3. Only the Mburoja files relevant to the code at hand (e.g. `xss.md`, `jwt.md`, `ssrf.md`, `sql_injection.md`).

### When to trigger

- The user says "audit with Mburoja" or "mburoja review".
- Before writing new web code, or before merging a PR that touches auth, upload, redirect, or query strings.

### The procedure

1. **Scope.** Identify what code is touched: input, auth, query, upload, redirect, token.
2. **Open only the right topics.** Do not read all 15 files. Open the ones tied to the touched surface.
3. **Check against the playbook.** For each topic, compare the code to the listed principles and bypasses.
4. **Report.** A list of findings with severity (low/medium/high), file:line, and the proposed fix.
5. **Do not fix without approval** when the change touches security behavior or a public API.

### Rules

- No unchecked false positives. Verify every finding against the real code.
- No secrets in the report. No tokens, credentials, production logs.
- No em-dash.
