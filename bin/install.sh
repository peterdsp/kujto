#!/usr/bin/env bash
# Kujto installer
#
# Works two ways:
#   - Remote one-liner (no clone needed):
#       curl -fsSL https://raw.githubusercontent.com/peterdsp/kujto/main/bin/install.sh | bash
#     It clones Kujto into ~/.kujto (override with KUJTO_HOME), then installs.
#   - From a local clone:
#       ./bin/install.sh
#     It uses the checkout it lives in.
#
# What it does:
#   - Links AGENTS.md globally for the agents you have installed:
#       Claude Code  -> ~/.claude/CLAUDE.md
#       OpenAI Codex -> ~/.codex/AGENTS.md
#       Gemini CLI   -> ~/.gemini/GEMINI.md
#       Generic      -> ~/AGENTS.md
#   - Installs Kujto skills into Claude and Codex.
#   - Makes the repo scripts executable and reports next steps.

set -euo pipefail

REPO_URL="${KUJTO_REPO_URL:-https://github.com/peterdsp/kujto.git}"
KUJTO_HOME="${KUJTO_HOME:-$HOME/.kujto}"

banner() { printf "\n\033[36m▌ Kujto\033[0m  %s\n" "$*"; }
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; }
skip() { printf "  \033[90m·\033[0m %s\n" "$*"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$*"; }
die()  { printf "\n\033[31m✗ Kujto\033[0m  %s\n" "$*" >&2; exit 1; }

# Resolve the Kujto checkout. BASH_SOURCE is empty when this script is piped
# to bash (curl | bash), so guard it under `set -u` and fall back to cloning.
resolve_root() {
  local src="${BASH_SOURCE[0]:-}"
  if [[ -n "$src" ]]; then
    local here
    here="$(cd "$(dirname "$src")/.." >/dev/null 2>&1 && pwd)" || here=""
    if [[ -n "$here" && -f "$here/AGENTS.md" ]]; then
      KUJTO_ROOT="$here"
      return
    fi
  fi

  # Piped install: clone or update ~/.kujto.
  command -v git >/dev/null 2>&1 || die "git is required. Install git and re-run."
  if [[ -d "$KUJTO_HOME/.git" ]]; then
    banner "Updating Kujto in $KUJTO_HOME"
    git -C "$KUJTO_HOME" pull --ff-only --quiet \
      && ok "Updated" || warn "Could not fast-forward; using existing checkout"
  elif [[ -e "$KUJTO_HOME" ]]; then
    die "$KUJTO_HOME exists but is not a Kujto git checkout. Move it aside or set KUJTO_HOME."
  else
    banner "Cloning Kujto into $KUJTO_HOME"
    git clone --depth 1 --quiet "$REPO_URL" "$KUJTO_HOME" || die "Clone failed from $REPO_URL"
    ok "Cloned"
  fi
  KUJTO_ROOT="$KUJTO_HOME"
}

resolve_root
AGENTS_FILE="$KUJTO_ROOT/AGENTS.md"
[[ -f "$AGENTS_FILE" ]] || die "AGENTS.md not found at $AGENTS_FILE"

banner "Linking AGENTS.md for the agents you have"

linked_any=0
link_into() {
  local dir="$1" name="$2"
  if [[ ! -d "$dir" ]]; then
    skip "$(basename "$dir") not present, skipping $name"
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
  linked_any=1
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
  linked_any=1
fi

[[ "$linked_any" -eq 1 ]] || warn "No agents detected (Claude, Codex, Gemini). Linked nothing but ~/AGENTS.md is the fallback."

banner "Making repo scripts executable"
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

Kujto is installed at: $KUJTO_ROOT

Next steps:
  1. Boot an iOS app:        cd your-ios-project && "$KUJTO_ROOT/simulator.sh"
  2. Wire memory to a repo:  cd your-repo && "$KUJTO_ROOT/bin/sync/wire.sh"
  3. Read the docs:          open "$KUJTO_ROOT/docs/getting-started.md"

Your agents (Claude, Codex, Gemini) now read Kujto's AGENTS.md globally.
NEXT
