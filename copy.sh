#!/usr/bin/env bash
set -euo pipefail

clip_copy() {
  if command -v wl-copy >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY-}" ]]; then
    wl-copy
  elif command -v xclip >/dev/null 2>&1 && [[ -n "${DISPLAY-}" ]]; then
    xclip -selection clipboard
  elif command -v xsel >/dev/null 2>&1 && [[ -n "${DISPLAY-}" ]]; then
    xsel --clipboard --input
  elif command -v vis-clipboard >/dev/null 2>&1; then
    vis-clipboard --copy
  else
    echo "copy: no clipboard tool found (install wl-clipboard or xclip/xsel)" >&2
    exit 2
  fi
}

usage() {
  cat <<'EOF' >&2
Usage:
  copy <cmd> [args...]              Copy "$ cmd…" + stdout+stderr
  copy -o <cmd> [args...]           Copy stdout+stderr only (no "$ cmd" header)
  copy -f <file>                    Copy file contents
  copy -c '<shell pipeline>'        Copy "$ pipeline…" + stdout+stderr
  copy -o -c '<shell pipeline>'     Copy stdout+stderr only (no header)

Notes:
  - For pipelines, use -c and quote the whole pipeline string.
EOF
  exit 2
}

mode="all"      # all | out | file
file=""
shell_cmd=""

while getopts ":of:c:" opt; do
  case "$opt" in
    o) mode="out" ;;
    f) mode="file"; file="$OPTARG" ;;
    c) shell_cmd="$OPTARG" ;;
    *) usage ;;
  esac
done
shift $((OPTIND-1))

tmp="$(mktemp)"
cleanup() { rm -f "$tmp"; }
trap cleanup EXIT

run_and_tee() {
  # Usage: run_and_tee [-a] -- command args...
  # Runs command, merges stderr->stdout, tees into $tmp, returns the command's exit code.
  local tee_flag=""
  if [[ "${1-}" == "-a" ]]; then
    tee_flag="-a"
    shift
  fi
  [[ "${1-}" == "--" ]] || { echo "copy: internal error (missing --)" >&2; exit 99; }
  shift

  set +e
  "$@" 2>&1 | tee $tee_flag "$tmp"
  local ps=("${PIPESTATUS[@]}")
  set -e
  return "${ps[0]}"
}

run_shell_and_tee() {
  # Usage: run_shell_and_tee [-a] -- "shell command string"
  local tee_flag=""
  if [[ "${1-}" == "-a" ]]; then
    tee_flag="-a"
    shift
  fi
  [[ "${1-}" == "--" ]] || { echo "copy: internal error (missing --)" >&2; exit 99; }
  shift
  local cmd="${1-}"
  [[ -n "$cmd" ]] || usage

  set +e
  bash -o pipefail -c "$cmd" 2>&1 | tee $tee_flag "$tmp"
  local ps=("${PIPESTATUS[@]}")
  set -e
  return "${ps[0]}"
}

if [[ "$mode" == "file" ]]; then
  [[ -n "$file" ]] || usage
  [[ $# -eq 0 && -z "$shell_cmd" ]] || usage
  cat -- "$file" | clip_copy
  exit 0
fi

if [[ -n "$shell_cmd" ]]; then
  [[ $# -eq 0 ]] || usage

  if [[ "$mode" == "all" ]]; then
    printf '$ %s\n' "$shell_cmd" >"$tmp"
    if run_shell_and_tee -a -- "$shell_cmd"; then
      :
    else
      rc=$?
    fi
    cat "$tmp" | clip_copy
    exit "${rc:-0}"
  else
    if run_shell_and_tee -- "$shell_cmd"; then
      rc=0
    else
      rc=$?
    fi
    cat "$tmp" | clip_copy
    exit "$rc"
  fi
fi

# argv-mode (no -c): runs the command directly (no eval).
[[ $# -ge 1 ]] || usage

if [[ "$mode" == "all" ]]; then
  {
    printf '$'
    for a in "$@"; do printf ' %q' "$a"; done
    printf '\n'
  } >"$tmp"

  if run_and_tee -a -- "$@"; then
    :
  else
    rc=$?
  fi
  cat "$tmp" | clip_copy
  exit "${rc:-0}"
else
  if run_and_tee -- "$@"; then
    rc=0
  else
    rc=$?
  fi
  cat "$tmp" | clip_copy
  exit "$rc"
fi
