#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Claude Code Status Visualizer — v8.0
# ═══════════════════════════════════════════════════════════
#
# Combined: Context Window Visualizer + color-coded Usage Limits
#
# Pro/Max:  ███████▊████▊█▊███▊█████████████▊████▊  50k/200k  5h 62% ↑2h13m · 7d 88%  Opus 4  [main]
# API key:  ███████▊████▊█▊███▊█████████████▊████▊  50k/200k ($8.44)  Opus 4  [main]
# Line 2:   tools-5k mcp-2k chat-8k (system-15k, skills-1k, memory-2k)

IFS= read -r -d '' input

# ─── Extract all status data (single jq call) ────────────
eval "$(jq -r '
  @sh "model_name=\(.model.display_name // "Unknown")",
  @sh "cwd=\(.workspace.current_dir // .cwd // "")",
  @sh "session_id=\(.session_id // "default")",
  @sh "five_hour_pct=\(.rate_limits.five_hour.used_percentage // -1)",
  @sh "five_hour_resets=\(.rate_limits.five_hour.resets_at // 0)",
  @sh "seven_day_pct=\(.rate_limits.seven_day.used_percentage // -1)",
  @sh "seven_day_resets=\(.rate_limits.seven_day.resets_at // 0)",
  @sh "context_size=\(.context_window.context_window_size // 200000)",
  @sh "used_pct=\(.context_window.used_percentage // 0)",
  @sh "input_tokens=\(.context_window.current_usage.input_tokens // 0)",
  @sh "cache_creation=\(.context_window.current_usage.cache_creation_input_tokens // 0)",
  @sh "cache_read=\(.context_window.current_usage.cache_read_input_tokens // 0)",
  @sh "total_cost=\(.cost.total_cost_usd // 0)"
' <<< "$input" 2>/dev/null)"

# Fallback defaults
: "${model_name:=Unknown}" "${session_id:=default}"
: "${five_hour_pct:=-1}" "${five_hour_resets:=0}"
: "${seven_day_pct:=-1}" "${seven_day_resets:=0}"
: "${context_size:=200000}" "${used_pct:=0}" "${total_cost:=0}"
: "${input_tokens:=0}" "${cache_creation:=0}" "${cache_read:=0}"

# Guard against zero/negative context_size
[ "$context_size" -le 0 ] 2>/dev/null && context_size=200000

# Truncate floats to prevent bash arithmetic crash
five_hour_pct=${five_hour_pct%.*}
seven_day_pct=${seven_day_pct%.*}
five_hour_resets=${five_hour_resets%.*}
seven_day_resets=${seven_day_resets%.*}
used_pct=${used_pct%.*}
input_tokens=${input_tokens%.*}
cache_creation=${cache_creation%.*}
cache_read=${cache_read%.*}

# ─── Git branch detection ─────────────────────────────────
git_branch=""
if [ -n "$cwd" ] && [ -e "$cwd/.git" ]; then
  git_branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

