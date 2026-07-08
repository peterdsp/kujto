#!/usr/bin/env bash
# Rebuilds the pre-extracted editor extension bundle that Kujto Studio ships
# in Contents/Resources/. Runtime install just copies this tree into the
# user-granted extensions folder, so the sandbox never needs to unzip.
#
# Run after any change under integrations/vscode/.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
src="$repo_root/integrations/vscode"
dst="$repo_root/integrations/xcode-extension/App/EditorExtensionBundle/kujto-vscode"

cd "$src"
npm run compile

vsix_tmp="$(mktemp -d)"
trap 'rm -rf "$vsix_tmp"' EXIT

npx --yes @vscode/vsce package --allow-missing-repository --skip-license --out "$vsix_tmp/kujto-vscode.vsix"
unzip -q -o "$vsix_tmp/kujto-vscode.vsix" -d "$vsix_tmp/unpacked"

rm -rf "$dst"
mkdir -p "$(dirname "$dst")"
cp -R "$vsix_tmp/unpacked/extension" "$dst"

echo "Rebuilt: $dst"
