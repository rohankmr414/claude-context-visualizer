# Claude Code Status Visualizer

A statusline for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that shows both your **API usage limits** and **context window breakdown** — so you always know how much capacity you have left.

<img alt="Claude Code Status Visualizer" src="screenshots/demo.png" />


## Install

```bash
curl -fsSL https://raw.githubusercontent.com/rohankmr414/claude-usage-limit-visualizer/main/install.sh | bash
```

Then restart Claude Code.

## Update

To update to the latest version, re-run the install command:

```bash
curl -fsSL https://raw.githubusercontent.com/rohankmr414/claude-usage-limit-visualizer/main/install.sh | bash
```

This overwrites the scripts with the latest version while preserving your `settings.json` configuration.

## What You Get

A status bar at the bottom of every Claude Code session showing:

### Usage Limits (Lines 1–2)

**5-hour limit** (Line 1):

| Color | Meaning | Remaining |
|-------|---------|-----------|
| Green | Plenty left | > 50% |
| Yellow | Moderate | 30–50% |
| Orange | Getting low | 15–30% |
| Red | Critical | < 15% |

**7-day limit** (Line 2, if available):

Same color coding, shown as a second bar below.

**Extras**: remaining percentage, time until reset, model name, git branch, and warnings at 30% (`!`), 15% (`!`), and 5% (`[LIMIT]`).

**Note**: Usage limits are only available for Claude.ai subscribers (Pro/Max). API key users will still see the context window visualization below.

### Context Window (Lines 3–4)

A stacked bar showing how your context window tokens are distributed:

| Color | Segment | Description |
|-------|---------|-------------|
| Pink | tools | Token results from Read, Grep, Bash, etc. |
| Teal | mcp | MCP tool results (Figma, Supabase, Slack, etc.) |
| Green | chat | User messages + assistant responses |
| Grey | system | System prompt, skills, memory files |
| Dark grey | free | Remaining usable space |
| Near-black | buffer | Autocompact buffer (16.5%, reserved) |

**Extras**: tokens used / total, session cost, and a warning at 70% (`!`) or 85% (`[/clear]`).

## How It Works

Two scripts work together:

- **`statusline.sh`** — reads the JSON that Claude Code pipes to `statusLine.command` on stdin. It renders both the usage limit bars (from `rate_limits`) and the context window breakdown (from `context_window` + tracker data).

- **`context-tracker.sh`** — a `PostToolUse` hook that estimates token consumption per tool call and writes running totals to `/tmp/claude-context-tracker/<session>.json`. This powers the tools/mcp/chat breakdown in the context bar.

### Architecture

```
Claude Code
  ├─ statusLine command ──→ statusline.sh ──→ reads JSON + tracker ──→ renders all bars
  └─ PostToolUse hook ────→ context-tracker.sh ──→ writes tracker JSON
```

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (any version with `statusLine` support)
- `jq` — JSON processor (`brew install jq` / `apt install jq`)
- macOS or Linux
- Any terminal — auto-detects color support (truecolor, 256-color, or basic 16-color)
- Claude.ai Pro or Max subscription (for usage limit data; context window works for all users)

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/rohankmr414/claude-usage-limit-visualizer/main/uninstall.sh | bash
```

Or run locally:

```bash
./uninstall.sh
```

This removes both scripts, the tracker hook, and cleans `settings.json`.

## License

MIT
