#!/usr/bin/env bash
# venv — virtual environment manager
# Install:
#   cp venv ~/.local/bin/venv && chmod +x ~/.local/bin/venv
#   venv --install-wrapper   ← run once, then reload your shell

set -euo pipefail

VERSION="1.1.0"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

_ok()   { echo -e "${GREEN}✓${NC}  $*"; }
_warn() { echo -e "${YELLOW}⚠${NC}  $*" >&2; }
_err()  { echo -e "${RED}✗${NC}  $*" >&2; }
_h()    { echo -e "\n${BOLD}${BLUE}$*${NC}"; }
_die()  { _err "$*"; exit 1; }

# ── Help ──────────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF

$(echo -e "${BOLD}venv${NC} ${DIM}v${VERSION}${NC} — virtual environment manager")
$(_h "USAGE")
  venv [NAME]                   Activate ./venv (or ./<NAME>)
  venv -                        Re-activate the most recently used venv
  venv -c  [NAME] [VERSION]     Create a venv
  venv -f  [NAME]               Freeze installed packages to requirements.txt
  venv -d  [NAME]               Delete a venv (with confirmation)
  venv -l                       List venvs in the current directory
  venv -i  [NAME]               Show details about a venv
  venv --clean [NAME]           Remove unused/unnecessary packages
  venv -h                       Show this help page
$(_h "CREATE  (-c)")
  NAME defaults to 'venv'. VERSION is a Python minor version e.g. 3.12.
  If omitted, the system default python3 is used.

  venv -c                       Create ./venv with default python3
  venv -c .venv                 Create ./.venv with default python3
  venv -c myenv 3.12            Create ./myenv with python3.12
  venv -c 3.11                  Create ./venv with python3.11
  venv -c ci 3.10 -r dev.txt    Create ./ci, install from dev.txt

  -r, --requirements FILE       pip install -r FILE after creation
                                (auto-detected if requirements.txt exists)
  --no-requirements             Skip auto-installing requirements.txt
$(_h "FREEZE  (-f)")
  Saves installed packages to a requirements file so others can reproduce
  your environment exactly. Shows a diff if the file already exists.

  venv -f                       Freeze active (or ./venv) → requirements.txt
  venv -f myenv                 Freeze ./myenv → requirements.txt
  venv -f -o deps.txt           Write to deps.txt instead
  venv -f --minimal             Top-level packages only (no transitive deps)

  -o, --output FILE             Output file (default: requirements.txt)
  --minimal                     Only direct/top-level packages, not all deps
$(_h "CLEAN  (--clean)")
  Uninstalls packages that are not needed. Two modes:

  With a requirements file (-r):
    Computes the full dependency tree of requirements.txt and removes
    everything not in it. Safe and precise.

  Without a requirements file:
    Finds orphan packages — installed, but nothing else depends on them.
    Useful after manually uninstalling packages that left deps behind.
    Shows each candidate and asks you to confirm.

  venv --clean                  Clean active (or ./venv)
  venv --clean myenv            Clean ./myenv
  venv --clean -r req.txt       Remove anything not needed by req.txt
  venv --clean --dry-run        Show what would be removed, don't remove it
$(_h "EXAMPLES")
  venv                          Activate ./venv
  venv .venv                    Activate ./.venv
  venv -                        Re-activate last used venv
  venv -c myenv 3.12            Create ./myenv with python3.12
  venv -f                       Freeze active venv → requirements.txt
  venv -f --minimal             Freeze only top-level packages
  venv --clean                  Remove orphan packages from active venv
  venv --clean -r requirements.txt  Remove anything not in requirements.txt
  venv -d old-env               Delete ./old-env
  venv -l                       List all venvs here
  venv -i                       Inspect ./venv
  deactivate                    Deactivate (standard shell built-in)
$(_h "FIRST-TIME SETUP")
  Because activating a venv modifies your shell's environment, it must be
  run with 'source'. The install-wrapper command adds a tiny shell function
  to your ~/.zshrc (or ~/.bashrc) that handles this for you automatically,
  so plain 'venv' just works — no 'source' needed.

  venv --install-wrapper        Run once, then: source ~/.zshrc

