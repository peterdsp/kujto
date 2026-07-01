#!/usr/bin/env bash
# Append a new <item> to site/appcast.xml for the Direct (Ko-fi) channel.
# Sparkle reads this file at SUFeedURL to discover updates.
#
# Requires: sign_update (from Sparkle's SparkleBin/, install with:
#   brew install --cask sparkle-project/homebrew-sparkle/sparkle-bin
# or download from https://github.com/sparkle-project/Sparkle/releases)
#
# Usage:
#   scripts/release/update-appcast.sh <path-to-dmg> <version> <download-url>
#
# The EdDSA private key is read from SPARKLE_ED_PRIVATE_KEY_PATH (a .pem file
# or the raw key). Its matching public key must be baked into Info.plist as
# SUPublicEDKey when the app is built.
set -euo pipefail

DMG_PATH="${1:?Missing dmg path}"
VERSION="${2:?Missing version}"
DOWNLOAD_URL="${3:?Missing download url, e.g. https://github.com/peterdsp/kujto/releases/download/v1.0.0/KujtoStudio-1.0.0.dmg}"
APPCAST_PATH="${APPCAST_PATH:-site/appcast.xml}"
SPARKLE_KEY="${SPARKLE_ED_PRIVATE_KEY_PATH:?SPARKLE_ED_PRIVATE_KEY_PATH is not set}"

if ! command -v sign_update >/dev/null 2>&1; then
    echo "sign_update not found (Sparkle helper). Install from Sparkle releases."
    exit 1
fi

DMG_SIZE=$(stat -f%z "$DMG_PATH")
PUBDATE=$(LC_ALL=en_US.UTF-8 date +"%a, %d %b %Y %H:%M:%S %z")
SIGNATURE=$(sign_update -f "$SPARKLE_KEY" "$DMG_PATH")

ENTRY=$(cat <<EOF
    <item>
      <title>Kujto Studio $VERSION</title>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <pubDate>$PUBDATE</pubDate>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure
        url="$DOWNLOAD_URL"
        length="$DMG_SIZE"
        type="application/octet-stream"
        $SIGNATURE />
    </item>
EOF
)

# Insert the new item right after <language>en</language>.
python3 - "$APPCAST_PATH" "$ENTRY" <<'PY'
import sys, re
path, entry = sys.argv[1], sys.argv[2]
text = open(path).read()
new = re.sub(r"(<language>en</language>\n)", r"\1" + entry + "\n", text, count=1)
if new == text:
    sys.exit("appcast.xml: could not find insertion point after <language>en</language>")
open(path, "w").write(new)
PY

echo "==> Appended $VERSION to $APPCAST_PATH"
