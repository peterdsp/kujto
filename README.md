<div align="center">

# 🦅 Kujto

**AI-ja e parë shqiptare e memories për iOS. Portative, dygjuhëshe, open source.**
**The first Albanian iOS memory AI. Portable, bilingual, open source.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Made in Albania](https://img.shields.io/badge/Made%20in-Albania%20🇦🇱-red)](https://github.com/peterdsp/kujto)
[![iOS](https://img.shields.io/badge/iOS-Xcode%2015%2B-blue?logo=apple)](https://developer.apple.com/xcode/)
[![Agents](https://img.shields.io/badge/Agents-Claude%20%7C%20Codex%20%7C%20Gemini%20%7C%20Copilot-purple)](AGENTS.md)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

[🇦🇱 Shqip](#-shqip) · [🇬🇧 English](#-english) · [Quickstart](#quickstart) · [Memory](#memory) · [Simulator](#simulator)

</div>

---

## 🇦🇱 Shqip

**Kujto** ("kujto!" në mënyrën urdhërore) është dy gjëra në një repo:

1. **Një framework memorie** për agjentët AI (Claude, Codex, Gemini, Copilot), që mban të vërtetën e gjatë në file Markdown të strukturuar dhe të versionuar, jo në kontekstin e brishtë të një bisede.
2. **Një `simulator.sh` ultra-portativ** për iOS, që ndizet pa konfigurim në çdo repo Xcode. Auto-detekton workspace, scheme, simulator dhe bundle id, ndërton, instalon, hap dhe streamon log-et.

Pse ekziston: agjentët AI harrojnë. iOS dev-i shqiptar nuk ka pasur kurrë një bazë memorie në gjuhën amtare. Dhe ndezja e një app-i në simulator ka mbetur 4 komanda më shumë nga sa duhet.

### Instalim me një rresht

```bash
curl -fsSL https://raw.githubusercontent.com/peterdsp/kujto/main/bin/install.sh | bash
```

Ose klono dhe instalo lokal:

```bash
git clone https://github.com/peterdsp/kujto.git ~/kujto
cd ~/kujto && ./install.sh
```

### Quickstart

Ndez një app iOS pa konfigurim:

```bash
cd path/to/your/ios/project
~/kujto/simulator.sh
```

Lidh memory-në te projekti yt:

```bash
cd path/to/your/project
~/kujto/bin/sync/wire.sh
```

### Çfarë ke pas instalimit

```
~/kujto/
├── memory/        bazë memorie dygjuhëshe për agjentët AI
├── bin/ios/       simulator.sh (zero-config) dhe helpera iOS
├── bin/sync/      install, wire, auto-pull, auto-push
└── integrations/  shabllonë për Claude, Codex, Gemini, Copilot, Cursor
```

---

## 🇬🇧 English

**Kujto** ("remember!" in Albanian, imperative) is two things in one repo:

1. **A memory framework** for AI agents (Claude, Codex, Gemini, Copilot) that stores long-term truth in structured, versioned Markdown files instead of the fragile context of a single chat.
2. **An ultra-portable `simulator.sh`** for iOS that boots any Xcode project with zero config. It auto-detects workspace, scheme, simulator, and bundle id, then builds, installs, launches, and streams logs.

Why it exists: AI agents forget. Albanian iOS devs never had a native-language memory base. And booting an app in the simulator still takes 4 commands more than it should.

### One-line install

```bash
curl -fsSL https://raw.githubusercontent.com/peterdsp/kujto/main/bin/install.sh | bash
```

Or clone and install locally:

```bash
git clone https://github.com/peterdsp/kujto.git ~/kujto
cd ~/kujto && ./install.sh
```

### Quickstart

Boot an iOS app with zero config:

```bash
cd path/to/your/ios/project
~/kujto/simulator.sh
```

Wire memory into your project:

```bash
cd path/to/your/project
~/kujto/bin/sync/wire.sh
```

### What you get

```
~/kujto/
├── memory/        bilingual memory base for AI agents
├── bin/ios/       simulator.sh (zero-config) and iOS helpers
├── bin/sync/      install, wire, auto-pull, auto-push
└── integrations/  templates for Claude, Codex, Gemini, Copilot, Cursor
```

---

## Quickstart

<table>
<tr><th>Step</th><th>Hap</th><th>Command</th></tr>
<tr><td>1. Install</td><td>1. Instalo</td><td><code>curl -fsSL https://raw.githubusercontent.com/peterdsp/kujto/main/bin/install.sh | bash</code></td></tr>
<tr><td>2. Boot an iOS app</td><td>2. Ndez app-in iOS</td><td><code>cd your-ios-project && ~/kujto/simulator.sh</code></td></tr>
<tr><td>3. Wire memory</td><td>3. Lidh memory-në</td><td><code>~/kujto/bin/sync/wire.sh</code></td></tr>
</table>

## Memory

The memory framework lives in [`memory/`](memory/). Read it in this order:

1. [`AGENTS.md`](AGENTS.md) (top-level rules for every agent, bilingual)
2. [`memory/MEMORY.md`](memory/MEMORY.md) (the index)
3. The referenced files only when relevant to the task

Memory is split into:

- [`memory/core/`](memory/core/): identity, writing style, safety, git, handoff
- [`memory/domains/ios/`](memory/domains/ios/): Swift, Xcode, snapshots, TCA
- [`memory/workflows/`](memory/workflows/): portable workflows like PR descriptions

See [docs/memory-architecture.md](docs/memory-architecture.md) for the full spec.

## Simulator

`simulator.sh` is the headline iOS tool. Zero config in 99% of cases.

```bash
./simulator.sh                       # auto-detect everything
./simulator.sh --device "iPhone 15"  # pin a device
./simulator.sh --scheme MyApp        # pin a scheme
./simulator.sh --clean               # rebuild from scratch
./simulator.sh --list                # list schemes and devices
./simulator.sh --no-logs             # do not stream logs
```

See [docs/simulator-guide.md](docs/simulator-guide.md) for all flags.

## Integrations

Kujto wires into the agents you already use:

| Agent | File | Folder |
|---|---|---|
| Claude Code | `~/.claude/CLAUDE.md` | [`integrations/claude/`](integrations/claude/) |
| OpenAI Codex CLI | `~/.codex/CODEX.md` | [`integrations/codex/`](integrations/codex/) |
| Gemini CLI | `~/.gemini/GEMINI.md` | [`integrations/gemini/`](integrations/gemini/) |
| GitHub Copilot | `.github/copilot-instructions.md` | [`integrations/copilot/`](integrations/copilot/) |
| Cursor | `.cursor/rules` | [`integrations/cursor/`](integrations/cursor/) |

All four (Claude, Codex, Gemini, Copilot) read the same `AGENTS.md` via symlinks. One source of truth.

## Philosophy

Three rules drive every decision in this repo:

1. **One source of truth.** Memory is versioned Markdown, not chat history.
2. **Zero config wins.** If a flag can default, it defaults.
3. **Bilingual is identity.** Albanian first, English equal. Never lose either.

## Roadmap

- [x] Memory framework (core, domains/ios, workflows)
- [x] `simulator.sh` with full auto-detection
- [x] Bilingual everything
- [ ] `kujto` CLI (single entry point)
- [ ] Homebrew formula
- [ ] VSCode and Xcode extension wrappers
- [ ] Templates for SwiftPM, TCA, MVVM

## Contributing

PRs welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) first. Both languages must stay in sync in every file.

## License

[MIT](LICENSE). Use it, fork it, ship it.

---

<div align="center">

Built with 🦅 in Tirana and Athens by [@peterdsp](https://github.com/peterdsp).

If Kujto saved you a command, drop a ⭐.

</div>
