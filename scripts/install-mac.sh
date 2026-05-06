#!/usr/bin/env bash
# install-mac.sh — copy this kit's agents into ~/.claude/agents/
# Idempotent: safe to re-run after a `git pull`.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.claude/agents"

mkdir -p "$DEST"

count=0
for src in "$REPO_DIR"/agents/*.md; do
  [ -f "$src" ] || continue
  name="$(basename "$src")"
  cp "$src" "$DEST/$name"
  echo "  installed $name"
  count=$((count + 1))
done

echo
echo "Installed $count agent(s) to $DEST"
echo "Restart Claude Code if it was already running."
