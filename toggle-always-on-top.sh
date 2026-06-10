#!/usr/bin/env bash

pin_x11() {
  local wid state
  wid=$(xdotool getactivewindow) || return 1
  state=$(xprop -id "$wid" _NET_WM_STATE 2>/dev/null)

  if echo "$state" | grep -q "_NET_WM_STATE_ABOVE"; then
    wmctrl -i -r "$wid" -b remove,above
  else
    wmctrl -i -r "$wid" -b add,above
  fi
}

pin_wayland_gnome() {
  gdbus call --session \
    --dest org.gnome.Shell \
    --object-path /org/gnome/Shell \
    --method org.gnome.Shell.Eval \
    "let w = global.display.focus_window; w.above ? w.unmake_above() : w.make_above();" \
    2>/dev/null
}

main() {
  case "${XDG_SESSION_TYPE}" in
    wayland) pin_wayland_gnome ;;
    *)       pin_x11 ;;
  esac
}

main
