#!/usr/bin/env bash
# install.sh — install the ctx% status line for Claude Code (macOS / Linux).
#
# Idempotent and safe to re-run:
#   1. copies statusline-ctx.sh to ~/.claude/statusline-ctx.sh
#   2. sets settings.json -> statusLine to call it (backs up settings.json first)
#
# Usage:  bash install.sh
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
DEST="$CLAUDE_DIR/statusline-ctx.sh"
SETTINGS="$CLAUDE_DIR/settings.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required. Install it with 'brew install jq' (macOS) or 'apt install jq' (Debian/Ubuntu)." >&2
  exit 1
fi

mkdir -p "$CLAUDE_DIR"
cp "$SRC_DIR/statusline-ctx.sh" "$DEST"
chmod +x "$DEST"
echo "  installed $DEST"

# Ensure settings.json exists and is valid JSON before we touch it
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
elif ! jq empty "$SETTINGS" >/dev/null 2>&1; then
  echo "ERROR: $SETTINGS is not valid JSON — fix or remove it, then re-run." >&2
  exit 1
fi

cp "$SETTINGS" "$SETTINGS.bak"
jq '.statusLine = {"type":"command","command":"bash ~/.claude/statusline-ctx.sh"}' \
  "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
echo "  wired statusLine into $SETTINGS (backup: $SETTINGS.bak)"

echo
echo "Done. Restart Claude Code — the status line shows:  cwd | model | ctx: NN%"
