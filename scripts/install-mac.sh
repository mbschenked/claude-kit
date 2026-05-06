#!/usr/bin/env bash
# install-mac.sh — copy this kit's agents into ~/.claude/agents/
# Idempotent: safe to re-run after a `git pull`.
#
# Usage: bash install-mac.sh [--prune]
#   --prune  remove .md files in ~/.claude/agents/ that aren't in this repo

set -euo pipefail

PRUNE=0
for arg in "$@"; do
  case "$arg" in
    --prune) PRUNE=1 ;;
    -h|--help)
      sed -n '2,7p' "$0"
      exit 0
      ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

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

pruned=0
if [ "$PRUNE" = "1" ]; then
  for dst in "$DEST"/*.md; do
    [ -f "$dst" ] || continue
    name="$(basename "$dst")"
    if [ ! -f "$REPO_DIR/agents/$name" ]; then
      rm "$dst"
      echo "  pruned $name"
      pruned=$((pruned + 1))
    fi
  done
fi

echo
echo "Installed $count agent(s) to $DEST"
if [ "$PRUNE" = "1" ]; then
  echo "Pruned $pruned stale agent(s)"
fi
echo "Restart Claude Code if it was already running."
