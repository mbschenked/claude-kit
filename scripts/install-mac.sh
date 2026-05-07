#!/usr/bin/env bash
# install-mac.sh — copy this kit's agents and commands into ~/.claude/
# Idempotent: safe to re-run after a `git pull`.
#
# Usage: bash install-mac.sh [--prune]
#   --prune  remove .md files in ~/.claude/{agents,commands}/ that aren't in this repo

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

install_dir() {
  local subdir="$1"
  local dest="$HOME/.claude/$subdir"
  local src_dir="$REPO_DIR/$subdir"

  [ -d "$src_dir" ] || return 0
  mkdir -p "$dest"

  local count=0
  for src in "$src_dir"/*.md; do
    [ -f "$src" ] || continue
    name="$(basename "$src")"
    cp "$src" "$dest/$name"
    echo "  installed $subdir/$name"
    count=$((count + 1))
  done

  local pruned=0
  if [ "$PRUNE" = "1" ]; then
    for dst in "$dest"/*.md; do
      [ -f "$dst" ] || continue
      name="$(basename "$dst")"
      if [ ! -f "$src_dir/$name" ]; then
        rm "$dst"
        echo "  pruned $subdir/$name"
        pruned=$((pruned + 1))
      fi
    done
  fi

  echo "Installed $count $subdir file(s) to $dest"
  if [ "$PRUNE" = "1" ]; then
    echo "Pruned $pruned stale $subdir file(s)"
  fi
}

install_dir agents
echo
install_dir commands

echo
echo "Restart Claude Code if it was already running."