EOF
}

# ── Helpers ───────────────────────────────────────────────────────────────────
_is_venv_dir() { [[ -f "$1/bin/activate" && -f "$1/bin/python" ]]; }
_py_ver()      { "$1/bin/python" --version 2>/dev/null || echo "unknown"; }
_pkg_count()   { "$1/bin/pip" list 2>/dev/null | awk 'NR>2{c++}END{print c+0}'; }
_last_file()   { echo "${XDG_CACHE_HOME:-$HOME/.cache}/venv-last"; }
_save_last()   { mkdir -p "$(dirname "$(_last_file)")"; echo "$1" > "$(_last_file)"; }

_looks_like_version() { [[ "$1" =~ ^[0-9]+\.[0-9] ]]; }
_resolve_python()     {
    _looks_like_version "$1" && echo "python${1}" || echo "$1"
}

# Packages that should never be touched by freeze/clean
_CORE_PKGS="pip setuptools wheel pkg.resources pkg_resources distribute"
_is_core() {
    local p; p=$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr '_' '-')
    echo "$_CORE_PKGS" | tr ' ' '\n' | grep -qx "$p"
}

# Normalise a package name to lowercase-hyphenated for comparisons
_norm() { echo "$1" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | tr -d ' '; }

# Resolve the pip binary for a named venv, or fall back to the active venv.
# Prints the pip path; exits 1 on failure.
_pip_for() {
    local name="$1"
    if [[ "$name" == "__active__" ]]; then
        if [[ -z "${VIRTUAL_ENV:-}" ]]; then
            _die "No active virtual environment and no name given."
        fi
        echo "$VIRTUAL_ENV/bin/pip"
    else
        _is_venv_dir "$name" || _die "No virtual environment found at './$name'"
        echo "./$name/bin/pip"
    fi
}

# BFS over pip's dependency graph starting from requirements.txt.
# Writes one normalised package name per line to stdout.
_transitive_deps() {
    local pip_bin="$1"
    local req_file="$2"
    local queue; queue=$(mktemp)
    local seen;  seen=$(mktemp)
    trap 'rm -f "$queue" "$seen"' RETURN

    # Seed the queue from requirements.txt (strip comments, version specs, -r lines)
    grep -v '^\s*#\|^\s*-\|^\s*$' "$req_file" 2>/dev/null \
        | sed 's/[>=<!;].*//' \
        | while IFS= read -r line; do _norm "$line"; done \
        > "$queue" || true

    while [[ -s "$queue" ]]; do
        local pkg; pkg=$(head -1 "$queue")
        sed -i '1d' "$queue"
        [[ -z "$pkg" ]] && continue
        grep -qx "$pkg" "$seen" 2>/dev/null && continue   # already visited
        echo "$pkg" >> "$seen"

        # Queue this package's dependencies
        "$pip_bin" show "$pkg" 2>/dev/null \
            | grep -i '^Requires:' \
            | cut -d: -f2 \
            | tr ',' '\n' \
            | while IFS= read -r dep; do
                dep=$(_norm "$dep")
                [[ -z "$dep" ]] && continue
                grep -qx "$dep" "$seen" 2>/dev/null || echo "$dep"
              done >> "$queue" || true
    done

    cat "$seen"
}

