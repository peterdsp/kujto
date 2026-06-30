# Kujto for Xcode (Source Editor extension)

> Status: scaffold. The sources are complete, but the Xcode project is built on your machine (it needs the GUI).

### What it does

Adds the command **Editor > Kujto > Show Rules for This File** to Xcode. When invoked it reads the buffer text, finds the memory rules that match, and inserts them as an undoable comment block (Cmd-Z) at the top.

### The constraint that shapes the design

A Source Editor extension cannot see the file path: the invocation carries only the text. So instead of path globs we use **content signals** (`RuleIndex.resolveByContent`): each glob yields a signal token (`**/*Reducer.swift` yields `Reducer`) that is searched as an identifier in the buffer. Same `RuleIndex`, two entry points: path for the app/CLI, content for the extension.

### Pieces

```
integrations/xcode-extension/
  App/                 container app (picks the repo, shares it via App Group)
  Extension/           the extension (command + principal class + Info.plist)
  Shared/              SharedConfig (the App Group bridge)
  project.yml          XcodeGen spec
```

### Build

1. Install XcodeGen: `brew install xcodegen`.
2. From this folder: `xcodegen generate`.
3. Open `KujtoStudio.xcodeproj`, select the `KujtoStudio` scheme, run.
4. In the app: click "Choose repo..." and pick your repo.
5. Enable the extension: System Settings > Login Items & Extensions > Xcode Source Editor.
6. In Xcode: Editor > Kujto > Show Rules for This File.

Without XcodeGen: create a macOS app plus an "Xcode Source Editor Extension" target by hand, add the files from `App/`, `Extension/`, `Shared/`, add the local `KujtoCore` package (repo root) to both targets, and set the App Group `group.dev.peterdsp.kujto`.

### Localization

The container app's user-facing strings live in `App/Localizable.xcstrings` (source English, Albanian as a locale). SwiftUI `Text` picks up the catalog automatically.

### Sandbox note

The extension is sandboxed. The root is stored as a security-scoped bookmark. For development builds you may disable the extension's sandbox; for distribution, keep the bookmark.
