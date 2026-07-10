#!/usr/bin/env bash
# Renders the marketing HTML mockups to PNG at the App Store retina size
# (2880x1800) and the 13-inch size (1440x900) using headless Chrome.
#
# App Store Connect accepts screenshots at either size; retina 2880x1800 is
# the highest-quality option and shows on every device tier.
#
# Requirements:
#   - Google Chrome installed at /Applications/Google Chrome.app
#     (fallback: brew install --cask chromium)
#
# Usage:
#   bash scripts/marketing/capture-screenshots.sh              # both sizes
#   bash scripts/marketing/capture-screenshots.sh retina       # retina only
#   bash scripts/marketing/capture-screenshots.sh standard     # 1440x900 only

set -euo pipefail

SIZE="${1:-both}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCREENS_DIR="$REPO_ROOT/site/marketing/screenshots"
OUT_DIR="$REPO_ROOT/site/marketing/screenshots/exports"

if [ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; then
    CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
elif command -v chromium >/dev/null 2>&1; then
    CHROME="$(command -v chromium)"
else
    echo "Google Chrome (or chromium) is required to capture screenshots."
    echo "Install Chrome from https://www.google.com/chrome/ or:"
    echo "  brew install --cask chromium"
    exit 1
fi

mkdir -p "$OUT_DIR/retina" "$OUT_DIR/standard"

capture() {
    local html="$1"
    local width="$2"
    local height="$3"
    local scale="$4"
    local out="$5"
    local name; name="$(basename "$html" .html)"
    echo "==> $name @ ${width}x${height} (scale ${scale}x)"
    "$CHROME" \
        --headless=new \
        --disable-gpu \
        --hide-scrollbars \
        --force-device-scale-factor="$scale" \
        --window-size="${width},${height}" \
        --screenshot="$out/${name}.png" \
        "file://$html" 2>/dev/null
}

for HTML in "$SCREENS_DIR"/[0-9][0-9]-*.html; do
    [ -f "$HTML" ] || continue
    case "$SIZE" in
        both|retina)   capture "$HTML" 1440 900 2 "$OUT_DIR/retina" ;;
    esac
    case "$SIZE" in
        both|standard) capture "$HTML" 1440 900 1 "$OUT_DIR/standard" ;;
    esac
done

echo ""
echo "Done. Screenshots exported to:"
echo "  $OUT_DIR/retina/    (2880x1800, for App Store Connect)"
echo "  $OUT_DIR/standard/  (1440x900,  for the website and Ko-fi)"
