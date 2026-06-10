#!/usr/bin/env bash

SESSION="${XDG_SESSION_TYPE}"
DESKTOP="${XDG_CURRENT_DESKTOP}"

# Log environment for debugging
echo "SESSION=$SESSION DESKTOP=$DESKTOP WID=$WID" >> /tmp/pin-debug.log

x11() {
  sleep 0.2
  WID=$(xdotool getactivewindow)
  STATE=$(xprop -id "$WID" _NET_WM_STATE 2>/dev/null)
  echo "WID=$WID STATE=$STATE" >> /tmp/pin-debug.log

  if echo "$STATE" | grep -q "_NET_WM_STATE_ABOVE"; then
    wmctrl -i -r "$WID" -b remove,above
  else
    wmctrl -i -r "$WID" -b add,above
  fi
}

wayland_gnome() {
  gdbus call --session \
    --dest org.gnome.Shell \
    --object-path /org/gnome/Shell \
    --method org.gnome.Shell.Eval \
    "let w = global.display.focus_window; w.above ? w.unmake_above() : w.make_above();" \
    2>/dev/null
}

# Hardcode x11 path for now to test
x11
