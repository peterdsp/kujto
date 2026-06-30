---
applies_to:
  - "**/*SnapshotTests.swift"
  - "**/__Snapshots__/**"
---

# Snapshot testing / Snapshot testing

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

### Kur te perdoresh snapshots
- Ekran ose komponent stable me state te qarte.
- Variantet kryesore (light/dark, dynamic type, RTL).
- Pa snapshot per state asinkron pa "wait for" eksplicit.

### Regjistrimi
Tregohu eksplicit kur regjistron. Pa `record = true` qe rrjedh ne main.
```swift
isRecording = true  // VETEM lokalisht, hiqe para commit-it
```

Per regjistrim ne batch, perdor flag mjedisi, jo edit-im kodi:
```bash
SNAPSHOT_RECORD=1 xcodebuild test ...
```

### Rishikimi
- Hap PDF-te ose PNG-te diff me sy, jo vetem byte compare.
- Konfirmo qe ndryshimi eshte i qellimshem para se ta pranosh.
- Pa modifikuar snapshots ne PR-e qe duhet te ishin "no-op".

### Kufijte
- Snapshot != test sjelljeje. Per logjike biznesi shkruaj test njesie.
- Mos teston sasi te medha permutacionesh. Zgjidh 3-4 te perfaqesuese.

---

## English

### When to use snapshots
- Stable screens or components with clear state.
- Key variants (light/dark, dynamic type, RTL).
- No snapshots for async state without explicit "wait for" hooks.

### Recording
Be explicit when recording. No `record = true` leaking into main.
```swift
isRecording = true  // LOCAL only, remove before commit
```

For batch recording, use an env flag, not code edits:
```bash
SNAPSHOT_RECORD=1 xcodebuild test ...
```

### Review
- Look at diff PDFs or PNGs with your eyes, not just byte compare.
- Confirm the change is intentional before accepting.
- Do not modify snapshots in PRs that should be "no-op".

### Limits
- Snapshot != behaviour test. For business logic write unit tests.
- Do not test huge permutations. Pick 3-4 representative ones.
