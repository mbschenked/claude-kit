# statusline-ctx — the `ctx: NN%` Claude Code status line

A tiny, self-contained status line that shows how much of the context window you've used, color-coded so you can see context pressure at a glance:

```
~/ClaudeCode/ProjectOptimizer | Opus 4.8 | ctx: 42%
```

- **`ctx: NN%`** — percent of the context window used this session.
- **Color:** 🟢 green `<33%` · 🟡 yellow `33–60%` · 🔴 red `>60%`.

It also shows the current directory (with `$HOME` collapsed to `~`) and the model name.

This is the portable, dependency-light version — just the one status line, no hooks or background state. (The fuller status line in this kit, `scripts/statusline-command.sh`, adds a live activity board on lines 2+ but depends on the activity-logging hooks. Use that one if you want the board; use this one if you just want `ctx: NN%` anywhere, fast.)

## Install

### macOS / Linux

```bash
bash install.sh
```

Requires `jq` (`brew install jq` or `apt install jq`). The installer copies `statusline-ctx.sh` to `~/.claude/` and wires it into `~/.claude/settings.json` (backing the file up to `settings.json.bak` first). Restart Claude Code.

### Windows

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
```

No external dependencies (uses built-in JSON parsing). Copies `statusline-ctx.ps1` to `%USERPROFILE%\.claude\` and wires it into `settings.json` (backup at `settings.json.bak`). Restart Claude Code.

## Manual install

If you'd rather wire it yourself, copy the script for your platform into `~/.claude/`, then add a `statusLine` block to `~/.claude/settings.json`:

**macOS / Linux**
```json
{
  "statusLine": { "type": "command", "command": "bash ~/.claude/statusline-ctx.sh" }
}
```

**Windows**
```json
{
  "statusLine": { "type": "command", "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\statusline-ctx.ps1" }
}
```

## How it works

Claude Code pipes a JSON status payload to the command on stdin each render. The script reads three fields and prints one line:

| Field | Used for |
|---|---|
| `workspace.current_dir` (or `cwd`) | the path segment |
| `model.display_name` | the model name |
| `context_window.used_percentage` | the `ctx: NN%` segment + its color |

If `used_percentage` isn't present in the payload, the `ctx` segment is simply omitted — the line never errors.

## Files

| File | Role |
|---|---|
| `statusline-ctx.sh` | macOS/Linux status line (needs `jq`). |
| `statusline-ctx.ps1` | Windows status line (no dependencies). |
| `install.sh` / `install.ps1` | Copy the script + wire `settings.json`. Idempotent; back up settings first. |
