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
MICROSOFT_CLIENT_ID="${AUGMA_MICROSOFT_CLIENT_ID:-}"
if [[ -n "$MICROSOFT_CLIENT_ID" && ! "$MICROSOFT_CLIENT_ID" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]]; then
  echo "AUGMA_MICROSOFT_CLIENT_ID must be a Microsoft Application (Client) ID." >&2
  exit 2
fi
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/augma-build.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

# An installed Xcode can require license acceptance; Command Line Tools can
# build this SwiftPM demo without modifying the user's Xcode installation.
if [[ -z "${DEVELOPER_DIR:-}" ]] && ! /usr/bin/xcodebuild -version >/dev/null 2>&1; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi
# SwiftPM hands the SDK to the clang linker as --sysroot, from which clang can't read
# the SDK version, so the binary records its deployment target as the SDK and macOS 26
# runs it with the pre-26 look instead of Liquid Glass. -isysroot records the real SDK.
SDK_FLAGS=(-Xswiftc -Xclang-linker -Xswiftc -isysroot -Xswiftc -Xclang-linker -Xswiftc "$(xcrun --sdk macosx --show-sdk-path)")

# A download package is a universal release build; local runs stay fast debug builds.
BUILD_FLAGS=(--package-path "$PACKAGE_DIR" -c debug "${SDK_FLAGS[@]}")
if [[ "$MODE" == "--package" ]]; then
  BUILD_FLAGS=(--package-path "$PACKAGE_DIR" -c release --arch arm64 --arch x86_64 "${SDK_FLAGS[@]}")
else
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  # Give the app time to flush native notes/drafts before replacing its bundle.
  for attempt in {1..50}; do
    pgrep -x "$APP_NAME" >/dev/null || break
    sleep 0.1
  done
  if pgrep -x "$APP_NAME" >/dev/null; then
    echo "Augma is still running. Resolve any unsaved-data prompt before rebuilding." >&2
    exit 1
  fi
fi
# Internal modules are native. Web browsing loads user-requested URLs at runtime.
swift build "${BUILD_FLAGS[@]}" --product "$APP_NAME"
BUILD_DIR="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_CONTENTS/MacOS" "$APP_CONTENTS/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_BINARY"
# String tables live outside the SwiftPM target so SwiftUI finds them in the main bundle.
cp -R "$PACKAGE_DIR/Localization/." "$APP_CONTENTS/Resources/"
chmod +x "$APP_BINARY"
# assets/brand is a pinned copy of YunLeFun/icons assets/apps/augma/v1.
node "$ROOT_DIR/scripts/sync-app-icon.mjs" --check
ICONSET="$WORK_DIR/AppIcon.iconset"
swift "$ROOT_DIR/script/create_app_icon.swift" "$ROOT_DIR/assets/brand/augma-app-icon.svg" "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP_CONTENTS/Resources/AppIcon.icns"
# macOS 26 reads the layered Icon Composer icon (default, dark, clear, tinted)
# from Assets.car via CFBundleIconName; AppIcon.icns above stays the fallback.
# Compiling .icon files needs Xcode 26+, so older toolchains keep only the icns.
ACTOOL_MAJOR="$(xcrun actool --version 2>/dev/null | sed -n '/short-bundle-version/{n;s/.*<string>\([0-9]*\).*/\1/p;}')"
if [[ "${ACTOOL_MAJOR:-0}" -ge 26 ]]; then
  ICON_BUILD_DIR="$WORK_DIR/Augma.icon-build"
  mkdir -p "$ICON_BUILD_DIR"
  xcrun actool "$ROOT_DIR/assets/brand/Augma.icon" --compile "$ICON_BUILD_DIR" \
    --platform macosx --target-device mac --minimum-deployment-target "$MIN_SYSTEM_VERSION" \
    --app-icon Augma --output-partial-info-plist "$ICON_BUILD_DIR/partial.plist" \
    --errors --warnings --output-format human-readable-text >/dev/null
  cp "$ICON_BUILD_DIR/Assets.car" "$APP_CONTENTS/Resources/Assets.car"
  ICON_NAME_KEY='<key>CFBundleIconName</key><string>Augma</string>'
else
  echo "warning: actool ${ACTOOL_MAJOR:-unknown} cannot compile Augma.icon (needs Xcode 26+); using AppIcon.icns only" >&2
  ICON_NAME_KEY=''
fi
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
  <key>CFBundleIconFile</key><string>AppIcon</string>
  $ICON_NAME_KEY
  <key>LSMinimumSystemVersion</key><string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>AugmaMicrosoftClientID</key><string>$MICROSOFT_CLIENT_ID</string>
  <key>CFBundleURLTypes</key>
  <array><dict>
    <key>CFBundleURLName</key><string>Microsoft sign-in</string>
    <key>CFBundleURLSchemes</key><array><string>msauth.cn.yunyoujun.augma.desktop-demo</string></array>
  </dict></array>
  <key>NSAppTransportSecurity</key>
  <dict><key>NSAllowsArbitraryLoadsInWebContent</key><true/></dict>
  <key>NSCameraUsageDescription</key><string>用于在你主动开启摄像头时预览画面和拍照，照片仅在你选择保存后写入本机。</string>
  <key>NSCameraUseContinuityCameraDeviceType</key><true/>
  <key>NSMicrophoneUsageDescription</key><string>用于识别你主动说出的 Augma 语音指令。</string>
  <key>NSSpeechRecognitionUsageDescription</key><string>用于将你主动说出的指令转换为文字并操作演示界面。</string>
  <key>NSAppleEventsUsageDescription</key><string>用于将你主动发送的快速记录保存到 macOS 备忘录。</string>
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