# ─── Time formatting (compact) ────────────────────────────
now=$(date +%s)
format_reset_compact() {
  local resets_at=$1
  [ "$resets_at" -le 0 ] 2>/dev/null && return
  local diff=$((resets_at - now))
  if [ $diff -le 0 ]; then
    echo "now"
    return
  fi
  local days=$((diff / 86400))
  local hours=$(( (diff % 86400) / 3600 ))
  local mins=$(( (diff % 3600) / 60 ))
  if [ $days -gt 0 ]; then
    echo "${days}d${hours}h"
  elif [ $hours -gt 0 ]; then
    echo "${hours}h${mins}m"
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
    # Limit severity — own palette, no overlap with context bar
    c_lim_ok="\033[38;2;220;220;220m"    # #DCDCDC — white/light (healthy)
    c_lim_warn="\033[38;2;255;214;0m"    # #FFD600 — yellow (moderate)
    c_lim_low="\033[38;2;255;140;60m"    # #FF8C3C — warm orange (getting low)
    c_lim_crit="\033[38;2;255;68;68m"    # #FF4444 — red (critical)
    # Metadata — intentionally subdued so they don't compete
    c_dim="\033[38;2;153;153;153m"       # #999999 — stats text
    c_model="\033[3;38;2;153;153;153m"   # #999999 — model name (italic, dim)
    c_branch="\033[38;2;153;153;153m"    # #999999 — git branch (dim)
    c_sep="\033[38;2;120;120;120m"       # #787878 — separator (·)
    c_5h_label="\033[38;2;184;160;212m"  # #B8A0D4 — 5h label (muted lavender)
    c_7d_label="\033[38;2;140;170;210m"  # #8CAAD2 — 7d label (muted blue)
    # Context window bar segments
    c_results="\033[38;2;252;102;177m"   # #FC66B1 — pink (tools)
    c_mcp="\033[38;2;55;243;186m"        # #37F3BA — teal (MCP)
    c_chat="\033[38;2;202;255;68m"       # #CAFF44 — green (chat)
    c_fixed="\033[38;2;153;153;153m"     # #999999 — grey (system)
    c_free="\033[38;2;57;57;57m"         # #393939 — dark grey (free)
    c_buf="\033[38;2;34;34;34m"          # #222222 — near-black (buffer)
    c_warn_y="\033[33m"
    c_warn_r="\033[31m"
    ;;
  256)
    c_lim_ok="\033[38;5;252m"
    c_lim_warn="\033[38;5;220m"
    c_lim_low="\033[38;5;208m"
    c_lim_crit="\033[38;5;196m"
    c_dim="\033[38;5;245m"
    c_model="\033[3;38;5;245m"
    c_branch="\033[38;5;245m"
    c_sep="\033[38;5;242m"
    c_5h_label="\033[38;5;140m"
    c_7d_label="\033[38;5;110m"
    c_results="\033[38;5;205m"
    c_mcp="\033[38;5;49m"
    c_chat="\033[38;5;154m"
    c_fixed="\033[38;5;245m"
    c_free="\033[38;5;237m"
    c_buf="\033[38;5;235m"
    c_warn_y="\033[33m"
    c_warn_r="\033[31m"
    ;;
  basic)
    c_lim_ok="\033[37m"
    c_lim_warn="\033[93m"
    c_lim_low="\033[93m"
    c_lim_crit="\033[91m"
    c_dim="\033[37m"
    c_model="\033[3;37m"
    c_branch="\033[37m"
    c_sep="\033[90m"
    c_5h_label="\033[95m"
    c_7d_label="\033[94m"
    c_results="\033[95m"
    c_mcp="\033[96m"
    c_chat="\033[92m"
    c_fixed="\033[37m"
    c_free="\033[90m"
    c_buf="\033[90m"
    c_warn_y="\033[33m"
    c_warn_r="\033[31m"
    ;;
esac

# ═══════════════════════════════════════════════════════════
# Severity color helper — returns color based on remaining %
# ═══════════════════════════════════════════════════════════

severity_color() {
  local remaining=$1
  if [ $remaining -gt 50 ]; then
    echo "$c_lim_ok"
  elif [ $remaining -gt 30 ]; then
    echo "$c_lim_warn"
  elif [ $remaining -gt 15 ]; then
    echo "$c_lim_low"
  else
    echo "$c_lim_crit"
  fi
}

# Determine if we have rate limits (Pro/Max) or not (API key)
has_limits=0
[ "$five_hour_pct" -ge 0 ] 2>/dev/null && has_limits=1
[ "$seven_day_pct" -ge 0 ] 2>/dev/null && has_limits=1

# ═══════════════════════════════════════════════════════════
# Context Window Visualizer
# ═══════════════════════════════════════════════════════════

# Derived values — prefer exact input_tokens over percentage-based estimate
context_k=$((context_size / 1000))
exact_tokens=$((input_tokens + cache_creation + cache_read))
if [ $exact_tokens -gt 0 ]; then
  tokens_used=$exact_tokens
  used_pct=$((tokens_used * 100 / context_size))
else
  tokens_used=$((used_pct * context_size / 100))
fi

# ─── Fixed overhead (auto-calibrated + dynamic measurement) ─
dir="/tmp/claude-context-tracker"
[ -d "$dir" ] || { mkdir -p "$dir" && chmod 700 "$dir"; } 2>/dev/null
overhead_file="$dir/${session_id}.overhead"
tracker="$dir/${session_id}.json"
state_file="$dir/${session_id}.state"

