#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Claude Code Usage Limit Visualizer — v1.0
# ═══════════════════════════════════════════════════════════
#
# Shows API usage limit consumption as colored bars.
# Reads rate_limits from the status line JSON input.
#
# Line 1: 5h ━━━━━━━━━━━━━─────────────────────────  62% left · 2h 13m  $8.44  Opus 4  [main]
# Line 2: 7d ━━━━━━━━──────────────────────────────  38% left · 3d 5h

IFS= read -r -d '' input

# ─── Extract status data (single jq call) ─────────────────
eval "$(jq -r '
  @sh "model_name=\(.model.display_name // "Unknown")",
  @sh "cwd=\(.workspace.current_dir // .cwd // "")",
  @sh "five_hour_pct=\(.rate_limits.five_hour.used_percentage // -1)",
  @sh "five_hour_resets=\(.rate_limits.five_hour.resets_at // 0)",
  @sh "seven_day_pct=\(.rate_limits.seven_day.used_percentage // -1)",
  @sh "seven_day_resets=\(.rate_limits.seven_day.resets_at // 0)"
' <<< "$input" 2>/dev/null)"

# Fallback defaults if jq eval failed
: "${model_name:=Unknown}"
: "${five_hour_pct:=-1}" "${five_hour_resets:=0}"
: "${seven_day_pct:=-1}" "${seven_day_resets:=0}"

# Truncate floats to prevent bash arithmetic crash
five_hour_pct=${five_hour_pct%.*}
seven_day_pct=${seven_day_pct%.*}
five_hour_resets=${five_hour_resets%.*}
seven_day_resets=${seven_day_resets%.*}

# ─── Git branch detection ─────────────────────────────────
git_branch=""
if [ -n "$cwd" ] && [ -e "$cwd/.git" ]; then
  git_branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

# ─── Time formatting ──────────────────────────────────────
now=$(date +%s)
format_reset_time() {
  local resets_at=$1
  [ "$resets_at" -le 0 ] 2>/dev/null && return
  local diff=$((resets_at - now))
  if [ $diff -le 0 ]; then
    echo "resetting"
    return
  fi
  local days=$((diff / 86400))
  local hours=$(( (diff % 86400) / 3600 ))
  local mins=$(( (diff % 3600) / 60 ))
  if [ $days -gt 0 ]; then
    echo "${days}d ${hours}h"
  elif [ $hours -gt 0 ]; then
    echo "${hours}h ${mins}m"
  else
    echo "${mins}m"
  fi
}

# ─── Detect terminal color support ────────────────────────
_cm=basic
case "${COLORTERM-}" in
  truecolor|24bit) _cm=truecolor ;;
  *) case "${TERM-}" in *256color*) _cm=256 ;; esac ;;
esac

# ─── Colors (adaptive to terminal capability) ─────────────
reset="\033[0m"
c_bold="\033[1m"

case $_cm in
  truecolor)
    c_green="\033[38;2;202;255;68m"      # #CAFF44 — plenty left
    c_yellow="\033[38;2;255;214;0m"      # #FFD600 — moderate
    c_orange="\033[38;2;243;155;55m"     # #F39B37 — getting low
    c_red="\033[38;2;255;68;68m"         # #FF4444 — critical
    c_free="\033[38;2;57;57;57m"         # #393939 — remaining (dark)
    c_dim="\033[38;2;153;153;153m"       # #999999 — stats text
    c_model="\033[3;38;2;255;96;68m"     # #FF6044 — model name italic
    c_branch="\033[38;2;243;155;55m"     # #F39B37 — git branch
    c_label="\033[38;2;120;120;120m"     # #787878 — bar labels
    c_7d="\033[38;2;100;180;255m"        # #64B4FF — 7-day accent
    ;;
  256)
    c_green="\033[38;5;154m"
    c_yellow="\033[38;5;220m"
    c_orange="\033[38;5;214m"
    c_red="\033[38;5;196m"
    c_free="\033[38;5;237m"
    c_dim="\033[38;5;245m"
    c_model="\033[3;38;5;202m"
    c_branch="\033[38;5;214m"
    c_label="\033[38;5;242m"
    c_7d="\033[38;5;111m"
    ;;
  basic)
    c_green="\033[92m"
    c_yellow="\033[93m"
    c_orange="\033[93m"
    c_red="\033[91m"
    c_free="\033[90m"
    c_dim="\033[37m"
    c_model="\033[3;91m"
    c_branch="\033[93m"
    c_label="\033[90m"
    c_7d="\033[94m"
    ;;
