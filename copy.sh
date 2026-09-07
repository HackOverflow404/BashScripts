#!/usr/bin/env bash
# Capture command output, files, or stdin to the Wayland clipboard.
set -uo pipefail
usage() {
  cat <<'EOF'
Usage: copy [-o] command [args...]
       copy [-o] -c 'shell pipeline'
       copy -f FILE
       command | copy
       copy --help
Copies combined stdout/stderr; -o omits the command header.
-c uses $SHELL with pipefail (no interactive aliases). Use -- before a command
whose name starts with a dash. -f - reads stdin. Command exit codes are retained.
EOF
}
fail() { printf 'copy: %s\n' "$*" >&2; exit 2; }
mode=command; header=1; value=''
while (($#)); do
  case $1 in
    -h|--help) usage; exit 0 ;;
    -o) header=0; shift ;;
    -f|-c)
      [[ $mode == command && $# -ge 2 ]] || fail 'use exactly one -f FILE or -c PIPELINE'
      [[ $1 == -f ]] && mode=file || mode=shell
      value=$2; shift 2 ;;
    --) shift; break ;;
    -*) fail "unknown option: $1" ;;
    *) break ;;
  esac
done
[[ $mode == command || $# == 0 ]] || fail 'unexpected arguments after -f/-c'
if [[ $mode == command && $# == 0 ]]; then
  [[ ! -t 0 ]] || { usage >&2; exit 2; }
  mode=stdin
fi
command -v wl-copy >/dev/null || fail 'wl-copy is required (omarchy pkg add wl-clipboard)'
[[ -n ${WAYLAND_DISPLAY:-} ]] || fail 'no Wayland session available'
if [[ $mode == file ]]; then
  [[ $value != - ]] || mode=stdin
  if [[ $mode == file ]]; then
    [[ -f $value && -r $value ]] || fail "cannot read regular file: $value"
    exec wl-copy <"$value"
  fi
fi
[[ $mode != stdin ]] || exec wl-copy
umask 077
tmp=$(mktemp) || exit 1
trap 'rm -f -- "$tmp"' EXIT
trap 'exit 143' TERM
interrupted=0
trap 'interrupted=1' INT
if ((header)); then
  if [[ $mode == shell ]]; then printf '$ %s\n' "$value" >"$tmp"
  else
    { printf '$'; printf ' %q' "$@"; printf '\n'; } >"$tmp"
  fi
fi
if [[ $mode == shell ]]; then
  shell=${SHELL:-/bin/bash}
  case ${shell##*/} in bash|zsh) ;; *) fail '-c requires bash or zsh in SHELL' ;; esac
  "$shell" -o pipefail -c "$value" 2>&1 | tee -a -- "$tmp"
else
  "$@" 2>&1 | tee -a -- "$tmp"
fi
statuses=("${PIPESTATUS[@]}")
rc=${statuses[0]}
((rc != 0)) || rc=${statuses[1]}
if ! wl-copy <"$tmp"; then
  printf 'copy: clipboard write failed\n' >&2
  ((rc != 0)) || rc=1
fi
((interrupted == 0)) || rc=130
exit "$rc"
