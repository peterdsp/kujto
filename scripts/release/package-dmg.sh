#!/usr/bin/env bash
# Package Kujto Studio.app into a signed, notarized DMG for the direct
# (Ko-fi) distribution channel.
#
# Requires: create-dmg, xcrun notarytool creds set as env
#   DEVELOPER_ID_APPLICATION      the Developer ID Application identity
#   NOTARY_KEYCHAIN_PROFILE       a stored notarytool profile name
#
# Usage:
#   scripts/release/package-dmg.sh <path-to-app> <output-dir> <version>
set -euo pipefail

APP_PATH="${1:?Missing app path}"
OUT_DIR="${2:?Missing output dir}"
VERSION="${3:?Missing version, e.g. 1.0.0}"
IDENTITY="${DEVELOPER_ID_APPLICATION:?DEVELOPER_ID_APPLICATION is not set}"
PROFILE="${NOTARY_KEYCHAIN_PROFILE:?NOTARY_KEYCHAIN_PROFILE is not set}"

APP_NAME="$(basename "$APP_PATH" .app)"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${OUT_DIR}/${DMG_NAME}"

mkdir -p "$OUT_DIR"

echo "==> Signing $APP_PATH"
codesign --force --deep --options runtime --sign "$IDENTITY" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "==> Notarizing app (this can take a few minutes)"
NOTARY_ZIP="${OUT_DIR}/${APP_NAME}-notarize.zip"
ditto -c -k --keepParent "$APP_PATH" "$NOTARY_ZIP"
xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP_PATH"
rm -f "$NOTARY_ZIP"

echo "==> Building DMG"
if ! command -v create-dmg >/dev/null 2>&1; then
    echo "create-dmg not found. Install it: brew install create-dmg"
    exit 1
fi
create-dmg \
    --volname "$APP_NAME" \
    --window-size 540 360 \
    --icon "${APP_NAME}.app" 150 180 \
    --app-drop-link 400 180 \
    --hide-extension "${APP_NAME}.app" \
    "$DMG_PATH" \
    "$APP_PATH"

echo "==> Signing DMG"
codesign --force --sign "$IDENTITY" "$DMG_PATH"

echo "==> Notarizing DMG"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG_PATH"

echo "==> Done: $DMG_PATH"
