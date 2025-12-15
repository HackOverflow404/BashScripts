#!/usr/bin/env bash
set -euo pipefail

SINK="HAL9000"
DESC="HAL-9000"

# Find your AudioRelay binary path (edit if needed)
AUDIOR_BIN="/opt/audiorelay/bin/AudioRelay"

if [ ! -x "$AUDIOR_BIN" ]; then
  echo "AudioRelay binary not found. Edit AUDIOR_BIN in this script."
  exit 1
fi

# Save current default sink so we can restore it
OLD_DEFAULT="$(pactl info | awk -F': ' '/Default Sink:/{print $2}')"

created_module_id=""

cleanup() {
  # Restore previous default sink (best effort)
  if [ -n "${OLD_DEFAULT:-}" ]; then
    pactl set-default-sink "$OLD_DEFAULT" >/dev/null 2>&1 || true
  fi

  # Unload only if we created it
  if [ -n "${created_module_id:-}" ]; then
    pactl unload-module "$created_module_id" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

# Create null sink only if missing; remember module id if we created it
if ! pactl list short sinks | awk '{print $2}' | grep -qx "$SINK"; then
  created_module_id="$(pactl load-module module-null-sink \
    sink_name="$SINK" \
    sink_properties=device.description="$DESC")"
fi

# Make it default while AudioRelay is open (optional, but usually what you want)
pactl set-default-sink "$SINK"

# Launch GUI AudioRelay and wait until you close it
"$AUDIOR_BIN"
