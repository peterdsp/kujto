#!/usr/bin/env bash
# Kujto simulator.sh
# Build, install, launch and tail any iOS Xcode project in the iOS Simulator
# with zero configuration. Detects workspace, scheme, simulator and bundle id
# automatically. Works on any Xcode 15+ project.
#
# Ndertim, instalim, hapje dhe ndjekje e log-eve te cdo projekti Xcode iOS ne
# Simulator pa konfigurim. Auto-detekton workspace, scheme, simulator dhe
# bundle id. Funksionon ne cdo projekt Xcode 15+.
#
# Usage / Perdorimi:
#   ./simulator.sh                          full auto, debug
#   ./simulator.sh --release                full auto, release
#   ./simulator.sh --device "iPhone 15"     pin device
#   ./simulator.sh --scheme MyApp           pin scheme
#   ./simulator.sh --clean                  clean DerivedData first
#   ./simulator.sh --no-logs                do not stream logs after launch
#   ./simulator.sh --list                   list schemes and devices, then exit
#   ./simulator.sh --stop                   terminate app and shutdown simulator
#   ./simulator.sh --help                   show this help

set -euo pipefail

# ---- defaults --------------------------------------------------------------

CONFIGURATION="Debug"
DEVICE_HINT=""
SCHEME_OVERRIDE=""
PROJECT_OVERRIDE=""
CLEAN=0
STREAM_LOGS=1
LIST_ONLY=0
STOP_MODE=0

KUJTO_BANNER="\033[36m▌ Kujto · iOS\033[0m"

# ---- helpers ---------------------------------------------------------------

log() { printf "%b  %s\n" "$KUJTO_BANNER" "$*"; }
warn() { printf "\033[33m!!\033[0m %s\n" "$*" >&2; }
die() { printf "\033[31m!!\033[0m %s\n" "$*" >&2; exit 1; }

require() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required tool: $1"
}

usage() {
  sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

# ---- arg parsing -----------------------------------------------------------

while (( "$#" )); do
  case "$1" in
    --release) CONFIGURATION="Release"; shift ;;
    --debug) CONFIGURATION="Debug"; shift ;;
    --device) DEVICE_HINT="${2:-}"; shift 2 ;;
    --scheme) SCHEME_OVERRIDE="${2:-}"; shift 2 ;;
    --project) PROJECT_OVERRIDE="${2:-}"; shift 2 ;;
    --clean) CLEAN=1; shift ;;
    --no-logs) STREAM_LOGS=0; shift ;;
    --list) LIST_ONLY=1; shift ;;
    --stop|--cease) STOP_MODE=1; shift ;;
    -h|--help) usage ;;
    *) die "Unknown flag: $1 (try --help)" ;;
  esac
done

# ---- preflight -------------------------------------------------------------

require xcodebuild
require xcrun

if [[ "$(uname)" != "Darwin" ]]; then
  die "simulator.sh requires macOS"
fi

# ---- find project ----------------------------------------------------------

find_project() {
  if [[ -n "$PROJECT_OVERRIDE" ]]; then
    echo "$PROJECT_OVERRIDE"
    return
  fi

  local ws proj
  ws="$(find . -maxdepth 2 -name '*.xcworkspace' -not -path '*.xcodeproj/*' -not -path '*/Pods/*' 2>/dev/null | head -n1)"
  if [[ -n "$ws" ]]; then
    echo "$ws"
    return
  fi
  proj="$(find . -maxdepth 2 -name '*.xcodeproj' -not -path '*/Pods/*' 2>/dev/null | head -n1)"
  if [[ -n "$proj" ]]; then
    echo "$proj"
    return
  fi
  echo ""
}

PROJECT_PATH="$(find_project)"
if [[ -z "$PROJECT_PATH" ]]; then
  die "No .xcworkspace or .xcodeproj found in $(pwd). Run inside an iOS project."
fi

if [[ "$PROJECT_PATH" == *.xcworkspace ]]; then
  PROJECT_FLAG=(-workspace "$PROJECT_PATH")
else
  PROJECT_FLAG=(-project "$PROJECT_PATH")
fi
PROJECT_NAME="$(basename "$PROJECT_PATH" | sed 's/\.[^.]*$//')"

log "Project: $PROJECT_PATH"

# ---- pick scheme -----------------------------------------------------------

list_schemes() {
  xcodebuild "${PROJECT_FLAG[@]}" -list -json 2>/dev/null \
    | /usr/bin/python3 -c '
import json, sys
data = json.load(sys.stdin)
info = data.get("project") or data.get("workspace") or {}
for s in info.get("schemes", []):
    print(s)
'
}

pick_scheme() {
  if [[ -n "$SCHEME_OVERRIDE" ]]; then
    echo "$SCHEME_OVERRIDE"
    return
  fi
  local schemes scheme
  schemes="$(list_schemes)"
  if [[ -z "$schemes" ]]; then
    die "No schemes found in $PROJECT_PATH"
  fi
  # Prefer a scheme that matches the project name, else first non-Tests scheme.
  scheme="$(echo "$schemes" | grep -i -x "$PROJECT_NAME" | head -n1 || true)"
  if [[ -z "$scheme" ]]; then
    scheme="$(echo "$schemes" | grep -v -iE 'Tests?$|UITests$|Snapshot' | head -n1 || true)"
  fi
  if [[ -z "$scheme" ]]; then
    scheme="$(echo "$schemes" | head -n1)"
  fi
  echo "$scheme"
}

SCHEME="$(pick_scheme)"
[[ -n "$SCHEME" ]] || die "Could not pick a scheme"
log "Scheme:  $SCHEME"

# ---- pick simulator --------------------------------------------------------

