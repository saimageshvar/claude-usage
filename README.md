# claude-usage

A kill switch for Claude Code: stop every running session when your 5h or weekly usage crosses a threshold.

## What's here

| File | What it is |
|---|---|
| `claude-usage` | The whole tool, one bash script. `5h`/`7d` arm it, `status` and `off` manage it, and `statusline`, `check` and `hook` are what Claude Code calls |
| `SETUP.md` | Step-by-step instructions for a Claude Code agent to wire it into your machine |
| `README.md` | This file |

## Install

Setup touches your `statusLine` and hooks in `~/.claude/settings.json`, so an agent does it: it reads your existing config, adapts, and asks before each edit. Needs `jq`; `terminal-notifier` is optional, for a banner when it fires. In any directory:

```sh
claude "Set up claude-usage by following https://raw.githubusercontent.com/saimageshvar/claude-usage/main/SETUP.md"
```

The agent backs up `settings.json`, installs the script to `~/.local/bin`, wraps your statusline (or patches it, if you prefer), adds the `PostToolUse` hook, and verifies without arming anything. Restart running sessions afterwards. Uninstall steps are at the end of `SETUP.md`.

## Use

```sh
claude-usage 5h 30%     # arm: stop everything when 5h usage >= 30%
claude-usage 7d 10%     # arm the weekly window too; whichever trips first fires
claude-usage status
claude-usage off        # disarm and lift a block
```

Arming is one-shot. When a limit trips, the switch disarms and every tool call in every session (subagents included) is halted until the tripped window resets or you run `claude-usage off`. Sessions resume with `claude --resume`.

## How it works

Claude Code hands the statusline `rate_limits` on every render, but hooks never see usage. The statusline wrapper forks a background `check` only while armed (about 5 ms, off the render path). A trip writes `~/.claude/usage-stop.json`, and the `PostToolUse` hook returns `continue:false` while it is live (about 2 ms per tool call when idle).

Headless `claude -p` sessions never render a statusline, so an interactive session must be open for a crossing to be detected; the hook then stops headless ones too.
