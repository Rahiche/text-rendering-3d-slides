#!/usr/bin/env bash
# Builds the talk as a plain slides app for the conference's archive:
# "Inside Flutter's Text Pipeline.app" opens straight into the talk (the
# booth's kiosk off), without the narration's clips (the presenter's
# voice stays home), zipped beside it.
#   bash booth3d/tool/build_slides_app.sh [--voice] [out dir]   (default: build/share)
#   --voice   the presenter's own copy: the clips kept (F6 plays the talk in
#             their voice). Never one to share.
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="Inside Flutter's Text Pipeline"
VOICE=0
if [ "${1:-}" = "--voice" ]; then VOICE=1; shift; fi
OUT="${1:-../build/share}"

flutter build macos --release --dart-define=NAME_CITY_TALK=1 | grep -E "✓|rror" || true
SRC=build/macos/Build/Products/Release/booth3d.app
mkdir -p "$OUT"
APP="$OUT/$NAME.app"
rm -rf "$APP"
cp -R "$SRC" "$APP"

PLIST="$APP/Contents/Info.plist"
plutil -replace CFBundleName -string "$NAME" "$PLIST"
plutil -replace CFBundleDisplayName -string "$NAME" "$PLIST"
plutil -replace CFBundleIdentifier -string dev.slides.nameCity.talk "$PLIST"
[ "$VOICE" = 1 ] || find "$APP"/Contents/Frameworks/App.framework/Resources/flutter_assets/assets/narration -name '*.mp3' -delete 2>/dev/null || true
codesign --force --deep --sign - --entitlements macos/Runner/Release.entitlements "$APP" 2>&1 | grep -v "replacing existing signature" || true

rm -f "$OUT/$NAME.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/$NAME.zip"
echo "Slides app: $OUT/$NAME.zip"
