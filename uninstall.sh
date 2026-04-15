#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Claude Code Status Visualizer — Uninstaller
# ═══════════════════════════════════════════════════════════
# Removes the statusline, context-tracker, and cleans settings.json.

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"

green="\033[32m"; yellow="\033[33m"; bold="\033[1m"; reset="\033[0m"

info()  { printf "%b[-]%b %s\n" "${bold}${green}" "$reset" "$1"; }
warn()  { printf "%b[!]%b %s\n" "${bold}${yellow}" "$reset" "$1"; }

# ─── Remove scripts ─────────────────────────────────────
if [ -f "$CLAUDE_DIR/statusline.sh" ]; then
  rm "$CLAUDE_DIR/statusline.sh"
  info "Removed statusline.sh"
else
  warn "statusline.sh not found — skipping"
fi

if [ -f "$CLAUDE_DIR/hooks/context-tracker.sh" ]; then
  rm "$CLAUDE_DIR/hooks/context-tracker.sh"
  info "Removed context-tracker.sh"
else
  warn "context-tracker.sh not found — skipping"
fi

# ─── Patch settings.json ─────────────────────────────────
if [ -f "$SETTINGS" ]; then
  # Backup before patching
  backup="${SETTINGS}.backup.$(date +%s)"
  cp "$SETTINGS" "$backup"
  info "Backed up settings.json → $(basename "$backup")"

  # Remove statusLine key
  if jq -e 'has("statusLine")' "$SETTINGS" >/dev/null 2>&1; then
    jq 'del(.statusLine)' "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"
    info "Removed statusLine from settings.json"
  fi

  # Remove context-tracker hook entries
  has_tracker=$(jq '
    (.hooks // {}).PostToolUse // [] |
    map(.hooks // []) | flatten |
    any(.command | tostring | test("context-tracker"))
  ' "$SETTINGS" 2>/dev/null)

  if [ "$has_tracker" = "true" ]; then
    jq '
      .hooks.PostToolUse = [
        .hooks.PostToolUse[] |
        select(
          (.hooks // []) | map(.command | tostring | test("context-tracker")) | any | not
        )
      ] |
      if (.hooks.PostToolUse | length) == 0 then del(.hooks.PostToolUse) else . end |
      if (.hooks | length) == 0 then del(.hooks) else . end
    ' "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"
    info "Removed context-tracker hook from settings.json"
  fi
else
  warn "settings.json not found — skipping"
fi

# ─── Clean up tracker data ───────────────────────────────
if [ -d "/tmp/claude-context-tracker" ]; then
  rm -rf "/tmp/claude-context-tracker"
  info "Cleaned up tracker data"
fi

printf "\n%b✓ Claude Code Status Visualizer uninstalled.%b\n" "${bold}${green}" "$reset"
printf "  Restart Claude Code to apply changes.\n\n"
