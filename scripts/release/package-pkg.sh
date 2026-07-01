#!/usr/bin/env bash
# Package Kujto Studio.app into a signed, notarized installer PKG for the
# direct (Ko-fi) distribution channel. The PKG installs into /Applications
# and is compatible with Sparkle 2's package installation type.
#
# Requires:
#   DEVELOPER_ID_APPLICATION      the Developer ID Application identity
#   DEVELOPER_ID_INSTALLER        the Developer ID Installer identity
#   NOTARY_KEYCHAIN_PROFILE       a stored notarytool profile name
#
# Usage:
#   scripts/release/package-pkg.sh <path-to-app> <output-dir> <version>
set -euo pipefail

APP_PATH="${1:?Missing app path}"
OUT_DIR="${2:?Missing output dir}"
VERSION="${3:?Missing version, e.g. 1.0.0}"

APP_IDENTITY="${DEVELOPER_ID_APPLICATION:?DEVELOPER_ID_APPLICATION is not set}"
INSTALLER_IDENTITY="${DEVELOPER_ID_INSTALLER:?DEVELOPER_ID_INSTALLER is not set}"
PROFILE="${NOTARY_KEYCHAIN_PROFILE:?NOTARY_KEYCHAIN_PROFILE is not set}"

APP_NAME="$(basename "$APP_PATH" .app)"
BUNDLE_ID="$(defaults read "$APP_PATH/Contents/Info" CFBundleIdentifier)"
PKG_NAME="${APP_NAME}-${VERSION}.pkg"
PKG_PATH="${OUT_DIR}/${PKG_NAME}"
UNSIGNED_PKG="${OUT_DIR}/${APP_NAME}-${VERSION}-unsigned.pkg"

mkdir -p "$OUT_DIR"

echo "==> Signing $APP_PATH with $APP_IDENTITY"
codesign --force --deep --options runtime --sign "$APP_IDENTITY" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "==> Notarizing app before packaging"
NOTARY_ZIP="${OUT_DIR}/${APP_NAME}-notarize.zip"
ditto -c -k --keepParent "$APP_PATH" "$NOTARY_ZIP"
xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP_PATH"
rm -f "$NOTARY_ZIP"

echo "==> Building installer PKG"
# Stage the .app under a component root so pkgbuild places it in /Applications.
STAGING="${OUT_DIR}/staging"
rm -rf "$STAGING"
mkdir -p "$STAGING/Applications"
ditto "$APP_PATH" "$STAGING/Applications/$(basename "$APP_PATH")"

pkgbuild \
    --root "$STAGING" \
    --identifier "${BUNDLE_ID}.installer" \
    --version "$VERSION" \
    --install-location "/" \
    "$UNSIGNED_PKG"

echo "==> Signing PKG with $INSTALLER_IDENTITY"
productsign --sign "$INSTALLER_IDENTITY" "$UNSIGNED_PKG" "$PKG_PATH"
rm -f "$UNSIGNED_PKG"

echo "==> Notarizing PKG"
xcrun notarytool submit "$PKG_PATH" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$PKG_PATH"

rm -rf "$STAGING"
echo "==> Done: $PKG_PATH"
