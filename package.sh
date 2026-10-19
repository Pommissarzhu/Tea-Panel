#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"

APP_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
if [[ ! "$APP_VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
  print -u2 "应用版本必须使用 major.minor.patch 格式：$APP_VERSION"
  exit 1
fi

APP_PATH="$PWD/build/Tea Panel.app"
DMG_NAME="Tea-Panel-${APP_VERSION}-Apple-Silicon.dmg"
DMG_PATH="$PWD/dist/$DMG_NAME"

zsh build.sh
codesign --verify --deep --strict "$APP_PATH"

mkdir -p dist
PACKAGE_STAGE=$(mktemp -d "$PWD/build/dmg-stage.XXXXXX")
trap 'rm -rf "$PACKAGE_STAGE"' EXIT
ditto "$APP_PATH" "$PACKAGE_STAGE/Tea Panel.app"
ln -s /Applications "$PACKAGE_STAGE/Applications"
cp LICENSE "$PACKAGE_STAGE/LICENSE.txt"

hdiutil create -volname "Tea Panel" -srcfolder "$PACKAGE_STAGE" \
  -fs HFS+ -format UDZO -ov "$DMG_PATH"
hdiutil verify "$DMG_PATH"
(
  cd dist
  shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
)

print "已生成：$DMG_PATH"
print "校验文件：$DMG_PATH.sha256"
