#!/usr/bin/env bash
# Symlink the skills into ~/.claude/skills. With --vault, also scaffold the
# vault's _System folder from vault/ when it does not exist yet.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
VAULT="${BRAIN_VAULT:-$HOME/Brain}"

mkdir -p "$SKILLS_DIR"
for src in "$HERE"/skills/*/; do
  name="$(basename "$src")"
  dest="$SKILLS_DIR/$name"
  if [[ -L "$dest" ]]; then
    ln -sfn "$src" "$dest"
    echo "updated  $dest"
  elif [[ -e "$dest" ]]; then
    echo "skipped  $dest (exists and is not a symlink)"
  else
    ln -s "$src" "$dest"
    echo "linked   $dest"
  fi
done

if [[ "${1:-}" == "--vault" ]]; then
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
