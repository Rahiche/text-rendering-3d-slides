#!/usr/bin/env bash
# The scroll lab (lib/lab/scroll_lab.dart: hanging scrolls of vertical
# writing on a washing line in a field) as a Mac app of its own, apart from
# Name City and the talk: ~/Applications/Scroll Lab.app, opened.
#   bash booth3d/tool/build_scroll_lab.sh
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="Scroll Lab"
flutter build macos --release --dart-define=BOOTH3D_LAB=scrolls | grep -E "✓|rror" || true
SRC=build/macos/Build/Products/Release/booth3d.app
APP="$HOME/Applications/$NAME.app"
osascript -e "quit app \"$NAME\"" 2>/dev/null || true
rm -rf "$APP"
cp -R "$SRC" "$APP"

PLIST="$APP/Contents/Info.plist"
plutil -replace CFBundleName -string "$NAME" "$PLIST"
plutil -replace CFBundleDisplayName -string "$NAME" "$PLIST"
plutil -replace CFBundleIdentifier -string dev.slides.nameCity.scrollLab "$PLIST"
# (No voice in it: the narration's clips stay with the talk.)
find "$APP"/Contents/Frameworks/App.framework/Resources/flutter_assets/assets/narration -name '*.mp3' -delete 2>/dev/null || true
codesign --force --deep --sign - --entitlements macos/Runner/Release.entitlements "$APP" 2>&1 | grep -v "replacing existing signature" || true
open "$APP" && echo "Scroll Lab: $APP"
