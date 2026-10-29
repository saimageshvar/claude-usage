# Setting up claude-usage (instructions for a Claude Code agent)

You are installing `claude-usage`, a kill switch that halts every Claude Code session when 5h or 7d usage crosses a threshold. It needs two hooks into the user's Claude Code config: something that sees the statusline JSON (the only place usage percentages appear), and a `PostToolUse` hook that halts sessions. You are editing the user's live config, so explain each change before making it and ask before each edit to `settings.json` or to their statusline script.

## 1. Preflight

- `command -v jq` must succeed; if not, tell the user to install it (`brew install jq` or their package manager) and stop.
- `terminal-notifier` is optional (macOS banner when it fires); mention it, don't install it.
- Back up `~/.claude/settings.json` to `~/.claude/settings.json.bak-claude-usage` before any edit.

## 2. Install the script

```sh
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/saimageshvar/claude-usage/main/claude-usage -o ~/.local/bin/claude-usage
chmod +x ~/.local/bin/claude-usage
```

If `~/.local/bin` is not on `PATH`, tell the user; don't edit their shell rc.

## 3. Feed it the statusline JSON

Read `statusLine` in `~/.claude/settings.json` and offer the user these options, recommending the first that applies:

- **No statusLine set:** set `"statusLine": {"type": "command", "command": "~/.local/bin/claude-usage statusline"}`.
- **statusLine runs the user's own command** (wrapper, recommended): their script stays untouched. Save the existing command string, unchanged, to `~/.claude/usage-orig-statusline`, then set `statusLine.command` to `~/.local/bin/claude-usage statusline`. The wrapper runs the saved command with the same stdin and prints its output unchanged.
- **Patch their script instead** (if they prefer no wrapper): add these lines right after the script reads stdin into `$input`:
  ```sh
  printf '%s' "$input" > ~/.claude/usage-last.json
  if [ -f ~/.claude/usage-kill.json ]; then
      read -r a b ra rb < <(jq -r '.rate_limits | [(.five_hour.used_percentage // 0 | round), (.seven_day.used_percentage // 0 | round), (.five_hour.resets_at // 0), (.seven_day.resets_at // 0)] | join(" ")' <<<"$input")
      ~/.local/bin/claude-usage check "$a" "$b" "$ra" "$rb" >/dev/null 2>&1 &
  fi
  ```
  The check must run in the background so it never delays rendering.

## 4. Add the halting hook

Append to `hooks.PostToolUse` in `~/.claude/settings.json` (create the key if missing; keep every existing entry):

```json
{"hooks": [{"type": "command", "command": "[ ! -f ~/.claude/usage-stop.json ] || ~/.local/bin/claude-usage hook", "timeout": 5}]}
```

Edit with `jq` to a temp file, check that it parses, then move it into place. Never overwrite unrelated keys.

## 5. Verify without arming anything real

1. Pipe a sample payload through the statusline command and confirm the user's original statusline output is unchanged and `~/.claude/usage-last.json` exists:
   `echo '{"rate_limits":{"five_hour":{"used_percentage":1,"resets_at":1999999999},"seven_day":{"used_percentage":1,"resets_at":1999999999}}}' | ~/.local/bin/claude-usage statusline`
2. `claude-usage status` prints `not armed`.
3. Write a fake stop flag, confirm the hook halts, then clear it:
   `echo '{"reason":"setup test","until":'$(( $(date +%s)+60 ))'}' > ~/.claude/usage-stop.json; echo '{}' | claude-usage hook; claude-usage off`
   The hook must print JSON containing `"continue":false`, and `claude-usage off` must clear the flag.

## 6. Report

Tell the user what you changed (files and lines), that running sessions must be restarted to pick up the new statusline and hook, and show usage: `claude-usage 5h 30%`, `claude-usage 7d 10%`, `claude-usage status`, `claude-usage off`.

## Uninstall

Restore `statusLine.command` from `~/.claude/usage-orig-statusline` (or delete the `statusLine` key if that file is empty or absent), remove the `claude-usage hook` entry from `hooks.PostToolUse`, then delete `~/.local/bin/claude-usage` and `~/.claude/usage-*`.