esac

# ─── Bar rendering ────────────────────────────────────────
# Thin line bar: ━ (used) + ─ (remaining), color shifts by severity.
render_bar() {
  local used_pct=$1
  local bar_len=$2

  # Clamp
  [ $used_pct -lt 0 ] && used_pct=0
  [ $used_pct -gt 100 ] && used_pct=100

  local remaining_pct=$((100 - used_pct))

  # Severity color for the filled (used) portion
  local bar_color
  if [ $remaining_pct -gt 50 ]; then
    bar_color="$c_green"
  elif [ $remaining_pct -gt 30 ]; then
    bar_color="$c_yellow"
  elif [ $remaining_pct -gt 15 ]; then
    bar_color="$c_orange"
  else
    bar_color="$c_red"
  fi

  # Calculate filled chars
  local filled=$((used_pct * bar_len / 100))
  local empty=$((bar_len - filled))

  # Ensure at least 1 char for non-zero segments
  if [ $used_pct -gt 0 ] && [ $filled -eq 0 ]; then
    filled=1; empty=$((bar_len - 1))
  fi
  if [ $remaining_pct -gt 0 ] && [ $empty -eq 0 ]; then
    empty=1; filled=$((bar_len - 1))
  fi

  local THICK="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  local THIN="────────────────────────────────────────"

  # Filled portion (used) — thick line
  [ $filled -gt 0 ] && printf "${bar_color}%s" "${THICK:0:$filled}"

  # Empty portion (remaining) — thin line
  [ $empty -gt 0 ] && printf "${c_free}%s" "${THIN:0:$empty}"

  printf "${reset}"
}

# ─── RENDER ───────────────────────────────────────────────
bar_len=36

if [ "$five_hour_pct" -ge 0 ] 2>/dev/null; then
  # ─── Line 1: 5-hour limit bar ───────────────────────
  five_remaining=$((100 - five_hour_pct))
  five_reset_str=$(format_reset_time "$five_hour_resets")

  printf "${c_label}5h${reset} "
  render_bar "$five_hour_pct" "$bar_len"

  # Warning indicator
  warn=""
  if [ "$five_remaining" -le 5 ]; then
    warn=" ${c_red}${c_bold}[LIMIT]${reset}"
  elif [ "$five_remaining" -le 15 ]; then
    warn=" ${c_red}!${reset}"
  elif [ "$five_remaining" -le 30 ]; then
    warn=" ${c_yellow}!${reset}"
  fi

  printf "${c_dim}  %d%% left" "$five_remaining"
  [ -n "$five_reset_str" ] && printf " · %s" "$five_reset_str"
  printf "${reset}"
  printf "%b" "$warn"

  printf "${c_model}  %s${reset}" "$model_name"
  [ -n "$git_branch" ] && printf "  ${c_bold}${c_branch}[%s]${reset}" "$git_branch"

  # ─── Line 2: 7-day limit (if available) ─────────────
  if [ "$seven_day_pct" -ge 0 ] 2>/dev/null; then
    seven_remaining=$((100 - seven_day_pct))
    seven_reset_str=$(format_reset_time "$seven_day_resets")

    printf "\n${c_label}7d${reset} "
    render_bar "$seven_day_pct" "$bar_len"
    printf "${c_7d}  %d%% left" "$seven_remaining"
    [ -n "$seven_reset_str" ] && printf " · %s" "$seven_reset_str"
    printf "${reset}"
  fi

elif [ "$seven_day_pct" -ge 0 ] 2>/dev/null; then
  # Only 7-day available (no 5-hour)
  seven_remaining=$((100 - seven_day_pct))
  seven_reset_str=$(format_reset_time "$seven_day_resets")

  printf "${c_label}7d${reset} "
  render_bar "$seven_day_pct" "$bar_len"
  printf "${c_7d}  %d%% left" "$seven_remaining"
  [ -n "$seven_reset_str" ] && printf " · %s" "$seven_reset_str"
  printf "${reset}"
  printf "${c_model}  %s${reset}" "$model_name"
  [ -n "$git_branch" ] && printf "  ${c_bold}${c_branch}[%s]${reset}" "$git_branch"

else
  # No rate limit data yet — output nothing so the status line stays hidden
  :
fi

exit 0
