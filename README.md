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

The agent backs up `settings.json`, installs the script to `~/.local/bin`, wraps your statusline (or patches it, if you prefer), adds the `PreToolUse` and `UserPromptSubmit` hooks, and verifies without arming anything. If a running session doesn't halt in a later test, restart it. Uninstall steps are at the end of `SETUP.md`.

## Use

```sh
claude-usage 5h 30%                  # stop when 5-hour usage reaches 30%
claude-usage 7d 40%                  # stop when weekly usage reaches 40%
claude-usage at 07:00                # stop at the next 07:00 (today if still ahead, else tomorrow)
claude-usage at 25-12-2026 07:00     # stop at a date and time (DD-MM-YYYY HH:MM)
claude-usage at 2026-12-25 07:00     # same, YYYY-MM-DD HH:MM
claude-usage 5h 30% 7d 40% at 07:00  # any mix: whichever is hit first stops every session
claude-usage status
claude-usage off                     # disarm everything and lift a block
claude-usage help
claude-usage --warn 50,80 5h 30%     # change the warning steps (default 95; `--warn none` turns them off)
claude-usage --session <id> at 07:00 # arm for one session only, for testing; never touches the global arm
```

Times are 24-hour local time, in exactly those three formats; anything else is rejected, as is a date and time already past. Every limit is validated before anything is armed.

Arming is one-shot. When a limit trips, the switch disarms and every session is halted before its next tool call and refuses new prompts. A usage stop lifts when its window resets; a time stop holds until you run `claude-usage off`. Sessions resume with `claude --resume`.

## Warnings before the limit

Each armed limit also warns once, at 95% of the way to it (a 30% limit warns at 29%), once per window; the warning point is always at least one point below the limit. A time limit warns at 95% of the way from arming to the deadline, and at least 2 minutes before it. `--warn 50,80` sets other steps. The warning goes to the agents themselves: each session gets a note as extra context on its next tool call or prompt, telling it to finish or checkpoint, commit work in progress and not start long tasks, so overnight work lands cleanly before the hard stop. If you jump past several steps at once, only the highest is announced.

To also reach yourself, put a shell command in `~/.claude/usage-notify`; it receives the message as `$1`, for example `slack-ping "$1"`. There is no desktop banner for warnings by default.

## How it works

Claude Code hands the statusline `rate_limits` on every render, but hooks never see usage. A time limit needs no render: while one is armed, the hooks compare the clock on every tool call and prompt (a few ms each). The statusline wrapper forks a background `check` only while armed (about 5 ms, off the render path). A trip writes `~/.claude/usage-stop.json`, and the hooks return `continue:false` while it is live (about 2 ms per tool call when idle).

`rate_limits` only appears for claude.ai Pro/Max subscriptions (or a gateway with spend limits); on a plain API key the switch can never trip.

Headless `claude -p` sessions never render a statusline, so an interactive session must be open for a crossing to be detected; the hook then stops headless ones too.
