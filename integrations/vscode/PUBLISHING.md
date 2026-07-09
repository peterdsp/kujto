# Publishing Kujto Studio to the VS Code Marketplace

This extension publishes under:

- Publisher: `peterdsp`
- Extension name: `kujto-vscode`
- Marketplace ID: `peterdsp.kujto-vscode`
- Display name: `Kujto Studio`

Do not change `name` or `publisher` without planning a Marketplace migration.
The Mac app installer also expects `peterdsp.kujto-vscode`.

## Local package

```sh
cd integrations/vscode
npm install
npm run vsce:package
```

This creates `kujto-vscode-0.1.0.vsix`. Install it locally with:

```sh
code --install-extension kujto-vscode-0.1.0.vsix
```

## Publish

Publishing requires access to the `peterdsp` publisher in the Visual Studio
Marketplace.

```sh
cd integrations/vscode
npm install
npm run vsce:publish
```

For manual PAT-based publishing:

```sh
npx vsce login peterdsp
npm run vsce:publish
```

Use an Azure DevOps PAT with Marketplace Manage scope and All accessible
organizations. Do not commit the token or place it in shell scripts.

For automated publishing, prefer Microsoft Entra ID with workload identity
federation or another short-lived credential path. Keep the credential in the
CI provider, not in this repo.

## Version bumps

Let `vsce` bump and publish when the release is ready:

```sh
npx vsce publish patch
npx vsce publish minor
npx vsce publish major
```

`vsce publish` can create a version commit and tag through npm. This repo does
not allow autonomous commits or pushes, so run those commands only when a
maintainer explicitly approves the release.

## Pre-release

```sh
npm run vsce:package:pre
npm run vsce:publish:pre
```

Keep pre-release and stable versions distinct. VS Code does not support full
SemVer pre-release identifiers for extension versions.

## Marketplace checklist

- `package.json` has `publisher`, `license`, `repository`, `homepage`, `bugs`,
  `icon`, `galleryBanner`, `pricing`, categories, and keywords.
- `README.md`, `CHANGELOG.md`, `LICENSE`, and `SUPPORT.md` exist in the
  extension root.
- `icon` points to a PNG file, not SVG.
- README and changelog image URLs, if added later, use HTTPS and avoid SVG
  unless the badge provider is trusted.
- `.vscodeignore` excludes TypeScript source, maps, local VSIX files,
  `node_modules`, and development-only config from the package.
- `npm run compile` passes before packaging.
