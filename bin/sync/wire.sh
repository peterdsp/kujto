#!/usr/bin/env bash
# Kujto wire.sh
# Wire the Kujto memory base into a target repository.
# Creates AGENTS.md, CLAUDE.md, CODEX.md, GEMINI.md as symlinks pointing back
# to your Kujto checkout, so the project picks up Kujto's rules without you
# duplicating files.
#
# Lidh bazen e memories Kujto ne nje repo. Krijon AGENTS.md, CLAUDE.md,
# CODEX.md, GEMINI.md si symlink drejt checkout-it tend te Kujto, qe projekti
# t'i marre rregullat pa duplikim file-ash.
#
# Usage / Perdorimi:
#   cd /path/to/your/repo
#   ~/kujto/bin/sync/wire.sh                # link AGENTS.md and aliases
#   ~/kujto/bin/sync/wire.sh --memory       # also symlink memory/ folder
#   ~/kujto/bin/sync/wire.sh --unwire       # remove all Kujto symlinks

set -euo pipefail

KUJTO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="$(pwd)"

WIRE_MEMORY=0
UNWIRE=0

while (( "$#" )); do
  case "$1" in
    --memory) WIRE_MEMORY=1; shift ;;
    --unwire) UNWIRE=1; shift ;;
    -h|--help)
      sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
done

ok() { printf "  \033[32m✓\033[0m %s\n" "$*"; }
skip() { printf "  \033[90m·\033[0m %s\n" "$*"; }

if [[ "$TARGET" == "$KUJTO_ROOT" ]]; then
  echo "Refusing to wire Kujto into itself."
  exit 1
fi

if [[ "$UNWIRE" -eq 1 ]]; then
  for name in AGENTS.md CLAUDE.md CODEX.md GEMINI.md memory; do
    if [[ -L "$TARGET/$name" ]]; then
      rm "$TARGET/$name"
      ok "Removed $name"
    else
      skip "$name not a Kujto symlink, skipped"
    fi
  done
  exit 0
fi

link_or_skip() {
  local src="$1" dst="$2"
  if [[ -L "$dst" ]]; then
    skip "$dst already a symlink, leaving it"
  elif [[ -e "$dst" ]]; then
    skip "$dst exists and is not a symlink, leaving it"
  else
    ln -s "$src" "$dst"
    ok "$dst -> $src"
  fi
}

link_or_skip "$KUJTO_ROOT/AGENTS.md" "$TARGET/AGENTS.md"
link_or_skip "$KUJTO_ROOT/AGENTS.md" "$TARGET/CLAUDE.md"
link_or_skip "$KUJTO_ROOT/AGENTS.md" "$TARGET/CODEX.md"
link_or_skip "$KUJTO_ROOT/AGENTS.md" "$TARGET/GEMINI.md"

if [[ "$WIRE_MEMORY" -eq 1 ]]; then
  link_or_skip "$KUJTO_ROOT/memory" "$TARGET/memory"
fi

echo
echo "Wired Kujto into $TARGET"
echo "AGENTS.md points to $KUJTO_ROOT/AGENTS.md"
