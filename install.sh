#!/usr/bin/env bash
# Install the skills for one agent.
#
#   ./install.sh                     # Claude Code: symlinks skills/* into ~/.claude/skills
#   ./install.sh --agent codex       # Codex: writes a Codex-worded copy into ~/.agents/skills
#   ./install.sh --agent cursor      # Cursor: writes a Cursor-worded copy into ~/.cursor/skills
#   ./install.sh --agent all         # all three
#   ./install.sh --vault             # also scaffold $BRAIN_VAULT/_System from vault/ if missing
#
# Claude Code gets symlinks, so an edit in ~/.claude/skills is an edit in this repo.
# Codex and Cursor get generated copies: the text swaps "Claude Code" for the agent
# name and CLAUDE.md for AGENTS.md. Vault paths such as _Claude/sessions/ stay the
# same on purpose, so every agent reads and writes one shared memory. Re-run after
# editing a skill to refresh the copies.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="${BRAIN_VAULT:-$HOME/Brain}"
AGENT="claude"
DO_VAULT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENT="$2"; shift 2 ;;
    --vault) DO_VAULT=1; shift ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

link_claude() {
  local dir="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
  mkdir -p "$dir"
  for src in "$HERE"/skills/*/; do
    local name dest
    name="$(basename "$src")"
    dest="$dir/$name"
    if [[ -L "$dest" ]]; then
      ln -sfn "${src%/}" "$dest"; echo "updated  $dest"
    elif [[ -e "$dest" ]]; then
      echo "skipped  $dest (exists and is not a symlink; move it aside and re-run)"
    else
      ln -s "${src%/}" "$dest"; echo "linked   $dest"
    fi
  done
}

# generate <agent label> <target dir>
generate() {
  local label="$1" dir="$2"
  mkdir -p "$dir"
  for src in "$HERE"/skills/*/; do
    local name dest
    name="$(basename "$src")"
    dest="$dir/$name"
    if [[ -L "$dest" ]]; then
      echo "skipped  $dest (is a symlink; remove it to install a generated copy)"
      continue
    fi
    mkdir -p "$dest"
    perl -pe "
      s/Claude Code/$label/g;
      s/CLAUDE\\.md/AGENTS.md/g;
      s#~/\\.claude/skills#$dir#g;
    " "$src/SKILL.md" > "$dest/SKILL.md"
    echo "wrote    $dest/SKILL.md"
  done
}

case "$AGENT" in
  claude) link_claude ;;
  codex)  generate "Codex"  "${CODEX_SKILLS_DIR:-$HOME/.agents/skills}" ;;
  cursor) generate "Cursor" "${CURSOR_SKILLS_DIR:-$HOME/.cursor/skills}" ;;
  all)    link_claude
          generate "Codex"  "${CODEX_SKILLS_DIR:-$HOME/.agents/skills}"
          generate "Cursor" "${CURSOR_SKILLS_DIR:-$HOME/.cursor/skills}" ;;
  *) echo "unknown agent: $AGENT (claude | codex | cursor | all)" >&2; exit 2 ;;
esac

if [[ $DO_VAULT -eq 1 ]]; then
  if [[ -e "$VAULT/_System" ]]; then
    echo "skipped  $VAULT/_System (exists)"
  else
    mkdir -p "$VAULT/_Inbox" "$VAULT/_Claude/sessions" "$VAULT/Daily" "$VAULT/Archive"
    cp -R "$HERE/vault/_System" "$VAULT/_System"
    cp "$VAULT/_System/workspaces.example.yaml" "$VAULT/_System/workspaces.yaml"
    printf '# Vault index\n\nOne line per page. Skills append here.\n' > "$VAULT/_System/index.md"
    mkdir -p "$VAULT/_System/logs"
    echo "created  $VAULT/_System — edit workspaces.yaml next"
  fi
fi
