#!/bin/bash
# Builds the app, installs it to ~/Applications and wires it into Claude Code hooks.
set -euo pipefail
cd "$(dirname "$0")"
./build.sh

DEST="$HOME/Applications/ClawdBuddy.app"
pkill -x ClawdBuddy 2>/dev/null || true
mkdir -p "$HOME/Applications"
rm -rf "$DEST"
cp -R build/ClawdBuddy.app "$DEST"

SETTINGS="$HOME/.claude/settings.json"
CMD="\"$DEST/Contents/MacOS/ClawdBuddy\" hook"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
[ -f "$SETTINGS.bak-clawdbuddy" ] || cp "$SETTINGS" "$SETTINGS.bak-clawdbuddy"
OUT=$(mktemp)

# Drop any previous ClawdBuddy entries, then add ours (other hooks are kept).
# Written to a temp file first, so settings.json survives if jq can't parse it.
jq --arg cmd "$CMD" '
  def ours: {type: "command", command: $cmd, async: true, timeout: 5};
  .hooks //= {}
  | reduce ("SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUseFailure", "Stop", "Notification") as $e (.;
      .hooks[$e] = (
        ((.hooks[$e] // []) | map(select(((.hooks // []) | map(.command // "" | contains("ClawdBuddy")) | any) | not)))
        + [ if ($e == "PreToolUse" or $e == "PostToolUseFailure") then {matcher: "*", hooks: [ours]} else {hooks: [ours]} end ]
      ))
' "$SETTINGS" > "$OUT" || { rm -f "$OUT"; echo "Could not parse $SETTINGS, hooks not added" >&2; exit 1; }
mv "$OUT" "$SETTINGS"

open "$DEST"
echo "Installed to $DEST"
echo "Hooks added to $SETTINGS (backup: $SETTINGS.bak-clawdbuddy)"
