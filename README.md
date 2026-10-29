# claude-usage

A kill switch for Claude Code: stop every running session when your 5h or weekly usage crosses a threshold.

## Install

Needs `gh` (authenticated with access to this repo) and `jq`. `terminal-notifier` is optional, for a banner when it fires.

```sh
gh api repos/saimageshvar/claude-usage/contents/install.sh -H 'Accept: application/vnd.github.raw' | bash
```

It copies `claude-usage` to `~/.local/bin`, wraps your existing `statusLine` command (output unchanged) and adds a `PostToolUse` hook to `~/.claude/settings.json`. Restart running sessions afterwards.

## Use

```sh
claude-usage 5h 30%     # arm: stop everything when 5h usage >= 30%
claude-usage 7d 10%     # arm the weekly window too; whichever trips first fires
claude-usage status
claude-usage off        # disarm and lift a block
claude-usage uninstall  # restore your statusline, remove the hook
```

Arming is one-shot. When a limit trips, the switch disarms and every tool call in every session (subagents included) is halted until the tripped window resets or you run `claude-usage off`. Sessions resume with `claude --resume`.

## How it works

Claude Code hands the statusline `rate_limits` on every render, but hooks never see usage. The statusline wrapper forks a background `check` only while armed (about 5 ms, off the render path). A trip writes `~/.claude/usage-stop.json`, and the `PostToolUse` hook returns `continue:false` while it is live (about 2 ms per tool call when idle).

Headless `claude -p` sessions never render a statusline, so an interactive session must be open for a crossing to be detected; the hook then stops headless ones too.