list_devices_json() {
  xcrun simctl list devices --json
}

pick_device_udid() {
  local hint="$1"
  list_devices_json | DEVICE_HINT="$hint" /usr/bin/python3 -c '
import json, os, sys, re

data = json.load(sys.stdin)
hint = os.environ.get("DEVICE_HINT", "").strip().lower()
runtimes = data.get("devices", {})

def version_key(runtime):
    m = re.search(r"iOS-(\d+)-?(\d+)?", runtime)
    if not m:
        return (0, 0)
    return (int(m.group(1)), int(m.group(2) or 0))

candidates = []
for runtime, devices in runtimes.items():
    if "iOS" not in runtime:
        continue
    for d in devices:
        if not d.get("isAvailable", False):
            continue
        name = d.get("name", "")
        if "iPhone" not in name:
            continue
        candidates.append((runtime, d, name))

if not candidates:
    sys.exit(0)

booted = [c for c in candidates if c[1].get("state") == "Booted"]
def matches(hint, name):
    if not hint:
        return True
    return hint in name.lower()

pool = booted if booted else candidates
filtered = [c for c in pool if matches(hint, c[2])]
if not filtered and pool is booted:
    filtered = [c for c in candidates if matches(hint, c[2])]
if not filtered:
    sys.exit(0)

filtered.sort(key=lambda c: (version_key(c[0]), c[2]), reverse=True)
runtime, dev, name = filtered[0]
print(dev["udid"])
print(name)
print(runtime)
'
}

if [[ "$LIST_ONLY" -eq 1 ]]; then
  log "Schemes:"
  list_schemes | sed 's/^/    /'
  log "Devices:"
  xcrun simctl list devices available | grep -E "iPhone" | sed 's/^/    /'
  exit 0
fi

DEV_INFO="$(pick_device_udid "$DEVICE_HINT")"
if [[ -z "$DEV_INFO" ]]; then
  die "No available iPhone simulator found. Try --list."
fi
UDID="$(echo "$DEV_INFO" | sed -n 1p)"
DEV_NAME="$(echo "$DEV_INFO" | sed -n 2p)"
DEV_RUNTIME="$(echo "$DEV_INFO" | sed -n 3p)"
log "Device:  $DEV_NAME ($DEV_RUNTIME)"
log "UDID:    $UDID"

# ---- stop mode -------------------------------------------------------------

if [[ "$STOP_MODE" -eq 1 ]]; then
  log "Stopping any running app on $DEV_NAME"
  xcrun simctl terminate "$UDID" all >/dev/null 2>&1 || true
  log "Shutting down simulator"
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  log "Done."
  exit 0
fi

# ---- boot simulator --------------------------------------------------------

log "Booting simulator if needed"
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || xcrun simctl boot "$UDID"
open -a Simulator --args -CurrentDeviceUDID "$UDID" >/dev/null 2>&1 || true

# ---- build -----------------------------------------------------------------

DERIVED_DATA="${KUJTO_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/Kujto-$PROJECT_NAME}"
mkdir -p "$DERIVED_DATA"

if [[ "$CLEAN" -eq 1 ]]; then
  log "Cleaning DerivedData at $DERIVED_DATA"
  rm -rf "$DERIVED_DATA"
  mkdir -p "$DERIVED_DATA"
fi

log "Resolving Swift Package dependencies"
xcodebuild "${PROJECT_FLAG[@]}" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DERIVED_DATA" \
  -skipMacroValidation \
  -resolvePackageDependencies >/dev/null

XCBEAUTIFY_PIPE=()
if command -v xcbeautify >/dev/null 2>&1; then
  XCBEAUTIFY_PIPE=(xcbeautify)
fi

log "Building $SCHEME ($CONFIGURATION) for simulator"
set +e
if [[ ${#XCBEAUTIFY_PIPE[@]} -gt 0 ]]; then
  xcodebuild "${PROJECT_FLAG[@]}" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$DERIVED_DATA" \
    -skipMacroValidation \
    build 2>&1 | "${XCBEAUTIFY_PIPE[@]}"
  STATUS=${PIPESTATUS[0]}
else
  xcodebuild "${PROJECT_FLAG[@]}" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$DERIVED_DATA" \
    -skipMacroValidation \
    -quiet \
    build
  STATUS=$?
fi
set -e

if [[ "$STATUS" -ne 0 ]]; then
  die "Build failed (exit $STATUS)"
fi

# ---- locate .app and bundle id --------------------------------------------

APP_PATH="$(find "$DERIVED_DATA/Build/Products" -type d -name '*.app' -path "*${CONFIGURATION}-iphonesimulator*" 2>/dev/null | head -n1)"
if [[ -z "$APP_PATH" ]]; then
  die "Build succeeded but no .app found under $DERIVED_DATA"
fi
log "Built:   $APP_PATH"

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist" 2>/dev/null || true)"
if [[ -z "$BUNDLE_ID" ]]; then
  die "Could not read CFBundleIdentifier from $APP_PATH/Info.plist"
fi
log "Bundle:  $BUNDLE_ID"

# ---- install and launch ----------------------------------------------------

log "Installing on simulator"
xcrun simctl install "$UDID" "$APP_PATH"

log "Launching $BUNDLE_ID"
xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null

log "Done. Simulator is in front."

# ---- stream logs -----------------------------------------------------------

if [[ "$STREAM_LOGS" -eq 1 ]]; then
  log "Streaming logs (Ctrl-C to stop, app keeps running)"
  PROCESS_NAME="$(basename "$APP_PATH" .app)"
  exec xcrun simctl spawn "$UDID" log stream \
    --level=info \
    --style=compact \
    --predicate "process == \"$PROCESS_NAME\""
fi
