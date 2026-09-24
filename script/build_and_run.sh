#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
case "$MODE" in
  run|--debug|--logs|--telemetry|--verify) ;;
  *) echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac

APP_NAME="AugmaDesktopDemo"
BUNDLE_ID="cn.yunyoujun.augma.desktop-demo"
MIN_SYSTEM_VERSION="15.0"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/apps/mac"
APP_BUNDLE="$PACKAGE_DIR/dist/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_BINARY="$APP_CONTENTS/MacOS/$APP_NAME"

# An installed Xcode can require license acceptance; Command Line Tools can
# build this SwiftPM demo without modifying the user's Xcode installation.
if [[ -z "${DEVELOPER_DIR:-}" ]] && ! /usr/bin/xcodebuild -version >/dev/null 2>&1; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
pnpm --filter @augma/ar exec vite build --base ./
swift build --package-path "$PACKAGE_DIR" --product "$APP_NAME"
BUILD_DIR="$(swift build --package-path "$PACKAGE_DIR" --show-bin-path)"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_CONTENTS/MacOS" "$APP_CONTENTS/Resources/ar"
cp "$BUILD_DIR/$APP_NAME" "$APP_BINARY"
cp -R "$ROOT_DIR/apps/ar/dist/." "$APP_CONTENTS/Resources/ar/"
chmod +x "$APP_BINARY"
cat >"$APP_CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>Augma</string>
  <key>CFBundleDisplayName</key><string>Augma</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSMicrophoneUsageDescription</key><string>用于识别你主动说出的 Augma 语音指令。</string>
  <key>NSSpeechRecognitionUsageDescription</key><string>用于将你主动说出的指令转换为文字并操作演示界面。</string>
</dict>
</plist>
PLIST

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run) open_app ;;
  --debug) lldb -- "$APP_BINARY" ;;
  --logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify)
    open_app
    pgrep -f "$APP_BINARY" >/dev/null
    swift "$ROOT_DIR/script/verify-mac-window.swift"
    echo "$APP_NAME launched: $APP_BUNDLE"
    ;;
esac
