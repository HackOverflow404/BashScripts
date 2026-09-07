#!/usr/bin/env bash
# Hyprland's native float-and-pin toggle; pinned windows follow workspaces.
set -euo pipefail
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  echo 'Usage: toggle-always-on-top (toggle float/pin on the focused window)'; exit 0
fi
(($# == 0)) || exit 2
active=$(hyprctl activewindow -j)
addr=$(jq -er '.address | select(test("^0x[0-9a-fA-F]+$"))' <<<"$active") || {
  echo 'toggle-always-on-top: no focused window' >&2; exit 1;
}
if [[ $(jq -r '.pinned' <<<"$active") == true ]]; then
  hyprctl dispatch "hl.dsp.window.pin({ window = 'address:$addr' })"
else
  if [[ $(jq -r '.floating' <<<"$active") != true ]]; then
    hyprctl dispatch "hl.dsp.window.float({ window = 'address:$addr', action = 'toggle' })"
  fi
  hyprctl dispatch "hl.dsp.window.pin({ window = 'address:$addr' })"
  hyprctl dispatch "hl.dsp.window.alter_zorder({ window = 'address:$addr', mode = 'top' })"
fi
