#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"

APP_PATH="$PWD/build/Tea Panel.app"
BUILD_CACHE="$PWD/build/module-cache"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$BUILD_CACHE"

xcrun swiftc -O -swift-version 6 -target arm64-apple-macosx13.0 \
  -module-cache-path "$BUILD_CACHE" \
  Sources/TeaCore.swift Sources/TeaMotion.swift Sources/TeaViews.swift Sources/TeaPanelApp.swift \
  -o "$APP_PATH/Contents/MacOS/TeaPanel"
cp Resources/Info.plist "$APP_PATH/Contents/Info.plist"
codesign --force --sign - "$APP_PATH"
print "已生成：$APP_PATH"

if [[ "${1:-}" == "--run" ]]; then
  open "$APP_PATH"
fi