# ── Dynamic: measure memory files (CLAUDE.md + rules) ──
overhead_memory=0
for f in "$HOME/.claude/CLAUDE.md" "$HOME/.claude/claude.md"; do
  if [ -f "$f" ]; then
    _content=$(<"$f")
    overhead_memory=$((overhead_memory + ${#_content} / 4))
  fi
done
for f in "$HOME/.claude/rules"/*.md; do
  if [ -f "$f" ]; then
    _content=$(<"$f")
    overhead_memory=$((overhead_memory + ${#_content} / 4))
  fi
done
if [ -n "$cwd" ]; then
  for f in "$cwd/CLAUDE.md" "$cwd/.claude/CLAUDE.md"; do
    if [ -f "$f" ]; then
      _content=$(<"$f")
      overhead_memory=$((overhead_memory + ${#_content} / 4))
    fi
  done
  for f in "$cwd/.claude/rules"/*.md; do
    if [ -f "$f" ]; then
      _content=$(<"$f")
      overhead_memory=$((overhead_memory + ${#_content} / 4))
    fi
  done
fi

# ── Dynamic: measure skills (SKILL.md name+description) ──
overhead_skills=0
_skills_chars=0
for f in "$HOME/.claude/skills"/*/SKILL.md "$HOME/.claude/plugins/cache"/*/*/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  _in_fm=0; _name=""; _desc=""
  while IFS= read -r _line; do
    case "$_in_fm" in
      0) [ "$_line" = "---" ] && _in_fm=1 ;;
      1) case "$_line" in
           "---") break ;;
           name:*) _name="${_line#name: }" ;;
           description:*) _desc="${_line#description: }" ;;
         esac ;;
    esac
  done < "$f"
  _skills_chars=$((_skills_chars + ${#_name} + ${#_desc}))
done
overhead_skills=$((_skills_chars / 4))

# ── Auto-calibrate overhead ──
# While no tools have run (calls == 0), each render gives us
# tokens_used ≈ overhead + chat. We take the minimum observation
# across renders (smallest user message = best estimate) and
# subtract a bounded chat estimate.
# Once tools start running, we lock in the calibration.
_calls=0
if [ -f "$tracker" ]; then
  _calls=$(jq -r '.calls // 0' "$tracker" 2>/dev/null)
  _calls=${_calls:-0}
fi

overhead=0
if [ -f "$overhead_file" ]; then
  overhead=$(<"$overhead_file")
  overhead=${overhead%.*}
  [ "$overhead" -gt 0 ] 2>/dev/null || overhead=0
fi

if [ "$_calls" -eq 0 ] && [ $tokens_used -gt 0 ]; then
  # No tools called yet — safe to (re)calibrate.
  # Subtract estimated chat: min(1500, 5% of tokens_used) to avoid
  # inflating overhead when the user sends a long first message.
  chat_est=$((tokens_used * 5 / 100))
  [ $chat_est -gt 1500 ] && chat_est=1500
  new_overhead=$((tokens_used - chat_est))
  [ $new_overhead -lt 10000 ] && new_overhead=10000
  [ $new_overhead -gt 60000 ] && new_overhead=60000
  # Keep the minimum observation — closest to true overhead
  if [ $overhead -eq 0 ] || [ $new_overhead -lt $overhead ]; then
    overhead=$new_overhead
    printf '%d\n' "$overhead" > "$overhead_file"
  fi
elif [ $overhead -eq 0 ]; then
  # Tools have run but no calibration exists (edge case: tracker
  # appeared before first statusline render). Use measured floor.
  overhead=$((overhead_memory + overhead_skills + 15000))
  printf '%d\n' "$overhead" > "$overhead_file"
fi

# ── Ensure overhead covers measured components ──
# If memory/skills grew since calibration, the stored value is stale.
measured_floor=$((overhead_memory + overhead_skills + 10000))
if [ $overhead -lt $measured_floor ]; then
  overhead=$measured_floor
  printf '%d\n' "$overhead" > "$overhead_file"
fi

# ── Legend sub-components ──
overhead_system=$((overhead - overhead_memory - overhead_skills))
# If system < 0, calibration is stale — redistribute proportionally
if [ $overhead_system -lt 0 ]; then
  overhead_system=10000
  overhead=$((overhead_system + overhead_memory + overhead_skills))
  printf '%d\n' "$overhead" > "$overhead_file"
fi

# Autocompact buffer: ~16.5% of context_size (Claude Code's compaction
# threshold — not exposed in the API, so this is an assumption)
buffer=$((context_size * 165 / 1000))

# ─── Read tracker data ──────────────────────────────────
t_agents=0; t_tools=0; t_mcp=0
if [ -f "$tracker" ]; then
  eval "$(jq -r '
    @sh "t_agents=\(.agents // 0)",
    @sh "t_tools=\(.tools // 0)",
    @sh "t_mcp=\(.mcp // 0)"
  ' "$tracker" 2>/dev/null)"
fi
t_results=$((t_agents + t_tools))

# ─── Compaction detection ──────────────────────────────
# The tracker accumulates tokens across the session, but autocompaction
# evicts old content. When tokens_used drops >20%, reset the tracker
# so the bar honestly shows "unknown breakdown" until new tool calls
# rebuild it. This avoids displaying stale cumulative ratios.
prev_tokens=0
if [ -f "$state_file" ]; then
  prev_tokens=$(<"$state_file")
  prev_tokens=${prev_tokens%.*}
  [ "$prev_tokens" -gt 0 ] 2>/dev/null || prev_tokens=0
fi

if [ $prev_tokens -gt 0 ] && [ $tokens_used -lt $((prev_tokens * 80 / 100)) ]; then
  printf '{"agents":0,"tools":0,"mcp":0,"calls":%d}\n' "$_calls" \
    > "${tracker}.tmp" && mv "${tracker}.tmp" "$tracker" 2>/dev/null
  t_agents=0; t_tools=0; t_mcp=0; t_results=0
fi

printf '%d\n' "$tokens_used" > "$state_file" 2>/dev/null

# ─── Compute category breakdown ─────────────────────────
if [ $tokens_used -lt $overhead ]; then
  tokens_used=$overhead
  used_pct=$((tokens_used * 100 / context_size))
fi
tokens_k=$((tokens_used / 1000))

msg_budget=$((tokens_used - overhead))
[ $msg_budget -lt 0 ] && msg_budget=0

# The tracker is cumulative but context is a snapshot. After compaction,
# tracked values may exceed msg_budget. Scale proportionally — use
# tracker values only for the ratio between categories, not absolute
# sizes. Reserve a 15% floor for chat so it doesn't vanish entirely.
tracked=$((t_results + t_mcp))
if [ $tracked -gt 0 ] && [ $tracked -gt $msg_budget ]; then
  chat_floor=$((msg_budget * 15 / 100))
  tool_budget=$((msg_budget - chat_floor))
  if [ $tracked -gt 0 ]; then
    scale=$((tool_budget * 100 / tracked))
  else
    scale=0
  fi
  t_results=$((t_results * scale / 100))
  t_mcp=$((t_mcp * scale / 100))
  tracked=$((t_results + t_mcp))
fi

t_chat=$((msg_budget - tracked))
[ $t_chat -lt 0 ] && t_chat=0

free=$((context_size - tokens_used - buffer))
[ $free -lt 0 ] && free=0

# ─── Build 36-char stacked bar ──────────────────────────
ctx_bar_len=36

seg_vals=($t_results $t_mcp $t_chat $overhead $free $buffer)
seg_colors=("$c_results" "$c_mcp" "$c_chat" "$c_fixed" "$c_free" "$c_buf")

bar_chars=()
total_bar=0
for i in "${!seg_vals[@]}"; do
  v=${seg_vals[$i]}
  if [ $v -gt 0 ] && [ $context_size -gt 0 ]; then
    c=$((v * ctx_bar_len / context_size))
    if [ $c -eq 0 ]; then
      case $i in
        2|3|4|5) c=1 ;;
      esac
    fi
  else
    c=0
  fi
  bar_chars+=($c)
  total_bar=$((total_bar + c))
done

# Adjust to exactly ctx_bar_len
diff=$((total_bar - ctx_bar_len))
if [ $diff -ne 0 ]; then
  free_orig=${bar_chars[4]}
  adj=$((free_orig - diff))
  if [ $adj -ge 0 ]; then
    bar_chars[4]=$adj
  else
    bar_chars[4]=0
    overflow=$((diff - free_orig))
    buf_orig=${bar_chars[5]}
    bar_chars[5]=$((buf_orig - overflow))
    if [ ${bar_chars[5]} -lt 0 ]; then
      remaining=$(( -${bar_chars[5]} ))
      bar_chars[5]=0
      bar_chars[3]=$((bar_chars[3] - remaining))
      [ ${bar_chars[3]} -lt 1 ] && bar_chars[3]=1
    fi
  fi
fi

# Context warning indicator
ctx_warn=""
if [ "$used_pct" -ge 85 ]; then
  ctx_warn=" ${c_warn_r}[/clear]${reset}"
elif [ "$used_pct" -ge 70 ]; then
  ctx_warn=" ${c_warn_y}!${reset}"
fi

# Format cost
cost_fmt=$(printf '$%.2f' "$total_cost" 2>/dev/null || echo "\$$total_cost")

# ─── RENDER LINE 1: Context bar + stats + limits + model + branch ───
BLOCKS="████████████████████████████████████"  # 36 █ chars
for i in "${!seg_vals[@]}"; do
  n=${bar_chars[$i]}
  [ $n -le 0 ] && continue
  if [ $n -eq 1 ]; then
    printf "${seg_colors[$i]}▊"
  else
    printf "${seg_colors[$i]}%s▊" "${BLOCKS:0:$((n-1))}"
  fi
done
printf "${reset}"

# Token counts
printf "${c_fixed}  %dk/%dk${reset}" "$tokens_k" "$context_k"

# Cost only for API key users (no rate limits)
if [ $has_limits -eq 0 ]; then
  printf "${c_fixed} (%s)${reset}" "$cost_fmt"
fi

printf "%b" "$ctx_warn"

# Inline color-coded usage limits
if [ "$five_hour_pct" -ge 0 ] 2>/dev/null; then
  five_remaining=$((100 - five_hour_pct))
  five_color=$(severity_color $five_remaining)
  five_reset_str=$(format_reset_compact "$five_hour_resets")
  printf "  ${c_5h_label}5h ${reset}${five_color}%d%%${reset}" "$five_remaining"
  [ -n "$five_reset_str" ] && printf "${c_5h_label} ↑%s${reset}" "$five_reset_str"
fi
if [ "$seven_day_pct" -ge 0 ] 2>/dev/null; then
  seven_remaining=$((100 - seven_day_pct))
  seven_color=$(severity_color $seven_remaining)
  seven_reset_str=$(format_reset_compact "$seven_day_resets")
  [ "$five_hour_pct" -ge 0 ] 2>/dev/null && printf "${c_sep} ·${reset}"
  printf " ${c_7d_label}7d ${reset}${seven_color}%d%%${reset}" "$seven_remaining"
  [ -n "$seven_reset_str" ] && printf "${c_7d_label} ↑%s${reset}" "$seven_reset_str"
fi

printf "${c_model}  %s${reset}" "$model_name"
[ -n "$git_branch" ] && printf "  ${c_bold}${c_branch}[%s]${reset}" "$git_branch"

# ─── RENDER LINE 2: Context legend ──────────────────────
legend=""
[ ${bar_chars[0]} -gt 0 ] && legend="${legend}${c_results}tools-$((t_results / 1000))k${reset} "
[ ${bar_chars[1]} -gt 0 ] && legend="${legend}${c_mcp}mcp-$((t_mcp / 1000))k${reset} "
[ ${bar_chars[2]} -gt 0 ] && legend="${legend}${c_chat}chat-$((t_chat / 1000))k${reset} "
legend="${legend}${c_fixed}(system-$((overhead_system / 1000))k, skills-$((overhead_skills / 1000))k, memory-$((overhead_memory / 1000))k)${reset}"
printf "\n%b" "$legend"

exit 0