# ── cmd_create ────────────────────────────────────────────────────────────────
cmd_create() {
    local name="$1" python="$2" req_file="$3" auto_req="$4"

    command -v "$python" &>/dev/null || _die "Python interpreter not found: '$python'"
    local py_ver; py_ver="$("$python" --version 2>&1)"

    if [[ -d "$name" ]]; then
        if _is_venv_dir "$name"; then
            _warn "'$name' already exists ($(_py_ver "$name"))"
        else
            _warn "'$name' exists but doesn't look like a venv"
        fi
        printf "  Overwrite? [y/N] "; read -r confirm
        [[ "${confirm,,}" == "y" ]] || { _ok "Aborted."; return 0; }
        rm -rf "$name"
    fi

    _ok "Creating '$name' with $py_ver …"
    "$python" -m venv "$name" || _die "Failed to create virtual environment."
    _ok "Created: $(pwd)/$name"

    local req=""
    if   [[ -n "$req_file" ]];                              then req="$req_file"
    elif [[ "$auto_req" == "yes" && -f "requirements.txt" ]]; then req="requirements.txt"
    fi
    if [[ -n "$req" ]]; then
        [[ -f "$req" ]] || { _warn "Requirements file not found: $req"; return 0; }
        _ok "Installing from $req …"
        "$name/bin/pip" install --quiet --upgrade pip
        "$name/bin/pip" install -r "$req" || _warn "Some packages failed to install."
    fi

    echo -e "  ${DIM}Activate with:${NC} ${BOLD}venv $name${NC}"
}

# ── cmd_freeze ────────────────────────────────────────────────────────────────
cmd_freeze() {
    local name="$1" output="$2" minimal="$3"
    local pip_bin; pip_bin="$(_pip_for "$name")"

    # Collect packages
    local packages
    if [[ "$minimal" == "yes" ]]; then
        # Top-level only: packages nothing else depends on
        packages=$(
            "$pip_bin" list --not-required --format=freeze 2>/dev/null \
            | grep -iv '^pip==\|^setuptools==\|^wheel==\|^pkg.resources==' \
            | grep -v '^-e' || true
        )
    else
        # Full freeze: every installed package, pinned
        packages=$(
            "$pip_bin" freeze 2>/dev/null \
            | grep -iv '^pip==\|^setuptools==\|^wheel==\|^pkg.resources==' \
            | grep -v '^-e' || true
        )
    fi

    if [[ -z "$packages" ]]; then
        _warn "No packages to freeze (excluding core packages)."; return 0
    fi

    # Show diff if file already exists
    if [[ -f "$output" ]]; then
        local added removed
        added=$(comm  -13 <(sort "$output") <(echo "$packages" | sort))
        removed=$(comm -23 <(sort "$output") <(echo "$packages" | sort))
        if [[ -z "$added" && -z "$removed" ]]; then
            _ok "$output is already up to date."; return 0
        fi
        echo -e "\n  ${BOLD}Changes vs existing $output:${NC}"
        [[ -n "$added"   ]] && echo "$added"   | while IFS= read -r l; do
            echo -e "    ${GREEN}+ $l${NC}"
        done
        [[ -n "$removed" ]] && echo "$removed" | while IFS= read -r l; do
            echo -e "    ${RED}- $l${NC}"
        done
        echo ""
        printf "  Overwrite %s? [y/N] " "$output"; read -r confirm
        [[ "${confirm,,}" == "y" ]] || { _ok "Aborted."; return 0; }
    fi

    echo "$packages" > "$output"
    local count; count=$(echo "$packages" | grep -c '.' || true)
    _ok "Froze $count package(s) → $output"
    if [[ "$minimal" == "yes" ]]; then
        echo -e "  ${DIM}Top-level packages only. Omit --minimal to pin all transitive deps.${NC}"
    fi
}

