#!/bin/bash
# Watches a UE5 project log for PIE start/end, toggles NVIDIA ShadowPlay
# (Alt+F9) via PowerShell SendKeys, and moves the resulting mp4 from
# ShadowPlay's output folder into a timestamped destination.
#
# Configuration (all optional — falls back to auto-detect or sane defaults):
#   TOG_PIE_LOG         absolute path to a UE project's Saved/Logs/<Name>.log
#   TOG_SHADOWPLAY_DIR  where ShadowPlay drops its mp4s
#   TOG_OUTPUT_DIR      where this script moves finalized clips

set -uo pipefail

# --- Resolve configuration --------------------------------------------------

LOG="${TOG_PIE_LOG:-}"
SHADOWPLAY_DIR="${TOG_SHADOWPLAY_DIR:-}"
OUTDIR="${TOG_OUTPUT_DIR:-}"

# Auto-detect UE project log: most-recently-modified */Saved/Logs/*.log
# excluding rotated backups, on any local drive.
if [ -z "$LOG" ]; then
  CANDIDATES=()
  for ROOT in /c /d /e /f; do
    [ -d "$ROOT" ] || continue
    while IFS= read -r f; do CANDIDATES+=("$f"); done < <(
      find "$ROOT" -maxdepth 6 -path "*/Saved/Logs/*.log" \
        -not -iname "*backup*" -not -iname "cef3*" \
        -type f 2>/dev/null
    )
  done
  if [ "${#CANDIDATES[@]}" -gt 0 ]; then
    LOG=$(printf '%s\n' "${CANDIDATES[@]}" \
      | xargs -d '\n' stat -c '%Y %n' 2>/dev/null \
      | sort -rn | head -1 | cut -d' ' -f2-)
  fi
fi

# Default ShadowPlay output: $HOME/Videos/Unreal Engine 5 (matches its UE5 game profile)
if [ -z "$SHADOWPLAY_DIR" ]; then
  SHADOWPLAY_DIR="$HOME/Videos/Unreal Engine 5"
fi

# Default output: $HOME/TOG_Recordings
if [ -z "$OUTDIR" ]; then
  OUTDIR="$HOME/TOG_Recordings"
fi

# --- Validate ---------------------------------------------------------------

if [ -z "$LOG" ] || [ ! -f "$LOG" ]; then
  echo "ERROR: could not locate UE project log."
  echo "Set TOG_PIE_LOG to an absolute path, e.g.:"
  echo "  export TOG_PIE_LOG=/d/MyProject/Saved/Logs/MyProject.log"
  exit 1
fi

if [ ! -d "$SHADOWPLAY_DIR" ]; then
  echo "ERROR: ShadowPlay output folder not found: $SHADOWPLAY_DIR"
  echo "Set TOG_SHADOWPLAY_DIR or check NVIDIA App → Settings → Video → Recording location."
  exit 1
fi

mkdir -p "$OUTDIR"
STATEFILE="$(mktemp -u)"
rm -f "$STATEFILE"

echo "$(date +%H:%M:%S) ShadowPlay watcher armed"
echo "  log:         $LOG"
echo "  ShadowPlay:  $SHADOWPLAY_DIR"
echo "  output:      $OUTDIR"
echo "  toggle:      Alt+F9 (must be the ShadowPlay record hotkey)"

send_alt_f9() {
  powershell -NoProfile -Command \
    "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('%{F9}')" \
    2>/dev/null
}

snapshot_files() {
  find "$SHADOWPLAY_DIR" -maxdepth 1 -name "*.mp4" -type f 2>/dev/null | sort
}

# --- Main loop --------------------------------------------------------------

while IFS= read -r line; do
  case "$line" in
    *"Creating play world package"*)
      if [ ! -f "$STATEFILE" ]; then
        TS=$(date +%Y-%m-%d_%H%M%S)
        snapshot_files > "${STATEFILE}.pre"
        send_alt_f9
        echo "$TS" > "$STATEFILE"
        echo "$(date +%H:%M:%S) PIE START → sent Alt+F9 (ShadowPlay toggle ON)"
      fi
      ;;
    *"Shutting down PIE online subsystems"*)
      if [ -f "$STATEFILE" ]; then
        send_alt_f9
        echo "$(date +%H:%M:%S) PIE END → sent Alt+F9 (ShadowPlay toggle OFF)"
        TS=$(cat "$STATEFILE")
        rm -f "$STATEFILE"
        sleep 4  # let ShadowPlay finalize the mp4
        snapshot_files > "${STATEFILE}.post"
        NEWFILE=$(comm -13 "${STATEFILE}.pre" "${STATEFILE}.post" | head -1)
        rm -f "${STATEFILE}.pre" "${STATEFILE}.post"
        if [ -n "$NEWFILE" ]; then
          DEST="$OUTDIR/recording_${TS}.mp4"
          mv "$NEWFILE" "$DEST"
          SIZE=$(stat -c%s "$DEST" 2>/dev/null || echo "?")
          echo "$(date +%H:%M:%S) Moved → $DEST (${SIZE} bytes)"
        else
          echo "$(date +%H:%M:%S) WARN: no new mp4 in $SHADOWPLAY_DIR — ShadowPlay may not have started. Check overlay + hotkey settings."
        fi
      fi
      ;;
  esac
done < <(tail -n 0 -F "$LOG" 2>/dev/null)
