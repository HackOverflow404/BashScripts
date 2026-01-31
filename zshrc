# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ============================================================================
# Oh My Zsh Configuration (must come early)
# ============================================================================
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(
    git
    zsh-autosuggestions
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

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ============================================================================
# Custom Functions
# ============================================================================
# Copy stdout and stderr to clipboard
copy() {
  echo "\\$ $*" > /tmp/cmd_output.$$
  "$@" 2>&1 | tee -a /tmp/cmd_output.$$
  cat /tmp/cmd_output.$$ | xclip -selection clipboard
  rm /tmp/cmd_output.$$
}

# ============================================================================
# Terminal Welcome Screen
# ============================================================================
# Only run in interactive shells, not in TMUX sub-shells
if [[ -z "$TMUX" ]]; then
    # Fullscreen terminal window (after everything is loaded)
    wmctrl -r :ACTIVE: -b add,maximized_vert,maximized_horz 2>/dev/null || true
fi

# ============================================================================
# TMUX Autostart
# ============================================================================
if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
  exec tmux
fi

clear && fastfetch --file ~/Documents/hacking/d4rkc10ud-logo-ASCII-art-small.txt
