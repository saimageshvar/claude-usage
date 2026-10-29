#!/bin/bash
# claude-usage installer (private repo): needs an authenticated `gh` and `jq`.
set -euo pipefail
command -v gh >/dev/null || { echo "gh is required (brew install gh && gh auth login)" >&2; exit 1; }
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
gh api repos/saimageshvar/claude-usage/contents/claude-usage -H 'Accept: application/vnd.github.raw' > "$tmp"
bash "$tmp" install
