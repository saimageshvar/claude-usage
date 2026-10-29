# Setting up claude-usage (instructions for a Claude Code agent)

You are installing `claude-usage`, a kill switch that halts every Claude Code session when 5h or 7d usage crosses a threshold. It needs two hooks into the user's Claude Code config: something that sees the statusline JSON (the only place usage percentages appear), and hooks that halt sessions. You are editing the user's live config, so explain each change before making it and ask before each edit to `settings.json` or to their statusline script. Each step below is idempotent: check whether it is already done before doing it.

`rate_limits` only appears for claude.ai Pro/Max subscriptions (or a gateway with spend limits). If the user is on a plain API key, tell them the switch can never trip, and stop.

## 1. Preflight

- `command -v jq` must succeed; if not, tell the user to install it (`brew install jq` or their package manager) and stop.
- `terminal-notifier` is optional (macOS banner when it fires); mention it, don't install it.
- Back up `~/.claude/settings.json` to `~/.claude/settings.json.bak-claude-usage` before any edit.

## 2. Install the script

Download it, show the user the script (or at least summarize what it does), and only then make it executable:

```sh
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/saimageshvar/claude-usage/main/claude-usage -o ~/.local/bin/claude-usage
chmod +x ~/.local/bin/claude-usage
```

Check `PATH` with `case ":$PATH:" in *":$HOME/.local/bin:"*) echo on-path;; *) echo off-path;; esac`. If it is off, tell the user; don't edit their shell rc. Use the full path `~/.local/bin/claude-usage` for every command below.

## 3. Feed it the statusline JSON

Read `statusLine` in `~/.claude/settings.json`.

If `statusLine.command` already contains `claude-usage statusline`, this step is done; skip it. Never save the wrapper as its own original command: it would call itself forever.

The saved original may start with `~`; that is fine, because the wrapper runs it through `bash -c`. Otherwise offer the user these options, recommending the first that applies:

- **No statusLine set:** set `"statusLine": {"type": "command", "command": "~/.local/bin/claude-usage statusline"}`. Warn the user that any custom statusline hides most of Claude Code's footer hints, and this wrapper prints nothing of its own.
- **statusLine runs the user's own command** (wrapper, recommended): their script stays untouched. Save the existing command string, unchanged, to `~/.claude/usage-orig-statusline`, then set `statusLine.command` to `~/.local/bin/claude-usage statusline`. The wrapper runs the saved command with `bash -c` and the same stdin, and prints its output unchanged.
- **Patch their script instead** (only for a bash script that reads stdin into `$input`; otherwise use the wrapper): add these lines right after that read:
  ```sh
  printf '%s' "$input" > ~/.claude/usage-last.json
  if [ -f ~/.claude/usage-kill.json ]; then
      read -r a b ra rb < <(jq -r '.rate_limits | [(.five_hour.used_percentage // 0 | round), (.seven_day.used_percentage // 0 | round), (.five_hour.resets_at // 0), (.seven_day.resets_at // 0)] | join(" ")' <<<"$input")
      ~/.local/bin/claude-usage check "$a" "$b" "$ra" "$rb" >/dev/null 2>&1 &
  fi
  ```
  The check must run in the background so it never delays rendering.

## 4. Add the halting hooks

Add one entry to each of `hooks.PreToolUse` and `hooks.UserPromptSubmit` in `~/.claude/settings.json` (create the keys if missing; keep every existing entry; skip an event if an entry containing `claude-usage hook` is already there):

```json
{"hooks": [{"type": "command", "command": "[ ! -f ~/.claude/usage-stop.json ] || ~/.local/bin/claude-usage hook", "timeout": 5}]}
```

Use no `matcher`, so the hook applies to every tool, even if the user's other PreToolUse entries have one. The hooks are live as soon as the file is saved, which matters for step 5. PreToolUse halts a session before its next tool or subagent starts. UserPromptSubmit stops a halted session from being restarted by a new prompt. Edit with `jq` to a temp file, check that it parses, then move it into place. Never overwrite unrelated keys.

## 5. Verify without arming anything real

1. Pipe a sample payload through the wrapper (or your patched script) and confirm the user's original statusline output is unchanged and `~/.claude/usage-last.json` exists:
   `echo '{"rate_limits":{"five_hour":{"used_percentage":1,"resets_at":1999999999},"seven_day":{"used_percentage":1,"resets_at":1999999999}}}' | ~/.local/bin/claude-usage statusline`
   This overwrites `usage-last.json` with fake 1% values until the next real statusline render (seconds, in any live session). Don't arm a limit before then.
2. `~/.local/bin/claude-usage status` prints `not armed`.
3. Test the hook as a single command in one tool call (the hooks are already live, so a flag left behind would halt you; it self-clears after 60 s):
   `echo '{"reason":"setup test","until":'$(( $(date +%s)+60 ))'}' > ~/.claude/usage-stop.json; echo '{"hook_event_name":"PreToolUse"}' | ~/.local/bin/claude-usage hook; ~/.local/bin/claude-usage off`
   The hook must print JSON containing `"continue":false` and `"permissionDecision":"deny"`, and `off` must clear the flag.

## 6. Report

Tell the user what you changed (files and lines) and show usage: `~/.local/bin/claude-usage 5h 30%`, `7d 10%`, `status`, `off`. Settings edits are normally picked up live; if a session doesn't halt in a later test, restart it.

## Uninstall

Restore `statusLine.command` from `~/.claude/usage-orig-statusline` (or delete the `statusLine` key if that file is empty or absent) and remove any lines you patched into their script. Remove the `claude-usage hook` entries from `hooks.PreToolUse` and `hooks.UserPromptSubmit`, then delete `~/.local/bin/claude-usage` and the files `usage-kill.json`, `usage-stop.json`, `usage-last.json` and `usage-orig-statusline` in `~/.claude`. The `settings.json.bak-claude-usage` backup is yours to keep or delete.
