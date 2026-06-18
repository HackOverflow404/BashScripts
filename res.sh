#!/bin/bash
# Opens the Resume project in Zed (left half) + Resume.pdf in Evince (right half),
# with both windows snapped and sidebars closed.

RESUME_DIR="/home/hackoverflow/Documents/Projects/Resume"
PDF_PATH="$RESUME_DIR/Resume.pdf"

# Evince persists sidebar state; force it off so the new window opens clean.
gsettings set org.gnome.Evince.Default show-sidebar false

# Snapshot window IDs that already exist so we can detect the new ones.
EXISTING_ZED=$(xdotool search --class "zed" 2>/dev/null || true)
EXISTING_EVINCE=$(xdotool search --class "evince" 2>/dev/null || true)

wait_for_new_window() {
    local class="$1"
    local existing="$2"
    local tries=40
    while [ "$tries" -gt 0 ]; do
        for wid in $(xdotool search --class "$class" 2>/dev/null || true); do
            echo "$existing" | grep -qw "$wid" || { echo "$wid"; return 0; }
        done
        sleep 0.5
        tries=$((tries - 1))
    done
    return 1
}

# ── Zed ──────────────────────────────────────────────────────────────────────
zed "$RESUME_DIR" &

ZED_WID=$(wait_for_new_window "zed" "$EXISTING_ZED")
if [ -z "$ZED_WID" ]; then
    echo "resume-workspace: timed out waiting for Zed window" >&2
    exit 1
fi

sleep 1.5  # Let Zed finish rendering its panels before we interact

xdotool windowactivate --sync "$ZED_WID"
sleep 0.3
xdotool key --clearmodifiers super+Left   # GNOME snap to left half
sleep 0.4
xdotool key --clearmodifiers ctrl+b       # workspace::ToggleLeftDock → close sidebar

# ── Evince ───────────────────────────────────────────────────────────────────
evince "$PDF_PATH" &

EVINCE_WID=$(wait_for_new_window "evince" "$EXISTING_EVINCE")
if [ -z "$EVINCE_WID" ]; then
    echo "resume-workspace: timed out waiting for Evince window" >&2
    exit 1
fi

sleep 0.8  # Evince loads faster than Zed

xdotool windowactivate --sync "$EVINCE_WID"
sleep 0.3
xdotool key --clearmodifiers super+Right  # GNOME snap to right half
