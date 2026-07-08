# App Store Connect metadata for Kujto Studio

Drop these values into App Store Connect when submitting v1.0.0. Every string is under the field's max length. Everything is English (`en-US`); we can add locales later.

## Basics

| Field | Value |
| --- | --- |
| Bundle ID | `dev.peterdsp.kujto.studio` |
| SKU | `kujto-studio-1` |
| Primary category | Developer Tools |
| Secondary category | Productivity |
| Age rating | 4+ |
| Copyright | 2026 Petros Dhespollari |
| License | MIT |

## Pricing

| Field | Value |
| --- | --- |
| Tier | €19.99 (Tier 20) |
| Free trial | none |
| In-app purchases | none |

## Name and subtitle

| Field | Value | Chars |
| --- | --- | ---: |
| App name | `Kujto Studio` | 12 |
| Subtitle | `Before you touch this file` | 28 |
| Promotional text | `Stop briefing your AI on the same codebase every day. Kujto reads your repo's memory and shows the rules before you touch a file.` | 128 |

## Keywords

Comma-separated, 100-character limit including commas.

```
AI,claude,cursor,codex,copilot,memory,AGENTS,linter,rules,SwiftUI,developer
```

## Description

```
Kujto Studio is the local memory layer that stops AI agents and developers from breaking your codebase rules.

Every repo has hidden rules. New agents forget them. New developers miss them. Old decisions live in PRs, README files, Slack threads, AGENTS.md, and a dozen scattered docs. Kujto Studio scans that mess and turns it into a living memory map.

Pick a file. Kujto shows you the architecture rules that apply, the risks, the related tests, and the agent context to inject into Claude, Codex, Cursor, or Copilot. A confidence verdict tells you whether the file is safe, needs context, or sits in a danger zone.

One engine, four surfaces:
- Standalone Mac app with a sidebar memory map and a "Before You Touch This File" inspector
- Xcode Source Editor extension that surfaces the rules inline
- VS Code and Cursor extension with a Command Palette entry
- Command-line tool (kujto) for CI and scripting

Kujto is local-first. Nothing leaves your machine. The memory framework and CLI are open source (MIT). This app adds the Mac experience on top.

Perfect for:
- Engineers on convention-heavy architectures (TCA, Clean Swift, Redux)
- Teams using multiple AI coding agents that keep re-deriving the same context
- Anyone tired of pasting "here is our style guide" into a chat every day

Requires macOS 14 or later.
```

Character count: 1,347 (limit 4,000).

## What's New in Version

```
- Before You Touch This File inspector with rules, risks, related tests, and confidence verdict
- Memory map sidebar with agent wire status
- Memory linter surfaces stale rules and broken links
- Xcode Source Editor extension and VS Code / Cursor extension included
- Shortcuts intents: Show Rules, Summarize Rules, Lint Memory, Prepare Agent Context
- Menu bar helper for quick access
- Local-first, nothing uploaded
```

## Support and marketing URLs

| Field | Value |
| --- | --- |
| Support URL | `https://github.com/peterdsp/kujto/issues` |
| Marketing URL | `https://kujto.peterdsp.dev` |
| Privacy Policy URL | `https://github.com/peterdsp/kujto/blob/main/PRIVACY.md` |

## Screenshots

Required macOS sizes: 1280x800, 1440x900, 2560x1600, 2880x1800.

Suggested six screens:
1. Hero: the file inspector for `CheckoutFeature.swift` with `danger zone` badge
2. Sidebar memory map with the scoped/base counts
3. Memory linter panel showing three sample warnings
4. Agents panel with the six agent rows and Wire button
5. Welcome wizard, wire status step
6. Xcode Source Editor extension inserting rules into the editor

Screenshots can be captured on a locally installed build; use `Cmd-Shift-4` and crop to exact sizes.

## Privacy nutrition label

- **Data Not Collected**: correct answer for every category.
- `PrivacyInfo.xcprivacy` is already bundled inside `KujtoStudio.app` and declares `NSPrivacyTracking = false` with the three required accessed-API reasons.

## App Review notes

```
Kujto Studio is a developer tool. It reads local Markdown files from a folder the user picks and displays the applicable rules. It does not modify user files.

The Agents panel calls WireService to symlink AGENTS.md into ~/Applications/kujto or the user-picked target repo. Symlink creation only happens when the user clicks Wire in the panel.

The Sparkle update framework is used only by the direct-download build. It is not linked into or embedded in this App Store build: the update code is gated behind a DIRECT_BUILD compilation condition that is off for the App Store configuration, so Sparkle is never referenced and never linked here. No third-party update mechanism ships in this build. Updates flow through the App Store.

Test account: not applicable, no login.
```

## Version and build numbers

- Marketing version starts at `1.0.0`
- Build number is `github.run_number` (the CI workflow supplies it automatically at archive time)

## Locales to add later

Albanian (`sq-AL`) and Italian (`it-IT`) via the String Catalog once the app has customers asking for them.
