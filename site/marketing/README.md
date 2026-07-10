# Marketing material for Kujto Studio

Everything you need to submit Kujto Studio to the Mac App Store and list it on Ko-fi.

## What's here

```
site/marketing/
  README.md                         you are here
  screenshots/
    index.html                      browse all eleven mockups
    _shell.css                      shared design system
    01-hero.html                    "Before you touch this file" inspector
    02-linter.html                  Memory linter panel
    03-agents.html                  Six agents linked
    04-xcode.html                   Xcode Source Editor extension
    05-vscode.html                  VS Code / Cursor palette command
    06-menubar.html                 Menu bar dropdown
    07-dashboard.html               Confidence dashboard: verdict, trend, causes
    08-predictive.html              Predictive governance: risk before you commit
    09-sandbox.html                 Agent sandbox pre-flight
    10-rewind.html                  Governance rewind: rule history slider
    11-sync.html                    Team sync: signed proposals over Bonjour
    exports/                        generated PNGs (see below)
```

Panels 07-11 showcase the Repository Intelligence OS: predictive risk, agent
pre-flight, governance rewind, and signed peer sync. Like the others, they use
fictional-but-honest data (a `checkout-flow` repo with a payment-risk rule) and
the real command names, palette, and verdict model from the shipping app.

## Preview the mockups

```
cd site
python3 -m http.server 8000
open http://localhost:8000/marketing/screenshots/
```

You can also open any single `.html` file directly in Chrome or Safari; each renders at exactly 1440x900.

## Export as PNGs (for App Store Connect and Ko-fi)

```
bash scripts/marketing/capture-screenshots.sh
```

Produces:

- `screenshots/exports/retina/*.png` at **2880x1800** (App Store retina)
- `screenshots/exports/standard/*.png` at **1440x900** (Ko-fi and the website)

Runs headless Chrome under the hood. Takes about 20 seconds.

## App Store Connect submission

App Store Connect asks for six screenshots per screen size. Upload the six retina exports in this order:

| Slot | File | What sells it |
| --- | --- | --- |
| 1 | `01-hero.png` | The killer screen: rules + risks + tests before you touch a payment file |
| 2 | `03-agents.png` | One source of truth, six agents linked |
| 3 | `02-linter.png` | Deterministic drift detection |
| 4 | `04-xcode.png` | Native Xcode integration |
| 5 | `05-vscode.png` | Same engine in VS Code and Cursor |
| 6 | `06-menubar.png` | Always-visible menu bar |

App metadata (name, subtitle, description, keywords, review notes) lives at [`docs/app-store-metadata.md`](../../docs/app-store-metadata.md).

## Ko-fi listing

Ko-fi's product page accepts up to five gallery images. Use the same six PNGs at the **1440x900** (standard) size (smaller upload, faster page load, still crisp on non-retina displays).

Suggested Ko-fi copy:

> **Kujto Studio Pro, €39 one time**
>
> The direct build of Kujto Studio, made in Europe. Same app as the App Store version, plus early-access features (menu bar, TCA reducer graph, Shortcuts), Sparkle auto-update, and priority issue triage. You're backing an indie developer.

## Iterating on the mockups

- All screens use `_shell.css` for the palette (deep navy, gold, warm cream) and window chrome.
- Change a file name, a rule title, or a badge color in-place; refresh the preview; re-export.
- The app icon in `06-menubar.html` reads from `site/assets/kujto-icon-1024.png`. Swap the icon there and every screen updates.

## When you have the actual app running

For submission, App Store expects screenshots to be honest depictions of the app. The mockups here are pixel-accurate representations built from the same design system as the SwiftUI shell; they show real command names, real memory paths, and the real palette. When you can run the app on your machine (post-signing), you can replace any of these with a live capture using `Cmd-Shift-4` on the real window and dropping the PNG in the same slot.
