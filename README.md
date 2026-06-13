<div align="center">

# 🦅 Kujto

### Stop re-teaching your AI agents every session.

**Versioned, bilingual memory for Claude, Codex, Gemini, Copilot & Cursor.**
**Memorie e versionuar, dygjuheshe per Claude, Codex, Gemini, Copilot & Cursor.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Made in Albania](https://img.shields.io/badge/Made%20in-Albania%20🇦🇱-red)](https://github.com/peterdsp/kujto)
[![Focus](https://img.shields.io/badge/Focus-iOS%20first-blue?logo=apple)](memory/domains/ios/)
[![Mburoja](https://img.shields.io/badge/Security-Mburoja%20🛡️-darkgreen)](memory/domains/web/)
[![Agents](https://img.shields.io/badge/Agents-Claude%20%7C%20Codex%20%7C%20Gemini%20%7C%20Copilot%20%7C%20Cursor-purple)](AGENTS.md)
[![Site](https://img.shields.io/badge/Site-kujto.peterdsp.dev-black)](https://kujto.peterdsp.dev)
[![Version](https://img.shields.io/github/v/release/peterdsp/kujto?label=version)](https://github.com/peterdsp/kujto/releases/latest)
[![Stars](https://img.shields.io/github/stars/peterdsp/kujto?style=social)](https://github.com/peterdsp/kujto/stargazers)

[🇦🇱 Shqip](#-shqip) · [🇬🇧 English](#-english) · [Mburoja](#mburoja-security-playbook) · [Site](#site) · [Memory](#memory) · [Tools](#tools) · [Roadmap](#roadmap)

</div>

---

> **Teach your AI once. It remembers forever.**
> Your coding agents shouldn't need a re-orientation every chat. Kujto is the missing memory layer: a structured, versioned Markdown brain that Claude, Codex, Gemini, Copilot and Cursor all read on every run.

---

## 🇦🇱 Shqip

### Pse Kujto ekziston

Cdo bisede e re me Claude, Codex, Gemini, ose Copilot fillon nga zero. Ti shpenzon kohe duke i ri-mesuar konventat, arkitekturen, stilin, rregullat e git-it. **Kujto** e mban ate dije ne `memory/` te repo-s tende: file Markdown te strukturuar, te versionuar, qe cdo agjent i lexon ne cdo sesion.

Pa abonime. Pa lock-in. Pa magji. Vetem markdown.

### Çfarë merr sot

- 🧠 **Memory framework dygjuhesh** (shqip dhe anglisht ne te njejtin file), me rregulla berthame, konventa iOS, dhe workflow.
- 🏛 **12 guida arkitekture iOS** per MVC, MVP, MVVM, MVVM-C, VIPER, Clean Swift, Clean Architecture, TCA, Redux, ReactorKit, RIBs, MV + @Observable. Plus nje guide vendimi.
- 🛡 **[Mburoja](memory/domains/web/)** - playbook i plote sigurie per aplikacionet web (XSS, CSRF, SSRF, SQLi, XXE, JWT, file upload, path traversal, dhe me shume). 15 file, dygjuhesh.
- 🤝 **Nje burim, pese agjente.** Claude, Codex, Gemini, Copilot, Cursor lexojne te njejtin `AGENTS.md` permes symlink-eve.
- ⚡ **Vegla zero-config:** `simulator.sh` ndez cdo projekt Xcode pa pyetje. `wire.sh` e lidh Kujto-n ne cdo repo me dy komanda.
- 🌐 **Faqe e gjalle** te [kujto.peterdsp.dev](https://kujto.peterdsp.dev) me zbulim automatik gjuhe (shqip per Shqiperi, Kosove, Maqedoni e Veriut).

### Instalim me nje rresht

```bash
curl -fsSL https://raw.githubusercontent.com/peterdsp/kujto/main/bin/install.sh | bash
```

### Quickstart

```bash
# 1. Lidh Kujto-n te projekti yt
cd path/to/your/project
~/kujto/wire.sh

# 2. (iOS) ndez app pa konfigurim
~/kujto/simulator.sh
```

Tani agjentet e tu lexojne `AGENTS.md` dhe ndjekin `memory/MEMORY.md` ne cdo sesion. **Asnje brifing me.**

---

## 🇬🇧 English

### Why Kujto exists

Every fresh chat with Claude, Codex, Gemini, or Copilot starts from zero. You burn minutes (and tokens) re-teaching it your conventions, architecture, style, git rules. **Kujto** keeps that knowledge in your repo's `memory/`: structured, versioned Markdown that every agent reads in every session.

No subscriptions. No lock-in. No magic. Just markdown.

### What you get today

- 🧠 **Bilingual memory framework** (Albanian and English in the same file), with core rules, iOS conventions, and workflows.
- 🏛 **12 iOS architecture guides** covering MVC, MVP, MVVM, MVVM-C, VIPER, Clean Swift, Clean Architecture, TCA, Redux, ReactorKit, RIBs, MV + @Observable. Plus a decision guide.
- 🛡 **[Mburoja](memory/domains/web/)** - a full web-security playbook (XSS, CSRF, SSRF, SQLi, XXE, JWT, file upload, path traversal, and more). 15 files, bilingual.
- 🤝 **One source, five agents.** Claude, Codex, Gemini, Copilot, Cursor read the same `AGENTS.md` via symlinks.
- ⚡ **Zero-config tools:** `simulator.sh` boots any Xcode project, no questions asked. `wire.sh` attaches Kujto to any repo in two commands.
- 🌐 **Live site** at [kujto.peterdsp.dev](https://kujto.peterdsp.dev) with auto-language detection (Albanian for Albania, Kosovo, North Macedonia).

### One-line install

```bash
curl -fsSL https://raw.githubusercontent.com/peterdsp/kujto/main/bin/install.sh | bash
```

### Quickstart

```bash
# 1. Wire Kujto into your project
cd path/to/your/project
~/kujto/wire.sh

# 2. (iOS) boot the app, no config
~/kujto/simulator.sh
```

Your agents now read `AGENTS.md` and follow `memory/MEMORY.md` in every session. **No more briefings.**

---

## Mburoja, security playbook

🛡 **Mburoja** (shqip per *shield*) eshte playbook i sigurise se Kujto-s per aplikacione web. 15 file dygjuhesh qe agjentet i lexojne kur shkruan ose rishikojne kod web, ose kur kerkon nje audit eksplicit.

🛡 **Mburoja** (Albanian for *shield*) is Kujto's web-security playbook. 15 bilingual files your agents read when writing or reviewing web code, or when you explicitly ask for an audit.

**Coverage / Mbulimi:**

| Client-side | Server-side | Tokens & APIs |
|---|---|---|
| [Access control](memory/domains/web/access_control.md) | [SSRF](memory/domains/web/ssrf.md) | [JWT](memory/domains/web/jwt.md) |
| [XSS](memory/domains/web/xss.md) | [File upload](memory/domains/web/file_upload.md) | [API security](memory/domains/web/api_security.md) |
| [CSRF](memory/domains/web/csrf.md) | [SQL injection](memory/domains/web/sql_injection.md) | [Security headers](memory/domains/web/security_headers.md) |
| [Secrets exposure](memory/domains/web/secrets_exposure.md) | [XXE](memory/domains/web/xxe.md) | |
| [Open redirect](memory/domains/web/open_redirect.md) | [Path traversal](memory/domains/web/path_traversal.md) | |
| [Password security](memory/domains/web/password_security.md) | | |

**Trigger / Aktivizimi:** thuaji agjentit "audit me Mburoja" ose "mburoja review", para shkrimit te kodit te ri ose para merge te PR-ve qe prekin auth, upload, redirect, query string.

Tell your agent "audit with Mburoja" or "mburoja review", before writing new code or before merging PRs that touch auth, upload, redirect, or query strings.

---

## Site

Kujto ka nje faqe statike te gjalle / Kujto has a live static site at **[kujto.peterdsp.dev](https://kujto.peterdsp.dev)**.

- E ndertuar me HTML dhe CSS te paster, pa framework, pa build step.
- Dygjuheshe me zbulim automatik vendndodhjeje (IP-based) per vizitore nga Shqiperia, Kosova dhe Maqedonia e Veriut.
- Buton notues (FAB) ne kend te poshtem te djathte per nderrimin manual te gjuhes.
- E publikuar automatikisht me GitHub Pages nga dosja `site/`.

Built with plain HTML and CSS, no framework, no build step. Bilingual with automatic geo-detection (IP-based) for visitors from Albania, Kosovo, and North Macedonia. A floating action button in the bottom-right corner lets users switch languages manually. Auto-deployed via GitHub Pages from the `site/` directory.

```
site/
├── index.html      faqja kryesore me i18n te integruar / main page with inline i18n
├── styles.css       stilet / styles
├── favicon.svg      ikona / favicon
└── CNAME            kujto.peterdsp.dev
```

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
│   ├── ios/                        iOS first
│   │   ├── swift_conventions.md
│   │   ├── xcode_workflow.md
│   │   ├── snapshot_testing.md
│   │   ├── navigation.md
│   │   └── architectures/          12 modele arkitekture / 12 patterns
│   └── web/                        🛡 Mburoja, siguria web / web security
│       ├── README.md
│       ├── access_control.md
│       ├── xss.md
│       ├── csrf.md
│       ├── ssrf.md
│       ├── sql_injection.md
│       ├── jwt.md
│       └── ... (15 file gjithsej / 15 files total)
└── workflows/
    ├── answer_order.md
    ├── pr_descriptions.md
    └── git_hygiene.md
```

Detaje në [docs/memory-architecture.md](docs/memory-architecture.md).

## Tools

Vegla qe shoqerojne memorien / Tools that ship with the memory:

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

### `wire.sh`

Lidh Kujto-n ne cdo repo me nje komande / Attach Kujto to any repo in one command:

```bash
~/kujto/wire.sh
```

## Integrations

| Agent | Wires into | Folder |
|---|---|---|
| Claude Code | `~/.claude/CLAUDE.md` | [`integrations/claude/`](integrations/claude/) |
| OpenAI Codex CLI | `~/.codex/AGENTS.md` | [`integrations/codex/`](integrations/codex/) |
| Gemini CLI | `~/.gemini/GEMINI.md` | [`integrations/gemini/`](integrations/gemini/) |
| GitHub Copilot | `.github/copilot-instructions.md` | [`integrations/copilot/`](integrations/copilot/) |
| Cursor | `.cursor/rules/kujto.mdc` | [`integrations/cursor/`](integrations/cursor/) |

Te peste lexojne te njejtin `AGENTS.md` permes symlink-eve. **One source of truth.**

## Philosophy

1. **Memorie e versionuar, jo memorie chat-i.** / Versioned memory, not chat memory.
2. **iOS pari, ne thelle, jo gjeresisht.** / iOS first, deep before wide.
3. **Zero config fiton.** / Zero config wins.
4. **Dygjuhesh eshte identitet.** / Bilingual is identity. Shqipja e para. Albanian first.
5. **Mburoja qe ne fillim.** / Security from day one. Mburoja covers what most starter kits forget.

## Releases

Versioni aktual / Current version: **v0.1.3**. Shiko / See [GitHub Releases](https://github.com/peterdsp/kujto/releases).

## Packages

Kujto ka siperfaqe fillestare package per SwiftPM, KMP/Gradle dhe Flutter/Dart. Publikimi lidhet me release-et.

Kujto has initial package surfaces for SwiftPM, KMP/Gradle, and Flutter/Dart. Publishing is tied to releases.

### SwiftPM

```bash
swift package resolve
swift run kujto wire --target /path/to/your/repo --memory
```

### KMP / Gradle

```kotlin
plugins {
    id("com.github.peterdsp.kujto") version "0.1.3"
}
```

### Flutter

Tooling CLI, jo runtime dependency. Tooling CLI, not a runtime dependency.

### Commit distance

Çdo commit duhet të ketë një distancë logjike të qartë nga tjetri:

- 1 qëllim për commit.
- 5 deri 200 rreshta diff si rregull praktik.
- Ndaje commit-in kur prek dy fusha, për shembull README dhe skript runtime.
- Tag release vetëm kur README, install path dhe smoke test janë në sinkron.

Each commit should have clear logical distance from the next:

- 1 intent per commit.
- 5 to 200 diff lines as a practical default.
- Split when it touches two concerns (e.g. README and a runtime script).
- Tag a release only when README, install path, and smoke test are aligned.

## Roadmap

### v0.1.3 (aktual / current)

- [x] Memory framework (core, domains/ios, workflows)
- [x] AGENTS.md + adapter per Claude, Codex, Gemini, Copilot, Cursor
- [x] `simulator.sh` me auto-detektim te plote
- [x] `wire.sh` per integrim me repo
- [x] CI me shellcheck, no-em-dash guard, bilingual sections guard
- [x] Faqe statike e gjalle te [kujto.peterdsp.dev](https://kujto.peterdsp.dev)
- [x] Perkthim i plote ne shqip me zbulim automatik vendndodhjeje
- [x] 🛡 **Mburoja**, playbook i plote sigurie web (15 file)

### v0.2 (ne vijim / next)
- [ ] Pasurim i `memory/domains/ios/`: SwiftUI patterns, performance, accessibility, testing
- [ ] `snapshots.sh` per regjistrim batch te snapshot-eve
- [ ] `xcode-cleanup.sh` per DerivedData dhe simulator hygiene
- [ ] Homebrew formula
- [ ] CLI i vetem `kujto` per te gjitha veglat
- [ ] Mburoja v2: OAuth flows, GraphQL deep dive, rate limiting, supply-chain

### Me tej / Later
- [ ] `memory/domains/android/` (Kotlin, Compose, Gradle)
- [ ] `memory/domains/backend/` (Vapor, Express, FastAPI)
- [ ] `memory/domains/frontend/` (React, Vue, SvelteKit)
- [ ] Plugin per Xcode dhe VSCode

## Contributing

PR-të janë të mirëpritura. Lexo [CONTRIBUTING.md](CONTRIBUTING.md) i pari. Të dyja gjuhët duhet të mbeten në sinkron në çdo file.

PRs welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) first. Both languages must stay in sync in every file.

## License

[MIT](LICENSE). Use it, fork it, ship it.

---

<div align="center">

### Nese Kujto te kurseu nje komande, lere nje ⭐
### If Kujto saved you a command, drop a ⭐

[![Star History Chart](https://api.star-history.com/svg?repos=peterdsp/kujto&type=Date)](https://star-history.com/#peterdsp/kujto&Date)

Ndertuar me 🦅 ne Tirane dhe Athine nga [@peterdsp](https://github.com/peterdsp).
Built with 🦅 in Tirana and Athens by [@peterdsp](https://github.com/peterdsp).

</div>
