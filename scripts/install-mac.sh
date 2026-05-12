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

install_skills() {
  local subdir="skills"
  local dest="$HOME/.claude/$subdir"
  local src_dir="$REPO_DIR/$subdir"

  [ -d "$src_dir" ] || return 0
  mkdir -p "$dest"

  local count=0
  for src in "$src_dir"/*/; do
    [ -d "$src" ] || continue
    name="$(basename "$src")"
    rm -rf "$dest/$name"
    cp -R "$src" "$dest/$name"
    echo "  installed skills/$name"
    count=$((count + 1))
  done

  local pruned=0
  if [ "$PRUNE" = "1" ]; then
    for dst in "$dest"/*/; do
      [ -d "$dst" ] || continue
      name="$(basename "$dst")"
      if [ ! -d "$src_dir/$name" ]; then
        rm -rf "$dst"
        echo "  pruned skills/$name"
        pruned=$((pruned + 1))
      fi
    done
  fi

  echo "Installed $count skill(s) to $dest"
  if [ "$PRUNE" = "1" ]; then
    echo "Pruned $pruned stale skill(s)"
  fi
}

install_statusline() {
  local src="$REPO_DIR/scripts/statusline-command.sh"
  local dest="$HOME/.claude/statusline-command.sh"

  [ -f "$src" ] || return 0
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  chmod +x "$dest"
  echo "  installed statusline-command.sh"
  echo "Installed statusline-command.sh to $dest"
}

install_hooks() {
  local dest_dir="$HOME/.claude/scripts"
  local src_dir="$REPO_DIR/scripts"
  mkdir -p "$dest_dir"

  local count=0
  for src in "$src_dir"/log-activity.sh "$src_dir"/reap-stale-activity.sh; do
    [ -f "$src" ] || continue
    name="$(basename "$src")"
    cp "$src" "$dest_dir/$name"
    chmod +x "$dest_dir/$name"
    echo "  installed scripts/$name"
    count=$((count + 1))
  done

  echo "Installed $count hook script(s) to $dest_dir"
}

install_dir agents
echo
install_dir commands
echo
install_skills
echo
install_statusline
echo
install_hooks

echo
echo "Restart Claude Code if it was already running."
