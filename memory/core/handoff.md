# Handoff / Handoff

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

### Kur ta krijosh handoff-in
Kur konteksti yt afrohet limitit ose perdoruesi te kerkon pauze. Mos prit deri sa te detyrohesh nga sistemi.

### Cfare te shkruash
Krijo `memory/handoff_active.md` (i injoruar nga git) me kete strukture:

```markdown
# Handoff aktiv

## Detyra
<nje rresht qe pershkruan qellimin>

## Gjendja e tanishme
<degë, file-at e prekur, gjendja e git, hapi i fundit>

## Hapi i radhes
<cfare duhet bere me pas, konkret>

## Risqe te njohura
<listo nese ka>
```

### Pas rikthimit
Sesioni i ardhshem duhet:
1. Te lexoje `handoff_active.md` ne fillim.
2. Te konfirmoje gjendjen me `git status` dhe `git diff`.
3. Te vazhdoje nga hapi i radhes, jo nga zero.

### Pas perfundimit
Fshi `handoff_active.md` pasi puna mbyllet me sukses.

---

## English

### When to write a handoff
When your context budget gets low or the user asks for a pause. Do not wait until the system forces you.

### What to write
Create `memory/handoff_active.md` (git-ignored) with this shape:

```markdown
# Active handoff

## Task
<one line describing the goal>

## Current state
<branch, files touched, git state, last step>

## Next step
<what to do next, concrete>

## Known risks
<list if any>
```

### On resume
The next session should:
1. Read `handoff_active.md` first.
2. Confirm state with `git status` and `git diff`.
3. Continue from the next step, not from zero.

### After completion
Delete `handoff_active.md` once work is finished successfully.
