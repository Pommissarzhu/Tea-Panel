#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"

APP_PATH="$PWD/build/Tea Panel.app"
BUILD_CACHE="$PWD/build/module-cache"
ICONSET_PATH="$PWD/build/AppIcon.iconset"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$BUILD_CACHE"

mkdir -p "$ICONSET_PATH"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" Resources/AppIcon.png \
    --out "$ICONSET_PATH/icon_${size}x${size}.png" >/dev/null
  sips -z "$((size * 2))" "$((size * 2))" Resources/AppIcon.png \
    --out "$ICONSET_PATH/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET_PATH" -o "$APP_PATH/Contents/Resources/AppIcon.icns"

xcrun swiftc -O -swift-version 6 -target arm64-apple-macosx13.0 \
  -module-cache-path "$BUILD_CACHE" \
  Sources/TeaCore.swift Sources/TeaMotion.swift Sources/TeaViews.swift Sources/TeaPanelApp.swift \
  -o "$APP_PATH/Contents/MacOS/TeaPanel"
cp Resources/Info.plist "$APP_PATH/Contents/Info.plist"
for localization_path in Resources/*.lproj; do
  ditto "$localization_path" "$APP_PATH/Contents/Resources/${localization_path:t}"
done
codesign --force --sign - "$APP_PATH"
print "已生成：$APP_PATH"

if [[ "${1:-}" == "--run" ]]; then
  open "$APP_PATH"
fi
