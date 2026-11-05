#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

swift build -c release
BIN=".build/release/SK0124"
APP="$ROOT/SK0124.app"

if [[ ! -f "$ROOT/Resources/AppIcon.icns" || ! -f "$ROOT/Resources/MenuBarIcon.png" ]]; then
  swift "$ROOT/Scripts/make_icon.swift" "$ROOT"
  iconutil -c icns "$ROOT/Resources/AppIcon.iconset" -o "$ROOT/Resources/AppIcon.icns"
  rm -rf "$ROOT/Resources/AppIcon.iconset"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/SK0124"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/Resources/MenuBarIcon.png" "$APP/Contents/Resources/MenuBarIcon.png"
cp "$ROOT/Resources/MenuBarIcon@2x.png" "$APP/Contents/Resources/MenuBarIcon@2x.png"
codesign -s - --force --deep "$APP"
echo "Built $APP"
