#!/bin/bash
# 編譯 release 版並包成 build/Portside.app
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="build/Portside.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/Portside" "$APP/Contents/MacOS/Portside"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"

echo "完成：$APP"
echo "執行：open $APP"
