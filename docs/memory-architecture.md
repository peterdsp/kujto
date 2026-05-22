# Arkitektura e memories / Memory architecture

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

### Premisa
Kontekst chat-i eshte vend i brishte per te vertete afatgjate. File Markdown te versionuar jane vendi i duhur.

### Pesha
```
AGENTS.md              ~3 KB    Rregulla absolute, lexohet gjithmone
memory/MEMORY.md       ~2 KB    Indeks, lexohet i dyti
memory/core/*          ~3 KB    Stil, siguri, handoff
memory/domains/ios/*   ~3 KB    Konventa iOS
memory/workflows/*     ~2 KB    Praktika pune
```

Total: nen 50 KB, qe konsumohet me lehtesi nga cdo agjent ne fillim te sesionit. Pjesa specifike e fushes lexohet vetem kur lidhet me detyren.

### Rendi i leximit per agjentin
1. `AGENTS.md` (rrenja).
2. `memory/MEMORY.md` (indeks).
3. Skedaret e referuar nga indeksi qe lidhen me detyren.

### Pse jo nje monolit
- Nje file i madh konsumon kontekst per cdo task, jo vetem ate qe lidhet.
- File te ndare lejojne PR fokus dhe diff te qarte.
- Strukturimi i ndan fushat. Konventat Swift nuk perziehen me modele PR.

### Pse jo file me te vegjel
- Nese cdo rregull eshte file, lista e leximit behet aq e gjate sa zhduket avantazhi.
- Granulariteti i mire eshte "nje koncept i levizshem per file" (~50-200 rreshta).

### Cfare hyn ku
- `core/`: identitet i agjentit (jo i projektit). Pa specifika projekti.
- `domains/<X>/`: njohuri profesionale per nje fushe (iOS, Android, backend).
- `workflows/`: zakone pune qe kapercejne fusha (commits, PR, handoff).

### Cfare s'hyn kurre
- Sekrete (token, API keys, certifikata).
- Konfigurim qe ndryshon shpesh (versione varesie, IP-të).
- Informacion personal i pakerkuar (cv, email, info kontakti).

---

## English

### Premise
Chat context is a fragile place for long-term truth. Versioned Markdown files are the right place.

### Weight
```
AGENTS.md              ~3 KB    Absolute rules, always read
memory/MEMORY.md       ~2 KB    Index, read second
memory/core/*          ~3 KB    Style, safety, handoff
memory/domains/ios/*   ~3 KB    iOS conventions
memory/workflows/*     ~2 KB    Work practices
```

Total: under 50 KB, easily consumed by any agent at session start. Domain-specific content is read only when relevant to the task.

### Agent reading order
1. `AGENTS.md` (root).
2. `memory/MEMORY.md` (index).
3. Files referenced from the index that relate to the task.

### Why not a monolith
- One large file burns context on every task, not only the relevant slice.
- Split files allow focused PRs and clear diffs.
- Structure separates domains. Swift conventions do not mix with PR templates.

### Why not many tiny files
- If every rule is a file, the reading list grows until the benefit disappears.
- Good granularity is "one movable concept per file" (~50-200 lines).

### What goes where
- `core/`: agent identity (not project identity). No project specifics.
- `domains/<X>/`: domain knowledge (iOS, Android, backend).
- `workflows/`: cross-domain working habits (commits, PRs, handoff).

### What never goes in
- Secrets (tokens, API keys, certificates).
- Configuration that changes often (dependency versions, IPs).
- Personal information not requested (CV, email, contact info).
