# Udhezues `simulator.sh` / `simulator.sh` guide

[🇦🇱 Shqip](#shqip) · [🇬🇧 English](#english)

---

## Shqip

### Cfare ben
1. Gjen `*.xcworkspace` ose `*.xcodeproj` ne CWD.
2. Listoji scheme me `xcodebuild -list -json`, zgjedh me te lidhurin me emrin e projektit ose te parin jo-test.
3. Gjen iPhone simulator: i pari i ndezur, perndryshe iOS me te ri te disponueshem.
4. Zgjidh varesite Swift Package.
5. Ndertim me `xcodebuild build`, `xcbeautify` nese eshte instaluar.
6. Nxjerr `CFBundleIdentifier` nga `Info.plist` i ndertuar.
7. Hap simulatorin, instalon `.app`, lanson app-in.
8. Streamon log-et e procesit.

### Flags
```
--release          ndertim Release ne vend te Debug
--debug            ndertim Debug (default)
--device "NAME"    fiksim device, p.sh. "iPhone 15"
--scheme NAME      fiksim scheme
--project PATH     fiksim file projekti ose workspace
--clean            fshi DerivedData para ndertimit
--no-logs          mos i streamo log-et pas hapjes
--list             liston schemes dhe devices, del
--stop             mbyll cdo app dhe shuaj simulatorin
--help             ndihme
```

### Variabla mjedisi
```
KUJTO_DERIVED_DATA   path alternativ per DerivedData
```

### Kerkesa
- macOS 14+
- Xcode 15+ me Command Line Tools
- iOS Simulator runtime te instaluar
- Python 3 (vjen me macOS)

### Sjellja kur gjeret shkojne keq
- Pa workspace dhe pa project: ndalon me mesazh te qarte.
- Pa simulator iPhone te disponueshem: ndalon dhe sugjeron `--list`.
- Ndertimi deshton: kalon kodin e gabimit te xcodebuild.
- Pa `xcbeautify`: perdor `-quiet` te xcodebuild si fallback.

### Sugjerime
Instalon `xcbeautify` per output te bukur:
```bash
brew install xcbeautify
```

---

## English

### What it does
1. Finds `*.xcworkspace` or `*.xcodeproj` in CWD.
2. Lists schemes via `xcodebuild -list -json`, picks the one matching the project name or the first non-test scheme.
3. Finds an iPhone simulator: first one booted, otherwise the newest iOS available.
4. Resolves Swift Package dependencies.
5. Builds with `xcodebuild build`, piped through `xcbeautify` if installed.
6. Reads `CFBundleIdentifier` from the built `Info.plist`.
7. Opens the simulator, installs the `.app`, launches it.
8. Streams the process's logs.

### Flags
```
--release          Release build instead of Debug
--debug            Debug build (default)
--device "NAME"    pin a device, e.g. "iPhone 15"
--scheme NAME      pin a scheme
--project PATH     pin a project or workspace file
--clean            wipe DerivedData before build
--no-logs          do not stream logs after launch
--list             list schemes and devices, then exit
--stop             terminate any app and shut down the simulator
--help             help
```

### Environment variables
```
KUJTO_DERIVED_DATA   alternative DerivedData path
```

### Requirements
- macOS 14+
- Xcode 15+ with Command Line Tools
- An iOS Simulator runtime installed
- Python 3 (ships with macOS)

### Behaviour on failures
- No workspace and no project: stops with a clear message.
- No iPhone simulator available: stops and suggests `--list`.
- Build failed: forwards xcodebuild's exit code.
- No `xcbeautify`: falls back to `xcodebuild -quiet`.

### Tip
Install `xcbeautify` for pretty output:
```bash
brew install xcbeautify
```
