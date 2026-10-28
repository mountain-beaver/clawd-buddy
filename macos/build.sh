#!/bin/bash
# Builds build/ClawdBuddy.app (Apple Silicon + Intel binary, generated icon)
set -euo pipefail
cd "$(dirname "$0")"
APP="build/ClawdBuddy.app"
BIN="$APP/Contents/MacOS/ClawdBuddy"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target $arch-apple-macosx13.0 Sources/*.swift -o "build/ClawdBuddy-$arch" \
    -framework AppKit -framework SwiftUI
done
lipo -create build/ClawdBuddy-arm64 build/ClawdBuddy-x86_64 -output "$BIN"
rm build/ClawdBuddy-arm64 build/ClawdBuddy-x86_64
cp Info.plist "$APP/Contents/Info.plist"

"$BIN" make-icon build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP" >/dev/null 2>&1
echo "Built $APP"
