#!/usr/bin/env bash
# Kujto skills installer
#
# Installs Kujto skills from the single source in skills/ into each agent that
# is present, by symlink, so there is one source of truth. Skills are the
# procedure (how); the knowledge (what) stays in memory/.
#
# - Claude Code -> ~/.claude/skills/kujto-<name>      symlink to skills/<name>/
# - OpenAI Codex-> ~/.codex/prompts/kujto-<name>.md   symlink to skills/<name>/SKILL.md
#
# Each SKILL.md reads from the same memory base that AGENTS.md loads.
#
# Install skills nga burimi i vetem ne skills/ per çdo agjent te pranishem, me
# symlink, qe te kete nje burim te vetem te se vertetes. Skills jane procedura
# (si); njohuria (çfarë) rri ne memory/.
#
# Usage / Perdorimi:
#   ~/kujto/bin/skills/install-skills.sh             # install into present agents
#   ~/kujto/bin/skills/install-skills.sh --uninstall # remove Kujto skill symlinks
#   ~/kujto/bin/skills/install-skills.sh --list      # list source skills

set -euo pipefail

KUJTO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILLS_SRC="$KUJTO_ROOT/skills"

CLAUDE_DIR="$HOME/.claude/skills"
CODEX_DIR="$HOME/.codex/prompts"
PREFIX="kujto-"

banner() { printf "\n\033[36m▌ Kujto skills\033[0m  %s\n" "$*"; }
ok() { printf "  \033[32m✓\033[0m %s\n" "$*"; }
skip() { printf "  \033[90m·\033[0m %s\n" "$*"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$*"; }

UNINSTALL=0
LIST=0
while (( "$#" )); do
  case "$1" in
    --uninstall) UNINSTALL=1; shift ;;
    --list) LIST=1; shift ;;
    -h|--help)
      sed -n '15,18p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
done

if [[ ! -d "$SKILLS_SRC" ]]; then
  echo "skills/ not found at $SKILLS_SRC"
  exit 1
fi

# Collect skill names (directories under skills/ that hold a SKILL.md).
skills=()
for dir in "$SKILLS_SRC"/*/; do
  [[ -f "$dir/SKILL.md" ]] || continue
  skills+=("$(basename "$dir")")
done

if (( ${#skills[@]} == 0 )); then
  echo "No skills with SKILL.md found under $SKILLS_SRC"
  exit 1
fi

if [[ "$LIST" -eq 1 ]]; then
  banner "Source skills"
  for name in "${skills[@]}"; do
    ok "$name -> skills/$name/SKILL.md"
  done
  exit 0
fi

# Replace a symlink, back up a real file, then link src -> dst.
link_into() {
  local src="$1" dst="$2"
  if [[ -L "$dst" ]]; then
    rm "$dst"
  elif [[ -e "$dst" ]]; then
    mv "$dst" "$dst.bak.$(date +%s)"
    warn "Backed up existing $dst"
  fi
  ln -s "$src" "$dst"
  ok "$dst"
}

remove_link() {
  local dst="$1"
  if [[ -L "$dst" ]]; then
    rm "$dst"
    ok "Removed $dst"
  else
    skip "$dst not a Kujto symlink, skipped"
  fi
}

if [[ "$UNINSTALL" -eq 1 ]]; then
  banner "Removing Kujto skills"
  for name in "${skills[@]}"; do
    remove_link "$CLAUDE_DIR/$PREFIX$name"
    remove_link "$CODEX_DIR/$PREFIX$name.md"
  done
  banner "Done"
  exit 0
fi

# Claude Code: symlink the whole skill directory.
if [[ -d "$HOME/.claude" ]]; then
  banner "Claude Code skills"
  mkdir -p "$CLAUDE_DIR"
  for name in "${skills[@]}"; do
    link_into "$SKILLS_SRC/$name" "$CLAUDE_DIR/$PREFIX$name"
  done
else
  skip "\$HOME/.claude not present, skipping Claude skills"
fi

# Codex CLI: symlink SKILL.md as a slash-command prompt (/kujto-<name>).
if [[ -d "$HOME/.codex" ]]; then
  banner "Codex CLI prompts"
  mkdir -p "$CODEX_DIR"
  for name in "${skills[@]}"; do
    link_into "$SKILLS_SRC/$name/SKILL.md" "$CODEX_DIR/$PREFIX$name.md"
  done
else
  skip "\$HOME/.codex not present, skipping Codex prompts"
fi

banner "Done"
cat <<NEXT

Installed skills: ${skills[*]}

Use in Claude Code: the skill triggers by its description, or name it directly.
Use in Codex CLI:   type /${PREFIX}${skills[0]} to invoke it.

Skills te instaluara: ${skills[*]}

Perdor ne Claude Code: skill-i aktivizohet nga pershkrimi, ose emertoje direkt.
Perdor ne Codex CLI:   shkruaj /${PREFIX}${skills[0]} per ta thirrur.

NEXT
