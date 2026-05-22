#!/usr/bin/env bash
# Kujto auto-pull
# Quietly pulls the Kujto repo if it is behind origin. Useful in cron or
# launchd so your memory stays fresh across machines.
#
# Terheq qetesisht repo-n Kujto nese eshte prapa origin-it. E dobishme ne cron
# ose launchd qe memory te jete e fresket ne disa makina.

set -euo pipefail

KUJTO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$KUJTO_ROOT"

if [[ ! -d .git ]]; then
  exit 0
fi

git fetch --quiet origin 2>/dev/null || exit 0

LOCAL="$(git rev-parse @ 2>/dev/null || echo)"
REMOTE="$(git rev-parse @{u} 2>/dev/null || echo)"

if [[ -z "$LOCAL" || -z "$REMOTE" ]]; then
  exit 0
fi

if [[ "$LOCAL" == "$REMOTE" ]]; then
  exit 0
fi

BASE="$(git merge-base @ @{u} 2>/dev/null || echo)"
if [[ "$LOCAL" != "$BASE" ]]; then
  # Local has diverged, do not auto-pull.
  exit 0
fi

git pull --ff-only --quiet origin "$(git rev-parse --abbrev-ref HEAD)"
