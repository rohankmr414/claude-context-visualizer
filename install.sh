#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Claude Usage Limit Visualizer — Installer
# ═══════════════════════════════════════════════════════════
# One-line install:
#   curl -fsSL https://raw.githubusercontent.com/GLaDO8/claude-context-visualizer/main/install.sh | bash
#
# What it does:
#   1. Downloads statusline.sh
#   2. Patches ~/.claude/settings.json to wire it up
#
# Prerequisites: jq, curl, Claude Code

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/GLaDO8/claude-context-visualizer/main"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"

# ─── Colors ───────────────────────────────────────────────
red="\033[31m"; green="\033[32m"; yellow="\033[33m"; bold="\033[1m"; reset="\033[0m"

info()  { printf "%b[+]%b %s\n" "${bold}${green}" "$reset" "$1"; }
warn()  { printf "%b[!]%b %s\n" "${bold}${yellow}" "$reset" "$1"; }
error() { printf "%b[x]%b %s\n" "${bold}${red}" "$reset" "$1"; exit 1; }

# ─── Prerequisites ────────────────────────────────────────
command -v jq   >/dev/null 2>&1 || error "jq is required. Install with: brew install jq (macOS) or apt install jq (Linux)"
command -v curl >/dev/null 2>&1 || error "curl is required."

# ─── Create directories ──────────────────────────────────
mkdir -p "$CLAUDE_DIR"

# ─── Download script ─────────────────────────────────────
info "Downloading statusline.sh..."
curl -fsSL "$REPO_RAW/statusline.sh" -o "$CLAUDE_DIR/statusline.sh"
chmod +x "$CLAUDE_DIR/statusline.sh"

# ─── Patch settings.json ─────────────────────────────────
# Create settings.json if it doesn't exist
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
  info "Created new settings.json"
fi

# Backup before patching
backup="${SETTINGS}.backup.$(date +%s)"
cp "$SETTINGS" "$backup"
info "Backed up settings.json → $(basename "$backup")"

# Add statusLine (skip if already present)
if jq -e 'has("statusLine")' "$SETTINGS" >/dev/null 2>&1; then
  warn "statusLine already configured — skipping"
else
  jq '. + {"statusLine": {"type": "command", "command": "~/.claude/statusline.sh"}}' \
    "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"
  info "Added statusLine config"
fi

# ─── Clean up old context-tracker hook if present ─────────
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
  info "Removed old context-tracker hook"
fi

# Remove old context-tracker script if present
if [ -f "$CLAUDE_DIR/hooks/context-tracker.sh" ]; then
  rm "$CLAUDE_DIR/hooks/context-tracker.sh"
  info "Removed old context-tracker.sh"
fi

# Clean up old tracker data
if [ -d "/tmp/claude-context-tracker" ]; then
  rm -rf "/tmp/claude-context-tracker"
  info "Cleaned up old tracker data"
fi

# ─── Done ─────────────────────────────────────────────────
printf "\n%b✓ Claude Usage Limit Visualizer installed!%b\n" "${bold}${green}" "$reset"
printf "\n  Restart Claude Code to see the statusline.\n"
printf "  The bar shows your API usage limit with color-coded severity:\n"
printf "    %bgreen%b = plenty left  %byellow%b = moderate  %borange%b = getting low  %bred%b = critical\n\n" \
  "$bold" "$reset" "$bold" "$reset" "$bold" "$reset" "$bold" "$reset"
printf "  Note: Usage limits are only available for Claude.ai subscribers (Pro/Max).\n\n"
