#!/bin/bash
# Removes the app and its Claude Code hooks.
set -euo pipefail
SETTINGS="$HOME/.claude/settings.json"
pkill -x ClawdBuddy 2>/dev/null || true
rm -rf "$HOME/Applications/ClawdBuddy.app"
if [ -f "$SETTINGS" ]; then
  tmp=$(mktemp)
  jq '
    if .hooks then
      .hooks |= (with_entries(.value |= map(select(((.hooks // []) | map(.command // "" | contains("ClawdBuddy")) | any) | not)))
                 | with_entries(select(.value | length > 0)))
      | if (.hooks | length) == 0 then del(.hooks) else . end
    else . end
  ' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
fi
echo "Clawd Buddy removed."
