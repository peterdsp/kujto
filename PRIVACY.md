# Kujto Studio, privacy policy

**Last updated: 2026-07-01**

Kujto Studio is a local-first tool. Everything happens on your machine.

## What Kujto Studio does

Kujto Studio reads a directory you explicitly pick (a code repository) and shows you the memory rules that apply to files inside it. It does not send that directory, its contents, or any derived data anywhere.

## What we collect

**Nothing.** Kujto Studio makes no network requests, does not analytics, has no crash reporter, and does not phone home. The app is sandboxed and only accesses the folder you grant it read access to.

- No user account, no login, no cloud sync.
- No usage tracking, no telemetry.
- No advertising identifiers.
- No third-party SDKs that collect data.

## What Kujto Studio stores

The following state lives on your machine only, in your user library:

- Your onboarding completion flag (`kujto.hasOnboarded` in `UserDefaults`)
- A security-scoped bookmark to the repo you picked, so the app can re-read it after a restart

You can clear either from Settings > General > Reset onboarding, or by deleting the app.

## What Kujto CLI does

The `kujto` command-line tool is also local. When you run `kujto wire`, it creates symlinks inside your project repo (`CLAUDE.md`, `CODEX.md`, `GEMINI.md`, `AGENTS.md`, `.cursorrules`, and `.github/copilot-instructions.md`) pointing to Kujto's own `AGENTS.md`. Those symlinks are checked into your git repo if you commit them. The CLI does not send anything over the network.

## Third parties

Kujto does not integrate with third-party services. The AI agents that read Kujto's memory (Claude, Codex, Gemini, Copilot, Cursor) send whatever their own tools send, according to their own privacy policies. Kujto sits between you and your files; it never sees your prompts or your model responses.

## Marketing site

`kujto.peterdsp.dev` is static HTML hosted on GitHub Pages. It does not set analytics cookies. The one exception is the fonts loaded from Google Fonts (Instrument Serif, Inter, JetBrains Mono); those requests are governed by [Google's privacy policy](https://policies.google.com/privacy). If you prefer to self-host the fonts, fork the repo and edit `site/index.html`.

## Changes

If this policy ever changes, the new version will replace this file in the git history. The `Last updated` date at the top will move.

## Contact

Questions or concerns: open an issue at [github.com/peterdsp/kujto/issues](https://github.com/peterdsp/kujto/issues) or reach the author at [peterdsp.dev](https://peterdsp.dev).
