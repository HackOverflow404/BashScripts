#!/usr/bin/env bash
input=$(cat)

# ── Parse JSON ──────────────────────────────────────────────
CTX_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CTX_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
CWD=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
RL_5H=$(echo "$input" | jq -r '.rate_limits.five_hour.percent_used // 0' | cut -d. -f1)
RL_7D=$(echo "$input" | jq -r '.rate_limits.seven_day.percent_used // 0' | cut -d. -f1)

# ── Git ──────────────────────────────────────────────────────
BRANCH=""
DIRTY=""
if [ -n "$CWD" ]; then
    BRANCH=$(git -C "$CWD" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
    if [ -n "$BRANCH" ]; then
        DIRTY_COUNT=$(git -C "$CWD" --no-optional-locks status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        [ "$DIRTY_COUNT" -gt 0 ] && DIRTY=" *"
    fi
fi

# ── Colors ───────────────────────────────────────────────────
RESET='\033[0m'
DIM='\033[2m'
GRAY='\033[38;5;240m'
MID='\033[38;5;245m'
LIGHT='\033[38;5;250m'
YELLOW='\033[38;5;136m'
RED='\033[38;5;124m'
SEP="${GRAY} · ${RESET}"

# ── Context bar ──────────────────────────────────────────────
BAR_WIDTH=10
FILLED=$(( CTX_PCT * BAR_WIDTH / 100 ))
EMPTY=$(( BAR_WIDTH - FILLED ))
BAR=""
for ((i=0; i<FILLED; i++)); do BAR="${BAR}█"; done
for ((i=0; i<EMPTY; i++));  do BAR="${BAR}░"; done

# Context color: gray < 70%, yellow < 85%, red >= 85%
if   [ "$CTX_PCT" -ge 85 ]; then CTX_COLOR="$RED"
elif [ "$CTX_PCT" -ge 70 ]; then CTX_COLOR="$YELLOW"
else                              CTX_COLOR="$MID"
fi

# Rate limit color (same thresholds)
rl_color() {
    local pct=$1
    if   [ "$pct" -ge 85 ]; then echo "$RED"
    elif [ "$pct" -ge 70 ]; then echo "$YELLOW"
    else                         echo "$GRAY"
    fi
}

# ── Format values ────────────────────────────────────────────
CTX_K=$(( CTX_SIZE / 1000 ))
COST_FMT=$(printf '%.4f' "$COST")
CWD_SHORT="${CWD/#$HOME/\~}"

# ── Assemble ─────────────────────────────────────────────────
OUT=""

# Working dir
OUT+="${MID}${CWD_SHORT}${RESET}"

# Git (only if inside a repo)
if [ -n "$BRANCH" ]; then
    OUT+="${SEP}${GRAY}${BRANCH}${DIRTY}${RESET}"
fi

# Context window
OUT+="${SEP}${GRAY}ctx ${RESET}${CTX_COLOR}${CTX_PCT}%${RESET}"
OUT+="${GRAY}/${CTX_K}k ${RESET}"
OUT+="${GRAY}[${CTX_COLOR}${BAR}${GRAY}]${RESET}"

# Cost
OUT+="${SEP}${GRAY}\$${COST_FMT}${RESET}"

# Rate limits (only if data is present)
if [ "$RL_5H" -gt 0 ] || [ "$RL_7D" -gt 0 ]; then
    RL_5H_COLOR=$(rl_color "$RL_5H")
    RL_7D_COLOR=$(rl_color "$RL_7D")
    OUT+="${SEP}${GRAY}5h $(${RL_5H_COLOR})${RL_5H}%${RESET}"
    OUT+="${SEP}${GRAY}7d $(${RL_7D_COLOR})${RL_7D}%${RESET}"
fi

printf '%b\n' "$OUT"