# ── cmd_clean ─────────────────────────────────────────────────────────────────
cmd_clean() {
    local name="$1" req_file="$2" dry_run="$3"
    local pip_bin; pip_bin="$(_pip_for "$name")"
    [[ "$name" == "__active__" ]] && name="$(basename "${VIRTUAL_ENV:-active}")"

    # All installed packages (normalised), excluding core
    local all_pkgs
    all_pkgs=$(
        "$pip_bin" list --format=freeze 2>/dev/null \
        | grep -iv '^pip==\|^setuptools==\|^wheel==\|^pkg.resources==' \
        | sed 's/==.*//' \
        | while IFS= read -r p; do _norm "$p"; done \
        || true
    )

    if [[ -z "$all_pkgs" ]]; then
        _ok "No packages installed (excluding core). Nothing to clean."; return 0
    fi

    local removable=()

    if [[ -n "$req_file" ]]; then
        # ── Mode 1: requirements-guided clean ─────────────────────────────
        [[ -f "$req_file" ]] || _die "Requirements file not found: $req_file"
        echo -e "  ${DIM}Computing dependency tree from $req_file …${NC}"
        local needed; needed=$(_transitive_deps "$pip_bin" "$req_file")

        while IFS= read -r pkg; do
            [[ -z "$pkg" ]] && continue
            echo "$needed" | grep -qx "$pkg" || removable+=("$pkg")
        done <<< "$all_pkgs"

        if [[ ${#removable[@]} -eq 0 ]]; then
            _ok "Everything installed is required by $req_file. Nothing to clean."
            return 0
        fi
        echo ""
        _h "Not needed by $req_file (or their dependencies):"

    else
        # ── Mode 2: orphan clean (no requirements file) ───────────────────
        # Find packages nothing else depends on
        local orphans
        orphans=$(
            "$pip_bin" list --not-required --format=freeze 2>/dev/null \
            | grep -iv '^pip==\|^setuptools==\|^wheel==\|^pkg.resources==' \
            | sed 's/==.*//' \
            | while IFS= read -r p; do _norm "$p"; done \
            || true
        )

        while IFS= read -r pkg; do
            [[ -z "$pkg" ]] && continue
            removable+=("$pkg")
        done <<< "$orphans"

        if [[ ${#removable[@]} -eq 0 ]]; then
            _ok "No orphan packages found. Nothing to clean."; return 0
        fi
        echo ""
        _h "Orphan packages (installed, but nothing else depends on them):"
        echo -e "  ${DIM}Note: these may be top-level packages you installed on purpose."
        echo -e "  Use -r requirements.txt for a more precise clean.${NC}"
    fi

    # Print the candidate list with versions
    for pkg in "${removable[@]}"; do
        local ver; ver=$("$pip_bin" show "$pkg" 2>/dev/null | awk '/^Version:/{print $2}')
        printf "  ${RED}−${NC}  %-30s %s\n" "$pkg" "${ver:-unknown}"
    done
    echo ""

    if [[ "$dry_run" == "yes" ]]; then
        echo -e "  ${DIM}Dry run — nothing was removed.${NC}"
        return 0
    fi

    printf "  Remove %d package(s)? [y/N] " "${#removable[@]}"; read -r confirm
    [[ "${confirm,,}" == "y" ]] || { _ok "Aborted."; return 0; }

    "$pip_bin" uninstall -y "${removable[@]}" \
        && _ok "Removed ${#removable[@]} package(s)." \
        || _warn "Some packages could not be removed."
}

# ── cmd_delete ────────────────────────────────────────────────────────────────
cmd_delete() {
    local name="$1"
    _is_venv_dir "$name" || _die "No virtual environment found at './$name'"
    echo -e "  ${BOLD}$name${NC}  $(_py_ver "$name")  $(_pkg_count "$name") packages"
    printf "  Permanently delete? [y/N] "; read -r confirm
    [[ "${confirm,,}" == "y" ]] || { _ok "Aborted."; return 0; }
    rm -rf "$name"
    _ok "Deleted: $name"
}

# ── cmd_list ──────────────────────────────────────────────────────────────────
cmd_list() {
    echo -e "${BOLD}${BLUE}Virtual environments in $(pwd):${NC}"
    local found=0
    for dir in */ .*/; do
        dir="${dir%/}"; [[ -d "$dir" ]] || continue
        _is_venv_dir "$dir" || continue
        printf "  ${GREEN}%-20s${NC}  %-18s  %s packages\n" \
            "$dir" "$(_py_ver "$dir")" "$(_pkg_count "$dir")"
        found=1
    done
    [[ $found -eq 1 ]] || echo -e "  ${DIM}None found.${NC}"
}

# ── cmd_info ──────────────────────────────────────────────────────────────────
cmd_info() {
    local name="$1"
    _is_venv_dir "$name" || _die "No virtual environment found at './$name'"
    local size; size=$(du -sh "$name" 2>/dev/null | cut -f1)
    echo -e "\n${BOLD}${BLUE}venv: $name${NC}"
    printf "  %-12s %s\n" "Path:"     "$(pwd)/$name"
    printf "  %-12s %s\n" "Python:"   "$(_py_ver "$name")"
    printf "  %-12s %s\n" "Packages:" "$(_pkg_count "$name") installed"
    printf "  %-12s %s\n" "Size:"     "$size"
    echo ""
    local pkgs; pkgs=$(_pkg_count "$name")
    if [[ $pkgs -gt 0 ]]; then
        echo -e "  ${DIM}Installed packages:${NC}"
        "$name/bin/pip" list 2>/dev/null | tail -n +3 | \
            awk '{printf "    %-28s %s\n", $1, $2}'
    fi
}

# ── cmd_install_wrapper ───────────────────────────────────────────────────────
cmd_install_wrapper() {
    local shell_name; shell_name="$(basename "${SHELL:-bash}")"
    local rc_file
    case "$shell_name" in
        zsh)  rc_file="$HOME/.zshrc" ;;
        bash) rc_file="$HOME/.bashrc" ;;
        *)    _die "Unsupported shell '$shell_name'. Add the wrapper manually — see venv -h." ;;
    esac

    if grep -q "# venv-wrapper" "$rc_file" 2>/dev/null; then
        _warn "Wrapper already present in $rc_file — nothing changed."
        return 0
    fi

    cat >> "$rc_file" <<'SHELLWRAPPER'

# venv-wrapper — added by `venv --install-wrapper`
# Shell functions can call `source`; scripts in PATH cannot modify your shell.
# This function is the bridge: non-activation commands go straight to the
# script; activation is handled here via `source`.
venv() {
    case "${1:-}" in
        # ── Commands that don't need sourcing — delegate to the script ────
        -c|--create|-f|--freeze|-d|--delete|-l|--list|-i|--info|\
        --clean|-h|--help|-v|--version|--install-wrapper)
            command venv "$@" ;;

        # ── Re-activate last used venv ─────────────────────────────────────
        -)
            local last_file="${XDG_CACHE_HOME:-$HOME/.cache}/venv-last"
            if [[ ! -f "$last_file" ]]; then
                echo -e "\033[0;31m✗\033[0m  No previously activated venv found." >&2
                return 1
            fi
            local entry; entry="$(cat "$last_file")"
            local dir="${entry%%:*}" name="${entry##*:}"
            if [[ "$dir" != "$(pwd)" ]]; then
                echo -e "\033[0;31m✗\033[0m  Last venv was in: $dir" >&2; return 1
            fi
            local activate="./$name/bin/activate"
            [[ -f "$activate" ]] || {
                echo -e "\033[0;31m✗\033[0m  $activate not found." >&2; return 1
            }
            source "$activate"
            echo -e "\033[0;32m✓\033[0m  Re-activated: $name ($(python --version 2>&1))"
            ;;

        # ── Activate a venv ────────────────────────────────────────────────
        *)
            local name="${1:-venv}"
            local activate="./$name/bin/activate"
            if [[ ! -f "$activate" ]]; then
                echo -e "\033[0;31m✗\033[0m  No activate script at $activate" >&2
                echo    "   Create one with: venv -c $name" >&2
                return 1
            fi
            source "$activate"
            echo -e "\033[0;32m✓\033[0m  Activated: $name ($(python --version 2>&1))"
            local cache="${XDG_CACHE_HOME:-$HOME/.cache}"
            mkdir -p "$cache" && echo "$(pwd):$name" > "$cache/venv-last"
            ;;
    esac
}
SHELLWRAPPER

    _ok "Wrapper function added to $rc_file"
    echo -e "  Apply now with: ${BOLD}source $rc_file${NC}"
}

