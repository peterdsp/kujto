#!/usr/bin/env bash
# Kujto auto-push (opt-in, OFF by default)
#
# Pushes pending local commits in your Kujto checkout. This is for personal
# forks where you trust the working tree. It will NOT create commits and will
# NOT push if there are uncommitted changes.
#
# Pushon commit-et lokale ne kete fork-un tend te Kujto-s. Per fork-e personale
# ku ke besim ne working tree. NUK krijon commit-e dhe NUK pushon nese ka
# ndryshime te paambullizuara.

set -euo pipefail

KUJTO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$KUJTO_ROOT"

if [[ ! -d .git ]]; then
  exit 0
fi

if [[ -n "$(git status --porcelain)" ]]; then
  exit 0
fi

git fetch --quiet origin 2>/dev/null || exit 0

LOCAL="$(git rev-parse @)"
REMOTE="$(git rev-parse @{u} 2>/dev/null || echo)"

if [[ -z "$REMOTE" || "$LOCAL" == "$REMOTE" ]]; then
  exit 0
fi

BASE="$(git merge-base @ @{u})"
if [[ "$REMOTE" != "$BASE" ]]; then
  # Remote moved, do not auto-push.
  exit 0
fi

git push --quiet origin "$(git rev-parse --abbrev-ref HEAD)"
