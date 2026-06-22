#!/usr/bin/env bash
# Claude Code status line (two rows):
#   row 1:  [Model · effort] 📁 dir | 🌿 branch
#   row 2:  [██████░░░░] 42% ctx | 💾 87% cache | 💰 $0.12
#
# Reads Claude Code session JSON on stdin and prints the status line on stdout.
# Requires: jq   (macOS: brew install jq | Debian/Ubuntu: sudo apt install jq)
#
# Cache % is for the MOST RECENT API turn only (Claude Code does not expose a
# session-wide cache figure). It is "n/a" before the first response and right
# after /compact, until the next API call repopulates the data.

input=$(cat)

# ---- simple fields (null-safe) --------------------------------------------
MODEL=$(echo "$input"  | jq -r '.model.display_name // "Claude"')
EFFORT=$(echo "$input" | jq -r '.effort.level // "—"')          # absent on models w/o effort
DIR=$(echo "$input"    | jq -r '.workspace.current_dir // .cwd // "."')
COST=$(echo "$input"   | jq -r '.cost.total_cost_usd // 0')
PCT=$(echo "$input"    | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

# ---- cache hit rate (last turn) -------------------------------------------
# rate = cache_read / (input + cache_creation + cache_read); math done in jq
CACHE=$(echo "$input" | jq -r '
  .context_window.current_usage as $u
  | if $u == null then "n/a"
    else ($u.cache_read_input_tokens // 0) as $r
       | (($u.input_tokens // 0) + ($u.cache_creation_input_tokens // 0) + $r) as $t
       | if $t > 0 then "\($r / $t * 100 | floor)%" else "n/a" end
    end')

# ---- git branch (cd into session dir; silent when not a repo) --------------
BRANCH=""
cd "$DIR" 2>/dev/null && BRANCH=$(git branch --show-current 2>/dev/null)

# ---- colors ---------------------------------------------------------------
CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'
DIM='\033[2m';  RESET='\033[0m'

# ---- 10-cell context bar, colored by usage --------------------------------
if   [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else                         BAR_COLOR="$GREEN"; fi

FILLED=$((PCT / 10)); EMPTY=$((10 - FILLED))
[ "$FILLED" -lt 0 ] && FILLED=0; [ "$EMPTY" -lt 0 ] && EMPTY=0
printf -v FILL "%${FILLED}s"; printf -v PAD "%${EMPTY}s"
BAR="${FILL// /█}${PAD// /░}"

COST_FMT=$(printf '$%.2f' "$COST")

BRANCH_SEG=""
[ -n "$BRANCH" ] && BRANCH_SEG=" | 🌿 $BRANCH"

# ---- output (two rows) ----------------------------------------------------
printf '%b\n' "${CYAN}[${MODEL}${RESET}${DIM} · ${EFFORT}${RESET}${CYAN}]${RESET} 📁 ${DIR##*/}${BRANCH_SEG}"
printf '%b\n' "${BAR_COLOR}${BAR}${RESET} ${PCT}% ctx | 💾 ${CACHE} cache | ${YELLOW}${COST_FMT}${RESET}"
