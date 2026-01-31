#!/usr/bin/env bash
set -euo pipefail

SINK="HAL9000"
DESC="HAL-9000"

AUDIOR_BIN="/opt/audiorelay/bin/AudioRelay"
if [ ! -x "$AUDIOR_BIN" ]; then
  echo "AudioRelay binary not found. Edit AUDIOR_BIN in this script."
  exit 1
fi

# ---- Raspberry Pi SSH settings ----
PI_HOST="tps-l2.local"
PI_USER="user"
PI_KEY="${HOME}/.ssh/hal_speaker_pi"
PI_SSH_OPTS=(
  -i "$PI_KEY"
  -o BatchMode=yes
  -o ConnectTimeout=3
  -o StrictHostKeyChecking=yes
  -o IdentitiesOnly=yes
)

CMD_START_APP='adb shell am start -n com.azefsw.audioconnect/com.azefsw.audioconnect.root.ui.RootActivity'
CMD_STANDBY_APP='adb shell am start -n br.com.zetabit.ios_standby/br.com.zetabit.ios_standby.MainActivity'

remote_run() {
  local cmd="$1"
  # Best-effort; never let Pi connectivity issues kill cleanup or the main flow
  ssh "${PI_SSH_OPTS[@]}" "${PI_USER}@${PI_HOST}" "$cmd" >/dev/null 2>&1 || true
}

# Save current default sink so we can restore it
OLD_DEFAULT="$(pactl info | awk -F': ' '/Default Sink:/{print $2}')"
created_module_id=""

cleanup() {
  # Signal Pi to switch to standby (best effort)
  remote_run "$CMD_STANDBY_APP"

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

# Signal Pi to open AudioConnect (best effort)
remote_run "$CMD_START_APP"

# Create null sink only if missing; remember module id if we created it
if ! pactl list short sinks | awk '{print $2}' | grep -qx "$SINK"; then
  created_module_id="$(pactl load-module module-null-sink \
    sink_name="$SINK" \
    sink_properties=device.description="$DESC")"
fi

# Make it default while AudioRelay is open
pactl set-default-sink "$SINK"

# Launch GUI AudioRelay and wait until you close it
"$AUDIOR_BIN"