# ── Sourced-script activation path ───────────────────────────────────────────
_is_sourced() { [[ "${BASH_SOURCE[0]:-}" != "${0}" ]]; }

if _is_sourced; then
    _name="${1:-venv}"
    case "$_name" in
        -h|--help) usage; return 0 ;;
        -)
            _last="$(_last_file)"
            [[ -f "$_last" ]] || { _err "No previously activated venv found."; return 1; }
            _entry="$(cat "$_last")"
            _dir="${_entry%%:*}"; _name="${_entry##*:}"
            [[ "$_dir" == "$(pwd)" ]] || { _err "Last venv was in: $_dir"; return 1; }
            ;;
    esac
    _act="./$_name/bin/activate"
    if [[ ! -f "$_act" ]]; then
        _err "No activate script at $_act"
        echo "  Create one with: venv -c $_name" >&2
        return 1
    fi
    # shellcheck source=/dev/null
    source "$_act"
    _ok "Activated: $_name ($(python --version 2>&1))"
    _save_last "$(pwd):$_name"
    unset _name _act _last _entry _dir
    return 0
fi

# ── Normal command dispatch ───────────────────────────────────────────────────
NAME="venv"
PYTHON="python3"
REQ_FILE=""
AUTO_REQ="yes"
OUTPUT="requirements.txt"
MINIMAL="no"
DRY_RUN="no"

