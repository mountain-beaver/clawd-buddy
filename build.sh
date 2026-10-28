#!/bin/bash
# Builds build/ClawdBuddy.app (binary + generated icon)
set -euo pipefail
cd "$(dirname "$0")"
APP="build/ClawdBuddy.app"
BIN="$APP/Contents/MacOS/ClawdBuddy"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -swift-version 5 Sources/*.swift -o "$BIN" -framework AppKit -framework SwiftUI
cp Info.plist "$APP/Contents/Info.plist"

"$BIN" make-icon build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP" >/dev/null 2>&1
echo "Built $APP"
