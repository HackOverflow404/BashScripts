#!/usr/bin/env bash

pin_x11() {
  local wid state name action
  wid=$(xdotool getactivewindow) || return 1
  state=$(xprop -id "$wid" _NET_WM_STATE 2>/dev/null)
  name=$(xdotool getactivewindow getwindowname 2>/dev/null)

  if echo "$state" | grep -q "_NET_WM_STATE_ABOVE"; then
    wmctrl -i -r "$wid" -b remove,above
    action="unpinned"
  else
    wmctrl -i -r "$wid" -b add,above
    action="pinned"
  fi

  notify-send "${name} ${action}"
}

pin_wayland_gnome() {
  local name action
  name=$(gdbus call --session \
    --dest org.gnome.Shell \
    --object-path /org/gnome/Shell \
    --method org.gnome.Shell.Eval \
    "global.display.focus_window.title;" 2>/dev/null | grep -oP "(?<=')[^']*(?=')")

  action=$(gdbus call --session \
    --dest org.gnome.Shell \
    --object-path /org/gnome/Shell \
    --method org.gnome.Shell.Eval \
    "global.display.focus_window.above ? 'unpinned' : 'pinned';" 2>/dev/null | grep -oP "(?<=')[^']*(?=')")

  gdbus call --session \
    --dest org.gnome.Shell \
    --object-path /org/gnome/Shell \
    --method org.gnome.Shell.Eval \
    "let w = global.display.focus_window; w.above ? w.unmake_above() : w.make_above();" \
    2>/dev/null

  notify-send "${name} ${action}"
}

main() {
  case "${XDG_SESSION_TYPE}" in
    wayland) pin_wayland_gnome ;;
    *)       pin_x11 ;;
  esac
}

main