[[ $# -eq 0 ]] && { usage; exit 0; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)    usage; exit 0 ;;
        -v|--version) echo "venv $VERSION"; exit 0 ;;
        --install-wrapper) cmd_install_wrapper; exit $? ;;

        -c|--create)
            shift
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -r|--requirements) shift; REQ_FILE="$1"; shift ;;
                    --no-requirements) AUTO_REQ="no"; shift ;;
                    -*)  _die "Unknown option for -c: $1" ;;
                    *)
                        if _looks_like_version "$1"; then
                            PYTHON="$(_resolve_python "$1")"
                        else
                            NAME="$1"
                        fi
                        shift
                        ;;
                esac
            done
            cmd_create "$NAME" "$PYTHON" "$REQ_FILE" "$AUTO_REQ"
            exit $?
            ;;

        -f|--freeze)
            shift
            # Determine if next arg is a venv name or a flag
            if [[ $# -gt 0 && "${1:-}" != -* ]]; then
                # Could be a venv name — check if it looks like a dir or matches __active__
                NAME="$1"; shift
            else
                # Default: use active venv if one is running, else ./venv
                [[ -n "${VIRTUAL_ENV:-}" ]] && NAME="__active__"
            fi
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -o|--output)  shift; OUTPUT="$1"; shift ;;
                    --minimal)    MINIMAL="yes"; shift ;;
                    *) _die "Unknown option for -f: $1" ;;
                esac
            done
            cmd_freeze "$NAME" "$OUTPUT" "$MINIMAL"
            exit $?
            ;;

        --clean)
            shift
            if [[ $# -gt 0 && "${1:-}" != -* ]]; then
                NAME="$1"; shift
            else
                [[ -n "${VIRTUAL_ENV:-}" ]] && NAME="__active__"
            fi
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -r|--requirements) shift; REQ_FILE="$1"; shift ;;
                    --dry-run)         DRY_RUN="yes"; shift ;;
                    *) _die "Unknown option for --clean: $1" ;;
                esac
            done
            cmd_clean "$NAME" "$REQ_FILE" "$DRY_RUN"
            exit $?
            ;;

        -d|--delete)
            shift
            [[ "${1:-}" != -* && -n "${1:-}" ]] && { NAME="$1"; shift; }
            cmd_delete "$NAME"
            exit $?
            ;;

        -l|--list)  cmd_list; exit 0 ;;

        -i|--info)
            shift
            [[ "${1:-}" != -* && -n "${1:-}" ]] && { NAME="$1"; shift; }
            cmd_info "$NAME"
            exit $?
            ;;

        -*)
            _err "Unknown option: $1"
            echo "  Run 'venv -h' for usage." >&2
            exit 1
            ;;

        *)
            _warn "To activate, this script must be sourced."
            echo  "  Run 'venv --install-wrapper' once, then reload your shell." >&2
            echo  "  After that, plain 'venv $1' will work." >&2
            exit 1
            ;;
    esac
done
