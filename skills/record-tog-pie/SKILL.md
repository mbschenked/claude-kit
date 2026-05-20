---
name: record-tog-pie
description: Automate UE5 PIE gameplay capture for portfolio clips. Watches the project log, toggles NVIDIA ShadowPlay on Play/Stop, moves recordings to an output folder, and walks the user through cut + compress. Trigger when the user wants to record Unreal Engine 5 gameplay (especially TOG) for portfolio clips, set up automated PIE recording, or capture combat footage for review.
---

# /record-tog-pie — Automated UE5 PIE → ShadowPlay → Portfolio Clip Workflow

When invoked, set up an automated pipeline that records gameplay only while the user is in Play-In-Editor mode, drops timestamped mp4s into a known folder, and helps the user iterate on short, portfolio-ready clips.

## What this skill assumes

- **OS:** Windows (uses PowerShell + ShadowPlay + UE5 editor log format)
- **NVIDIA App / ShadowPlay** installed with:
  - In-game overlay enabled
  - Manual record hotkey set to **Alt+F9** (the default)
  - A configured "Videos" output folder for the UE editor (default: `%USERPROFILE%\Videos\Unreal Engine 5`)
- **ffmpeg** on PATH (for cuts/compression)
- A UE5 project whose `Saved/Logs/*.log` is being written to (auto-detected if env var unset)

If any of these is missing, stop and tell the user what to set up before proceeding.

## 1. Resolve configuration

Read environment variables; fall back to auto-detection. State the resolved values to the user before arming so they can override.

| Variable | Purpose | Fallback |
|---|---|---|
| `TOG_PIE_LOG` | Absolute path to the UE project's `Saved/Logs/<Name>.log` | Most-recently-modified `*/Saved/Logs/*.log` across `/c`, `/d`, `/e`, `/f` |
| `TOG_SHADOWPLAY_DIR` | Folder where ShadowPlay writes raw mp4s | `$HOME/Videos/Unreal Engine 5` |
| `TOG_OUTPUT_DIR` | Where finalized clips land | `$HOME/TOG_Recordings` |

Surface the chosen paths in plain text: "Watching X · ShadowPlay drops to Y · clips will move to Z." If any look wrong, ask before arming.

## 2. Arm the watcher

Launch the bundled watcher script in the background:

```bash
bash "$SKILL_DIR/pie_watcher.sh"
```

where `$SKILL_DIR` is this skill's folder. Use `run_in_background: true` so the script keeps tailing the log while the user works.

Then arm a Monitor on the watcher's output file with this filter:

```bash
tail -n 0 -F <watcher-output-file> | grep -E --line-buffered "PIE START|PIE END|Moved|WARN|ERROR"
```

Set `persistent: true` — the user may record many sessions before stopping.

## 3. The capture loop

For each Monitor event, respond in one short line. Don't narrate beyond that — the user is playing the game and just wants to know the system is working.

- **`PIE START`** → "Recording — PIE START at HH:MM:SS."
- **`PIE END`** → "PIE end at HH:MM:SS — waiting for the move (~4s)."
- **`Moved → ...`** → announce the file and size, then open it for review with `start "" "<path>"` so the user can scrub through.
- **`WARN`** → no new mp4 was found; tell the user ShadowPlay didn't capture. Common causes: in-game overlay off, hotkey not Alt+F9, ShadowPlay was already manually recording. Don't retry on their behalf — they need to fix the config.

## 4. Cut + compress clips

When the user identifies timestamps in a recording, cut + compress to portfolio defaults:

```bash
ffmpeg -hide_banner -loglevel error \
  -i SRC -ss <start_seconds> -t <duration_seconds> \
  -vf "scale=1920:1080:flags=lanczos,fps=30" \
  -c:v libx264 -preset slow -crf 26 -an -movflags +faststart \
  OUT.mp4
```

Defaults:
- **Duration:** 8 seconds (6s windows have truncated combat exchanges in practice)
- **Resolution:** 1080p (downscaled from 4K ShadowPlay source)
- **Framerate:** 30 (downsampled from 60 — halves file size, fine for web)
- **Audio:** dropped (`-an`) — portfolio clips don't carry audio
- **Container flags:** `+faststart` for fast web playback

Filenames should be hyphenated combat moves, e.g. `Dodged-Parried-Parried.mp4`, `BossHit-SwordRipped.mp4`. Version suffixes `-V2`, `-V3`, etc. when iterating on the same exchange.

The user may want to batch timestamps before cutting. If they say "just note this for now," write a `_pending_cuts.txt` file in the output folder with `<timestamp> | <name>` lines and add to it as they call out more.

## 5. Cleanup

- After cuts are confirmed acceptable, delete the source recording (only on explicit user OK — sources are large and getting them back means re-recording).
- Keep the watcher armed across multiple takes — the user usually wants several recordings in a row.
- On session end, stop the watcher task and the monitor task explicitly with `TaskStop`.

## Why this exists

UE5's PIE log writes two definitive lines that bracket every play session:
- **Start:** `LogPlayLevel: Creating play world package: /Game/...`
- **End:** `LogPlayLevel: Display: Shutting down PIE online subsystems`

Tailing the log and toggling ShadowPlay's hotkey on those signals gets us automatic, accurate clip capture without screen-recording the entire editor session or relying on user discipline to start/stop manually. The user just hits Play and plays.

## Known caveats

- **ShadowPlay must use Alt+F9.** If the user's overlay binds Alt+F9 to something else, the watcher will trigger the wrong action. Confirm in NVIDIA App → Settings → Keyboard shortcuts before first use.
- **In-game overlay must be ON** for hotkey injection to register.
- **If ShadowPlay is already recording** (Instant Replay or manual session) when the watcher fires, the first Alt+F9 will *stop* that recording rather than start a new one. Tell the user not to manually-record around this skill.
- **`LogWorld: BeginTearingDown`** also fires on level transitions inside PIE — do not use it as the session-end signal. Stick with `Shutting down PIE online subsystems`.
- **ffmpeg's NVENC** may fail on older NVIDIA drivers; this skill uses libx264 (software) which is robust but slower. ShadowPlay capture is unaffected because it uses its own NVENC binding.
