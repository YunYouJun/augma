#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
case "$MODE" in
  run|--debug|--logs|--telemetry|--verify|--package) ;;
  *) echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--package]" >&2; exit 2 ;;
esac

APP_NAME="AugmaDesktopDemo"
BUNDLE_ID="cn.yunyoujun.augma.desktop-demo"
MIN_SYSTEM_VERSION="15.0"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/apps/mac"
APP_BUNDLE="$PACKAGE_DIR/dist/Augma.app"
ARCHIVE="$PACKAGE_DIR/dist/Augma-macOS.zip"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_BINARY="$APP_CONTENTS/MacOS/$APP_NAME"
VERSION="$(node -p "require('$ROOT_DIR/package.json').version")"

# An installed Xcode can require license acceptance; Command Line Tools can
# build this SwiftPM demo without modifying the user's Xcode installation.
if [[ -z "${DEVELOPER_DIR:-}" ]] && ! /usr/bin/xcodebuild -version >/dev/null 2>&1; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi

# A download package is a universal release build; local runs stay fast debug builds.
BUILD_FLAGS=(--package-path "$PACKAGE_DIR" -c debug)
if [[ "$MODE" == "--package" ]]; then
  BUILD_FLAGS=(--package-path "$PACKAGE_DIR" -c release --arch arm64 --arch x86_64)
else
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
fi
# The AR app imports the built augma package; build it from the current sources first.
pnpm build:lib
pnpm --filter @augma/ar exec vite build --base ./
swift build "${BUILD_FLAGS[@]}" --product "$APP_NAME"
BUILD_DIR="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_CONTENTS/MacOS" "$APP_CONTENTS/Resources/ar"
cp "$BUILD_DIR/$APP_NAME" "$APP_BINARY"
cp -R "$ROOT_DIR/apps/ar/dist/." "$APP_CONTENTS/Resources/ar/"
# String tables live outside the SwiftPM target so SwiftUI finds them in the main bundle.
cp -R "$PACKAGE_DIR/Localization/." "$APP_CONTENTS/Resources/"
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
  <key>CFBundleDevelopmentRegion</key><string>zh-Hans</string>
  <key>CFBundleLocalizations</key><array><string>zh-Hans</string><string>en</string><string>ja</string></array>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
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
  --package)
    # Ad-hoc signature only: macOS asks for confirmation on first open until the
    # app is signed with a Developer ID and notarized.
    codesign --force --sign - "$APP_BUNDLE"
    codesign --verify --strict "$APP_BUNDLE"
    rm -f "$ARCHIVE" "$ARCHIVE.sha256"
    ditto -c -k --keepParent "$APP_BUNDLE" "$ARCHIVE"
    (cd "$(dirname "$ARCHIVE")" && shasum -a 256 "$(basename "$ARCHIVE")" >"$ARCHIVE.sha256")
    echo "Packaged Augma $VERSION: $ARCHIVE"
    ;;
esac
