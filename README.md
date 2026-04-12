# Claude Usage Limit Visualizer

A statusline for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that shows your API usage limit as a colored bar — so you always know how much capacity you have left.

<img width="full" height="full" alt="Frame 21" src="https://github.com/user-attachments/assets/298c0ae0-afeb-4d99-8257-18bc920f5837" />


## Install

```bash
curl -fsSL https://raw.githubusercontent.com/GLaDO8/claude-context-visualizer/main/install.sh | bash
```

Then restart Claude Code.

## Update

To update to the latest version, re-run the install command:

```bash
curl -fsSL https://raw.githubusercontent.com/GLaDO8/claude-context-visualizer/main/install.sh | bash
```

This overwrites the script with the latest version while preserving your `settings.json` configuration.

## What You Get

A status bar at the bottom of every Claude Code session showing your usage limits:

**5-hour limit** (Line 1):

| Color | Meaning | Remaining |
|-------|---------|-----------|
| Green | Plenty left | > 50% |
| Yellow | Moderate | 30–50% |
| Orange | Getting low | 15–30% |
| Red | Critical | < 15% |

**7-day limit** (Line 2, if available):

Same color coding, shown as a second bar below.

**Extras**: remaining percentage, time until reset, session cost, model name, git branch, and warnings at 30% (`!`), 15% (`!`), and 5% (`[LIMIT]`).

**Note**: Usage limits are only available for Claude.ai subscribers (Pro/Max). API key users will see a minimal status with cost and model info.

## How It Works

A single script — **`statusline.sh`** — reads the JSON that Claude Code pipes to the `statusLine.command` on stdin. It extracts `rate_limits.five_hour` and `rate_limits.seven_day` usage percentages and renders them as colored bars with reset countdowns.

### Architecture

```
Claude Code
  └─ statusLine command ──→ statusline.sh ──→ reads rate_limits JSON ──→ renders bars
```

No hooks needed — all data comes directly from the status line input.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (any version with `statusLine` support)
- `jq` — JSON processor (`brew install jq` / `apt install jq`)
- macOS or Linux
- Any terminal — auto-detects color support (truecolor, 256-color, or basic 16-color)
- Claude.ai Pro or Max subscription (for usage limit data)

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/GLaDO8/claude-context-visualizer/main/uninstall.sh | bash
```

Or run locally:

```bash
./uninstall.sh
```

This removes the script and cleans `settings.json`.

## License

MIT
