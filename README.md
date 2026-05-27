<div align="center">

# 🦅 Kujto

**AI-ja e parë shqiptare e memories për dev iOS. E versionuar, dygjuhëshe, e gjallë.**
**The first Albanian AI memory base for iOS developers. Versioned, bilingual, alive.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Made in Albania](https://img.shields.io/badge/Made%20in-Albania%20🇦🇱-red)](https://github.com/peterdsp/kujto)
[![Focus](https://img.shields.io/badge/Focus-iOS%20first-blue?logo=apple)](memory/domains/ios/)
[![Agents](https://img.shields.io/badge/Agents-Claude%20%7C%20Codex%20%7C%20Gemini%20%7C%20Copilot-purple)](AGENTS.md)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

[🇦🇱 Shqip](#-shqip) · [🇬🇧 English](#-english) · [Memory](#memory) · [Tools](#tools) · [Packages](#packages) · [Roadmap](#roadmap)

</div>

---

## 🇦🇱 Shqip

**Kujto** ("kujto!" në mënyrën urdhërore) është një **bazë memorie për agjentët AI që punojnë në projekte iOS**. Mban të vërtetën afatgjatë (konventa Swift, modelet kryesore të arkitekturës iOS, rregulla snapshot-esh, higjienë git, stil shkrimi) në Markdown të strukturuar dhe të versionuar, jo në kontekstin e brishtë të një bisede.

Fokusi fillestar është **iOS me Claude, Codex, Gemini dhe Copilot**, sepse aty rri vlera më e drejtpërdrejtë: dev iOS i shqipfolur nuk ka pasur kurrë një bazë memorie në gjuhën amtare që agjentët e tij ta lexojnë në çdo sesion.

Arkitektura është bërë për t'u zgjeruar (`memory/domains/`), por në fillim po e dërgojmë mirë një fushë të vetme.

Si bonus, repo-ja sjell **`simulator.sh`**, një skript ultra-portativ që ndez çdo projekt Xcode pa konfigurim. Ai është vegla e parë në një familje që do të rritet bashkë me memorien.

### Çfarë merr sot

- **Memory framework dygjuhësh** (shqip dhe anglisht në të njëjtin file), me rregulla bërthamë, konventa iOS dhe workflow.
- **12 guida arkitekture iOS** për modele klasike, UIKit, SwiftUI, reactive dhe unidirectional. Plus një guidë vendimi për të zgjedhur saktë midis tyre.
- **Adapter për Claude Code, OpenAI Codex CLI, Gemini CLI, GitHub Copilot, Cursor** përmes një `AGENTS.md` të vetëm.
- **`simulator.sh` zero-config** për ndërtim, instalim, ndezje dhe streaming log-esh në çdo projekt iOS Xcode.
- **`wire.sh`** për lidhjen e Kujto-s në çdo repo me dy komanda.

### Instalim me një rresht

```bash
curl -fsSL https://raw.githubusercontent.com/peterdsp/kujto/main/bin/install.sh | bash
```

Ose lokalisht:

```bash
git clone https://github.com/peterdsp/kujto.git ~/kujto
cd ~/kujto && ./install.sh
```

### Quickstart për dev iOS

```bash
# 1. Lidh memory-në te projekti yt iOS
cd path/to/your/ios/project
~/kujto/wire.sh

# 2. Ndez app-in pa konfigurim
~/kujto/simulator.sh
```

Tani agjentët e tu (Claude, Codex, Gemini, Copilot) e lexojnë `AGENTS.md` dhe e ndjekin `memory/MEMORY.md` ne çdo sesion.

---

## 🇬🇧 English

**Kujto** ("remember!" in Albanian, imperative) is a **memory base for AI agents working on iOS projects**. It stores long-term truth (Swift conventions, the main iOS architecture patterns, snapshot rules, git hygiene, writing style) in structured, versioned Markdown, not in the fragile context of a single chat.

The initial focus is **iOS with Claude, Codex, Gemini, and Copilot**, because that is where the most direct value lives: Albanian-speaking iOS devs never had a native-language memory base their agents could pick up in every session.

The architecture is built to expand (`memory/domains/`), but we are shipping one domain well first.

As a bonus, the repo ships **`simulator.sh`**, an ultra-portable script that boots any Xcode project with zero config. It is the first tool in a family that will grow alongside the memory.

### What you get today

- **Bilingual memory framework** (Albanian and English in the same file), with core rules, iOS conventions, and workflows.
- **12 iOS architecture guides** across classic, UIKit, SwiftUI, reactive, and unidirectional patterns. Plus a decision guide for choosing between them.
- **Adapter for Claude Code, OpenAI Codex CLI, Gemini CLI, GitHub Copilot, Cursor** through a single `AGENTS.md`.
- **Zero-config `simulator.sh`** for building, installing, launching, and tailing logs on any iOS Xcode project.
- **`wire.sh`** to attach Kujto to any repo with two commands.

### One-line install

```bash
curl -fsSL https://raw.githubusercontent.com/peterdsp/kujto/main/bin/install.sh | bash
```

Or locally:

```bash
git clone https://github.com/peterdsp/kujto.git ~/kujto
cd ~/kujto && ./install.sh
```

### Quickstart for iOS devs

```bash
# 1. Wire memory into your iOS project
cd path/to/your/ios/project
~/kujto/wire.sh

# 2. Boot the app with zero config
~/kujto/simulator.sh
```

Your agents (Claude, Codex, Gemini, Copilot) now read `AGENTS.md` and follow `memory/MEMORY.md` in every session.

---

## Memory

The memory base is the heart of the project. It lives in [`memory/`](memory/) and follows this reading order:

1. [`AGENTS.md`](AGENTS.md) at the root (rules for every agent, bilingual).
2. [`memory/MEMORY.md`](memory/MEMORY.md) (the index).
3. Only the referenced files relevant to the task.

### Layout

```
memory/
├── MEMORY.md                       indeks dygjuhesh / bilingual index
├── core/
│   ├── writing_style.md            stil i shkrimit, rregulli no-em-dash
│   ├── safety_and_git.md           siguri dhe disipline git
│   └── handoff.md                  ruajtja e gjendjes ne limit konteksti
├── domains/
│   └── ios/                        FOKUSI I FILLIMIT / INITIAL FOCUS
│       ├── swift_conventions.md
│       ├── xcode_workflow.md
│       ├── snapshot_testing.md
│       ├── navigation.md
│       └── architectures/          modele arkitekture / architecture patterns
│           ├── README.md           si te zgjedhesh / how to choose
│           └── *.md                guida per modelet kryesore iOS / guides
└── workflows/
    ├── answer_order.md
    ├── pr_descriptions.md
    └── git_hygiene.md
```

Detaje në [docs/memory-architecture.md](docs/memory-architecture.md).

## Tools

Vegla e parë qe shoqeron memorien:

### `simulator.sh`

Zero-config për çdo projekt iOS Xcode.

```bash
./simulator.sh                       # auto-detect everything
./simulator.sh --device "iPhone 15"  # pin a device
./simulator.sh --scheme MyApp        # pin a scheme
./simulator.sh --clean               # rebuild from scratch
./simulator.sh --list                # list schemes and devices
./simulator.sh --no-logs             # do not stream logs
./simulator.sh --stop                # terminate app and shutdown sim
```

Detaje në [docs/simulator-guide.md](docs/simulator-guide.md).

## Integrations

| Agent | Wires into | Folder |
|---|---|---|
| Claude Code | `~/.claude/CLAUDE.md` | [`integrations/claude/`](integrations/claude/) |
| OpenAI Codex CLI | `~/.codex/AGENTS.md` | [`integrations/codex/`](integrations/codex/) |
| Gemini CLI | `~/.gemini/GEMINI.md` | [`integrations/gemini/`](integrations/gemini/) |
| GitHub Copilot | `.github/copilot-instructions.md` | [`integrations/copilot/`](integrations/copilot/) |
| Cursor | `.cursor/rules/kujto.mdc` | [`integrations/cursor/`](integrations/cursor/) |

Të katërt (Claude, Codex, Gemini, Copilot) lexojnë të njëjtin `AGENTS.md` përmes symlink-eve. One source of truth.

## Philosophy

1. **Memorie e versionuar, jo memorie chat-i.** / Versioned memory, not chat memory.
2. **iOS pari, ne thelle, jo gjeresisht.** / iOS first, deep before wide.
3. **Zero config fiton.** / Zero config wins.
4. **Dygjuhesh eshte identitet.** / Bilingual is identity. Shqipja e para. Albanian first.

## Releases

Nuk ka release të publikuar ende. Release-i i parë do të shfaqet te
[GitHub Releases](https://github.com/peterdsp/kujto/releases) sapo të
tag-ohet versioni i parë.

No release has been published yet. The first release will appear in
[GitHub Releases](https://github.com/peterdsp/kujto/releases) once the first
version is tagged.

## Packages

Kujto ka tani sipërfaqe fillestare package për SwiftPM, KMP/Gradle dhe
Flutter/Dart. Publikimi lidhet me release-et: kur publikohet një GitHub
Release, workflow `Packages` ndërton SwiftPM, publikon Gradle plugin në
GitHub Packages dhe bën dry-run për Flutter.

Për iOS, rruga praktike është Swift Package Manager me URL të repo-s dhe tag
versioni:

```bash
swift package resolve
swift run kujto wire --target /path/to/your/repo --memory
```

Për KMP/Gradle, GitHub Packages është i dobishëm për plugin-in:

```kotlin
plugins {
    id("com.github.peterdsp.kujto") version "0.1.0"
}
```

Për Flutter, package është CLI vegle dhe duhet të shkojë në pub.dev kur të jetë
gati për publikim publik. Nuk duhet të jetë runtime dependency e app-it.

Kujto now has initial package surfaces for SwiftPM, KMP/Gradle, and
Flutter/Dart. Publishing is tied to releases: when a GitHub Release is
published, the `Packages` workflow builds SwiftPM, publishes the Gradle plugin
to GitHub Packages, and dry-runs Flutter.

For iOS, the practical path is Swift Package Manager with the repository URL
and a version tag:

```bash
swift package resolve
swift run kujto wire --target /path/to/your/repo --memory
```

For KMP/Gradle, GitHub Packages is useful for the plugin:

```kotlin
plugins {
    id("com.github.peterdsp.kujto") version "0.1.0"
}
```

For Flutter, the package is a tooling CLI and should go to pub.dev when it is
ready for public publishing. It should not be an app runtime dependency.

### Commit distance

Çdo commit duhet të ketë një distancë logjike të qartë nga tjetri:

- 1 qëllim për commit.
- 5 deri 200 rreshta diff si rregull praktik.
- Ndaje commit-in kur prek dy fusha, për shembull README dhe skript runtime.
- Mos bëj commit vetëm se kaluan 10 minuta. Bëje kur ka një njësi pune që
  kompilon, lexohet dhe mund të kthehet mbrapsht më vete.
- Tag release vetëm kur README, install path dhe smoke test janë në sinkron.

Each commit should have clear logical distance from the next:

- 1 intent per commit.
- 5 to 200 diff lines as a practical default.
- Split the commit when it touches two concerns, for example README and a
  runtime script.
- Do not commit just because 10 minutes passed. Commit when there is a unit of
  work that builds, reads cleanly, and can be reverted on its own.
- Tag a release only when README, install path, and smoke test are aligned.

## Roadmap

### v0.1 (sot / today)

- [x] Memory framework (core, domains/ios, workflows)
- [x] AGENTS.md + adapter për Claude, Codex, Gemini, Copilot, Cursor
- [x] `simulator.sh` me auto-detektim të plotë
- [x] `wire.sh` për integrim me repo
- [x] CI me shellcheck, no-em-dash guard, bilingual sections guard

### v0.2 (per të ardhmen e afërt / near future)
- [ ] Pasurim i `memory/domains/ios/`: SwiftUI patterns, performance, accessibility, testing
- [ ] `snapshots.sh` për regjistrim batch të snapshot-eve
- [ ] `xcode-cleanup.sh` për DerivedData dhe simulator hygiene
- [ ] Homebrew formula
- [ ] CLI i vetëm `kujto` për të gjitha veglat

### v1.0 (zgjerimi / expansion)
- [ ] `memory/domains/android/` (Kotlin, Compose, Gradle)
- [ ] `memory/domains/backend/` (Vapor, Express, FastAPI)
- [ ] `memory/domains/web/` (React, Vue, SvelteKit)
- [ ] Plugin për Xcode dhe VSCode

## Contributing

PR-të janë të mirëpritura. Lexo [CONTRIBUTING.md](CONTRIBUTING.md) i pari. Të dyja gjuhët duhet të mbeten në sinkron në çdo file.

## License

[MIT](LICENSE). Use it, fork it, ship it.

---

<div align="center">

Ndertuar me 🦅 ne Tirane dhe Athine nga [@peterdsp](https://github.com/peterdsp).
Built with 🦅 in Tirana and Athens by [@peterdsp](https://github.com/peterdsp).

Nese Kujto te kurseu nje komande, lere nje ⭐.
If Kujto saved you a command, drop a ⭐.

</div>
