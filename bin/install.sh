#!/usr/bin/env bash
# Kujto installer
#
# Installs Kujto globally for the agents you have:
# - Claude Code   -> ~/.claude/CLAUDE.md     symlink to AGENTS.md
# - OpenAI Codex  -> ~/.codex/AGENTS.md      symlink to AGENTS.md
# - Gemini CLI    -> ~/.gemini/GEMINI.md     symlink to AGENTS.md
# - Generic AGENTS-> ~/AGENTS.md             symlink to AGENTS.md
#
# Then installs Kujto skills from skills/ into Claude and Codex (see
# bin/skills/install-skills.sh), makes the root scripts executable, and
# reports next steps.
#
# Install Kujto globalisht per agjentet qe ke. Ben symlink AGENTS.md per
# secilin, ben ekzekutues skriptet ne root dhe raporton hapat e radhes.

set -euo pipefail

KUJTO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_FILE="$KUJTO_ROOT/AGENTS.md"

banner() { printf "\n\033[36m▌ Kujto\033[0m  %s\n" "$*"; }
ok() { printf "  \033[32m✓\033[0m %s\n" "$*"; }
skip() { printf "  \033[90m·\033[0m %s\n" "$*"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$*"; }

if [[ ! -f "$AGENTS_FILE" ]]; then
  echo "AGENTS.md not found at $AGENTS_FILE"
  exit 1
fi

banner "Linking AGENTS.md for installed agents"

link_into() {
  local dir="$1" name="$2"
  if [[ ! -d "$dir" ]]; then
    skip "$dir not present, skipping $name"
    return
  fi
  local target="$dir/$name"
  if [[ -L "$target" ]]; then
    rm "$target"
  elif [[ -f "$target" ]]; then
    mv "$target" "$target.bak.$(date +%s)"
    warn "Backed up existing $target"
  fi
  ln -s "$AGENTS_FILE" "$target"
  ok "Linked $target"
}

link_into "$HOME/.claude" "CLAUDE.md"
link_into "$HOME/.codex" "AGENTS.md"
link_into "$HOME/.gemini" "GEMINI.md"

# Generic ~/AGENTS.md for any tool that respects it (Copilot CLI, Aider, etc.)
if [[ -L "$HOME/AGENTS.md" || -f "$HOME/AGENTS.md" ]]; then
  skip "$HOME/AGENTS.md exists, leaving it alone"
else
  ln -s "$AGENTS_FILE" "$HOME/AGENTS.md"
  ok "Linked $HOME/AGENTS.md"
fi

banner "Making root scripts executable"
for f in "$KUJTO_ROOT"/bin/ios/*.sh "$KUJTO_ROOT"/bin/sync/*.sh "$KUJTO_ROOT"/bin/skills/*.sh "$KUJTO_ROOT"/bin/install.sh; do
  [[ -f "$f" ]] || continue
  chmod +x "$f"
  ok "$(basename "$f")"
done

if [[ -x "$KUJTO_ROOT/bin/skills/install-skills.sh" ]]; then
  "$KUJTO_ROOT/bin/skills/install-skills.sh"
fi

banner "Convenience root symlinks"
cd "$KUJTO_ROOT"
for pair in \
  "simulator.sh:bin/ios/simulator.sh" \
  "install.sh:bin/install.sh" \
  "wire.sh:bin/sync/wire.sh" \
  "auto-pull.sh:bin/sync/auto-pull.sh" \
  "auto-push.sh:bin/sync/auto-push.sh"; do
  link="${pair%%:*}"
  target="${pair##*:}"
  if [[ -L "$link" ]] || [[ -e "$link" ]]; then
    continue
  fi
  if [[ -f "$target" ]]; then
    ln -s "$target" "$link"
    ok "$link -> $target"
  fi
done

banner "Done"
cat <<NEXT

Next steps:
  1. Boot an iOS app:        cd your-ios-project && $KUJTO_ROOT/simulator.sh
  2. Wire memory to a repo:  cd your-repo && $KUJTO_ROOT/bin/sync/wire.sh
  3. Read the docs:          $KUJTO_ROOT/docs/getting-started.md

Hapat e radhes:
  1. Ndez nje app iOS:       cd projekti-yt-ios && $KUJTO_ROOT/simulator.sh
  2. Lidh memory me repo:    cd repo-yt && $KUJTO_ROOT/bin/sync/wire.sh
  3. Lexo dokumentet:        $KUJTO_ROOT/docs/getting-started.md

NEXT
