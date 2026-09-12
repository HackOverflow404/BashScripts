# ============================================================================
# TMUX Autostart
# ============================================================================
# Exec into tmux before the expensive init below; otherwise that init runs
# here, gets discarded by the exec, then repeats inside tmux.
if [[ -t 0 && -t 1 ]] && command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
  exec tmux
fi

# Print the greeting before instant prompt redirects stdout away from the terminal.
if [[ -o interactive && -t 1 ]]; then
  _logo=~/Documents/hacking/d4rkc10ud-logo-ASCII-art-small.txt
  clear
  if [[ -f $_logo ]]; then
    fastfetch --file "$_logo"
  else
    fastfetch
  fi
  unset _logo
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

# ============================================================================
# Oh My Zsh
# ============================================================================
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(
    git
    zsh-syntax-highlighting
)
source $ZSH/oh-my-zsh.sh

# ============================================================================
# Shell Options & History
# ============================================================================
setopt histignorealldups sharehistory

# Use emacs keybindings even if EDITOR is set to vi
bindkey -e

HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history

# ============================================================================
# Completion System
# ============================================================================
# compinit already runs via oh-my-zsh above; re-running here just doubles it.
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
# PATH
# ============================================================================
# OMARCHY_PATH, ~/.local/share/mise/shims and ~/.local/bin are already on PATH
# via env-bootstrap in ~/.zshenv. Only add the optional toolchains here.
[[ -d /opt/toolchains/riscv/bin ]] && export PATH="/opt/toolchains/riscv/bin:$PATH"
[[ -d "$HOME/riscv/bin" ]]        && export PATH="$HOME/riscv/bin:$PATH"

# ============================================================================
# Tool Init
# ============================================================================
command -v mise   &> /dev/null && eval "$(mise activate zsh)"
command -v zoxide &> /dev/null && eval "$(zoxide init zsh)"
[[ -r /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
[[ -r /usr/share/fzf/completion.zsh ]]   && source /usr/share/fzf/completion.zsh

# ============================================================================
# Key Bindings
# ============================================================================
# Ctrl+Arrow word jumps
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

# ============================================================================
# Aliases
# ============================================================================
if [ -f ~/.zsh_aliases ]; then
    . ~/.zsh_aliases
fi

# ============================================================================
# venv wrapper — added by `venv --install-wrapper`
# Routes activation through `source`; delegates commands to ~/.local/bin/venv
# ============================================================================
venv() {
    case "${1:-}" in
        -h|--help|-v|--version|-c|--create|-f|--freeze|--clean|-d|--delete|-l|--list|-i|--info|--install-wrapper)
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
            local activate="$name/bin/activate"
            [[ $activate == /* ]] || activate="./$activate"
            [[ -f "$activate" ]] || { echo "✗  $activate not found." >&2; return 1; }
            source "$activate" || return
            echo -e "\033[0;32m✓\033[0m  Re-activated: $name ($(python --version 2>&1))"
            ;;
        *)
            local name="${1:-venv}"
            local activate="$name/bin/activate"
            [[ $activate == /* ]] || activate="./$activate"
            if [[ ! -f "$activate" ]]; then
                echo -e "\033[0;31m✗\033[0m  No activate script at $activate" >&2
                echo    "   Create one with: venv --create $name" >&2
                return 1
            fi
            source "$activate" || return
            echo -e "\033[0;32m✓\033[0m  Activated: $name ($(python --version 2>&1))"
            local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
            mkdir -p "$cache_dir"
            echo "$(pwd):$name" > "$cache_dir/venv-last"
            ;;
    esac
}

# ============================================================================
# Prompt
# ============================================================================
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/hackoverflow404/google-cloud-sdk/path.zsh.inc' ]; then . '/home/hackoverflow404/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/home/hackoverflow404/google-cloud-sdk/completion.zsh.inc' ]; then . '/home/hackoverflow404/google-cloud-sdk/completion.zsh.inc'; fi


# Added by Antigravity CLI installer
export PATH="/home/hackoverflow404/.local/bin:$PATH"
