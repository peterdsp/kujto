# Prototipim me agjente / Prototyping with agents

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

> Burimi: WWDC 2026, "Create UI prototypes using agents in Xcode" (session 227).
> Source: WWDC 2026, "Create UI prototypes using agents in Xcode" (session 227).

---

## Shqip

### Parimi

Agjenti eshte bashkepunetor, jo dizajner. Gjykimi perfundimtar eshte i yti. Perdor agjentin per te zbuluar opsione, jo per te marre vendimet kreative ne vendin tend.

### Prompt me qellim, jo me ndjesi

- Listo veçoritë konkrete qe do (nje liste e thjeshte mjafton, jo paragrafe).
- Jep sinjale stili: humori, paleta, tipografia, ndjesia qe do te ngjalle app-i.
- Mos lejo agjentin te zgjedhe arkitekturen ose feature-set kur ti e di me mire. Prompt i paqarte prodhon AI slop dhe te ngec ne nje fillim te gabuar.

### Shko gjeresisht

- Kerko shume variacione ne nje prompt te vetem (psh 10).
- Çdo variacion merr **`#Preview` te emertuar dhe unik**, qe te kalosh shpejt mes tyre ne canvas.
- Heret eshte momenti me i mire per te eksploruar drejtime divergjente.

### Remix

- Rishiko variacionet, shenoje çfarë te pelqen ne secilin.
- Kthehu me nje prompt qe thote cilat variacione dhe cilat elemente specifike do te kombinosh.
- Perserit. Ne thelb: shko gjeresisht, remix, perserit.

### Bej app-in te ndihet i jetuar

- Mbushe me permbajtje realiste, jo placeholder bosh.
- Jep kontekst per personen qe e perdor (psh per book club, diskutimet duhet te jene rreth librave).
- Vendos sample data ne nje **file te vetem te riperdorshem dhe te lexueshem**, qe ta ndryshosh dore.

### Stress-test te edge cases

- Tekst shume i gjate dhe shume i shkurter: truncation apo shtim rreshtash?
- Koleksione bosh: si duket detail page kur s'ka ende takim te planifikuar?
- Lista pa kufi: numri i anetareve, gjatesia e bisedave, leaderboard qe rritet pa fund. Shto nje kontroll "expand" ose tregues rangu relativ.
- Çdo edge case merr `#Preview` te vetin. Kjo nxjerr ne pah interaksione qe mungojne dhe informacion te tepert (redundant).

### Tuning panel per momentet kyçe

- Per animacione dhe interaksione, kerko agjentit te ndertoje nje **tuning panel** me kontrolle te debug-ut, jo ta ndertosh ti me dore.
- Ndaje animacionin ne **faza te emertuara** (psh faza 1: tranzicioni i kopertines, faza 2: rreshtat qe hyjne me staggered timing). Fazat krijojne fjalor te perbashket per feedback.
- Specifiko parametrat: ease (kohezgjatja), spring (stiffness, damping, mass), preset si `bouncy`.
- Kerko layout **side by side** (kontrolli i resize ne Xcode 27) qe tuning panel te mos mbuloje UI-n dhe te shohesh efektin pa context switch.
- Tuning panel sherben edhe per state te app-it, ngjyra, font, offset, jo vetem animacion.

### Lidhje

- [[swift_conventions]] per stilin e kodit qe del nga agjenti.
- [[navigation]] kur variacionet ndryshojne strukturen e navigimit.
- [[snapshot_testing]] per te ngrire variacionin qe zgjedh.
- [[prototyping_loop]] per loop-in e plote si workflow.

---

## English

### Principle

The agent is a collaborator, not a designer. Final judgement is yours. Use the agent to discover options, not to make the creative decisions in your place.

### Prompt with intent, not vibes

- List the concrete features you want (a simple list is enough, not paragraphs).
- Give stylistic cues: mood, palette, typography, the feeling the app should evoke.
- Do not let the agent pick the architecture or feature set when you know better. A vague prompt produces AI slop and anchors you on a flawed start.

### Go wide

- Ask for many variations in a single prompt (e.g. 10).
- Each variation gets a **named, unique `#Preview`**, so you can switch fast in the canvas.
- Early is the best moment to explore divergent directions.

### Remix

- Review the variations, note what you like in each.
- Follow up with a prompt naming which variations and which specific elements to combine.
- Repeat. In a nutshell: go wide, remix, repeat.

### Make the app feel lived-in

- Fill it with realistic content, not empty placeholders.
- Give context about the persona using it (e.g. for a book club, discussions must center on books).
- Put sample data in a **single, reusable, readable file** so you can edit it by hand.

### Stress-test edge cases

- Very long and very short text: truncate or wrap?
- Empty collections: how does the detail page look with no meeting scheduled yet?
- Unbounded lists: member count, conversation length, a leaderboard that grows forever. Add an "expand" control or a relative-rank indicator.
- Each edge case gets its own `#Preview`. This surfaces missing interactions and redundant information.

### Tuning panel for key moments

- For animation and interaction, ask the agent to build a **tuning panel** with debug controls, rather than building it by hand.
- Break the animation into **named phases** (e.g. phase 1: the cover transition, phase 2: rows entering with staggered timing). Phases create a shared vocabulary for feedback.
- Specify the parameters: ease (duration), spring (stiffness, damping, mass), presets like `bouncy`.
- Ask for a **side-by-side** layout (the Xcode 27 resize control) so the panel does not obstruct the UI and you see the effect without context switching.
- Tuning panels also serve app states, colors, fonts, offsets, not just animation.

### Links

- [[swift_conventions]] for the code style the agent emits.
- [[navigation]] when variations change the navigation structure.
- [[snapshot_testing]] to freeze the variation you pick.
- [[prototyping_loop]] for the full loop as a workflow.
