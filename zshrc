# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

# ============================================================================
# Oh My Zsh Configuration (must come early)
# ============================================================================
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(
    git
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# ============================================================================
# Shell Options
# ============================================================================
setopt histignorealldups sharehistory

# Use emacs keybindings even if our EDITOR is set to vi
bindkey -e

# Keep 1000 lines of history within the shell and save it to ~/.zsh_history:
HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_history

# ============================================================================
# Completion System
# ============================================================================
autoload -Uz compinit
compinit

zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' menu select=2
eval "$(dircolors -b)"
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true

zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

# ============================================================================
# PATH Configuration
# ============================================================================
export PATH="$HOME/.local/bin:$PATH"
export PATH="/opt/toolchains/riscv/bin:$PATH"
export PATH="$HOME/riscv/bin:$PATH"

# Cargo environment
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# ============================================================================
# Key Bindings
# ============================================================================
# Bind Ctrl+Arrow keys to word jumps
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

# ============================================================================
# NVM Configuration
# ============================================================================
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# ============================================================================
# Aliases
# ============================================================================
if [ -f ~/.zsh_aliases ]; then
    . ~/.zsh_aliases
fi

# Wrapper around `caelestia scheme set` that also regenerates the
# alpha-suffix color variables Hyprland needs (e.g. $primarye6) and
# reloads the Hyprland config. Usage: caelestia-scheme set -n shadotheme
caelestia-scheme() {
    caelestia scheme "$@"
    if [[ "$1" == "set" ]]; then
        python3 - << 'EOF'
import re
from pathlib import Path
conf = Path.home() / ".config/hypr/scheme/current.conf"
colors = dict(re.findall(r'\$(\w+)\s*=\s*([0-9a-fA-F]{6})', conf.read_text()))
variants = [
    ("primarye6",          colors.get("primary", ""),          "e6"),
    ("primaryd4",          colors.get("primary", ""),          "d4"),
    ("outlined4",          colors.get("outline", ""),          "d4"),
    ("secondaryd4",        colors.get("secondary", ""),        "d4"),
    ("onSurfaceVariant11", colors.get("onSurfaceVariant", ""), "11"),
    ("inversePrimary10",   colors.get("inversePrimary", ""),   "10"),
]
out = Path.home() / ".config/caelestia/hypr-vars.conf"
out.write_text(
    "# Alpha-channel variants derived from current scheme (auto-generated)\n"
    + "\n".join(f"${n} = {b}{a}" for n, b, a in variants)
    + "\n"
)
print("Alpha vars updated.")
EOF
        hyprctl reload 2>/dev/null && echo "Hyprland reloaded." || echo "(Hyprland not running — reload skipped.)"
    fi
}

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ============================================================================
# TMUX Autostart
# ============================================================================
if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
  exec tmux
fi

clear && fastfetch --file ~/Documents/hacking/d4rkc10ud-logo-ASCII-art-small.txt

# venv-wrapper — added by `venv --install-wrapper`
# Routes activation through `source`; delegates commands to ~/.local/bin/venv
venv() {
    case "${1:-}" in
        -h|--help|-v|--version|-c|--create|-d|--delete|-l|--list|-i|--info|--install-wrapper)
            command venv "$@"
            ;;
        -)
            # Re-activate last used venv
            local last_file="${XDG_CACHE_HOME:-$HOME/.cache}/venv-last"
            if [[ ! -f "$last_file" ]]; then
                echo "✗  No previously activated venv found." >&2; return 1
            fi
            local entry; entry="$(cat "$last_file")"
            local dir="${entry%%:*}"; local name="${entry##*:}"
            if [[ "$dir" != "$(pwd)" ]]; then
                echo "✗  Last venv was in a different directory: $dir" >&2; return 1
            fi
            local activate="./$name/bin/activate"
            [[ -f "$activate" ]] || { echo "✗  $activate not found." >&2; return 1; }
            source "$activate"
            echo -e "\033[0;32m✓\033[0m  Re-activated: $name ($(python --version 2>&1))"
            ;;
        *)
            local name="${1:-venv}"
            local activate="./$name/bin/activate"
            if [[ ! -f "$activate" ]]; then
                echo -e "\033[0;31m✗\033[0m  No activate script at $activate" >&2
                echo    "   Create one with: venv --create $name" >&2
                return 1
            fi
            source "$activate"
            echo -e "\033[0;32m✓\033[0m  Activated: $name ($(python --version 2>&1))"
            # Remember for `venv -` (re-activate)
            local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
            mkdir -p "$cache_dir"
            echo "$(pwd):$name" > "$cache_dir/venv-last"
            ;;
    esac
}
