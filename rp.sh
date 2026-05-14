#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: rp <file>" >&2
  exit 1
fi

if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-paste &>/dev/null; then
  wl-paste --no-newline > "$1"
else
  xclip -selection clipboard -o > "$1"
fi
