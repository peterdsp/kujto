# Loop i prototipimit / Prototyping loop

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

> Procedura e shkurter. Detajet dhe shembujt iOS ne [[prototyping_with_agents]].
> The short procedure. iOS detail and examples in [[prototyping_with_agents]].

---

## Shqip

### Kur ta perdoresh

Heret ne zhvillim, kur duhet te zbulosh dizajnin e nje ekrani ose moment kyç, jo kur kerkesat jane fikse.

### Loop-i

1. **Specifiko.** Listo veçoritë dhe sinjalet e stilit. Pa prompt te paqarte.
2. **Shko gjeresisht.** Kerko shume variacione, secili me `#Preview` te emertuar.
3. **Vlereso.** Shenoje çfarë te pelqen ne secilin variacion.
4. **Remix.** Kerko kombinim te elementeve te zgjedhura. Perserit 1-4 sa here te duhet.
5. **Mbushe.** Popullo me sample data realiste ne file te vetem te riperdorshem.
6. **Stress-test.** Gjenero variacione per edge cases: tekst i gjate/shkurter, koleksione bosh, lista pa kufi.
7. **Akordo.** Per momentet me animacion, kerko nje tuning panel me faza te emertuara dhe layout side by side.

### Rregulla

- Çdo variacion ka emer dhe `#Preview` te vetin, gjithmone.
- Gjykimi yt vendos, jo agjenti. Mos delego mendimin kritik.
- Diff minimal kur kalon nga prototip ne kod prodhimi. Ndiq [[swift_conventions]].
- Pa veprime git shkaterruese pa miratim. Ndiq [[git_hygiene]].

---

## English

### When to use

Early in development, when you need to discover the design of a screen or key moment, not when requirements are fixed.

### The loop

1. **Specify.** List features and stylistic cues. No vague prompt.
2. **Go wide.** Ask for many variations, each with a named `#Preview`.
3. **Evaluate.** Note what you like in each variation.
4. **Remix.** Ask to combine the chosen elements. Repeat 1-4 as needed.
5. **Fill.** Populate with realistic sample data in a single reusable file.
6. **Stress-test.** Generate variations for edge cases: long/short text, empty collections, unbounded lists.
7. **Tune.** For moments with animation, ask for a tuning panel with named phases and a side-by-side layout.

### Rules

- Every variation has its own name and `#Preview`, always.
- Your judgement decides, not the agent. Do not delegate critical thinking.
- Minimal diff when moving from prototype to production code. Follow [[swift_conventions]].
- No destructive git actions without approval. Follow [[git_hygiene]].
