#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/augma-shelf-fixture.XXXXXX")"
WORK_DIR="$(cd "$WORK_DIR" && pwd -P)"
FIXTURE_APP="$WORK_DIR/ShelfFixture.app"
FIXTURE_PID=""
cleanup() {
  if [[ -n "$FIXTURE_PID" ]]; then kill -TERM "$FIXTURE_PID" 2>/dev/null || true; fi
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT
mkdir -p "$FIXTURE_APP/Contents/MacOS"
swiftc "$ROOT_DIR/apps/mac/Support/MenuBarShelfFixture/main.swift" -o "$FIXTURE_APP/Contents/MacOS/ShelfFixture"
cat > "$FIXTURE_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>cn.yunyoujun.augma.shelf-fixture</string><key>CFBundleExecutable</key><string>ShelfFixture</string><key>CFBundleName</key><string>Augma Shelf Fixture</string><key>NSPrincipalClass</key><string>NSApplication</string><key>LSUIElement</key><true/></dict></plist>
PLIST
open -n -g "$FIXTURE_APP"
for attempt in {1..30}; do
  FIXTURE_PID="$(pgrep -f "^$FIXTURE_APP/Contents/MacOS/ShelfFixture$" || true)"
  [[ -n "$FIXTURE_PID" ]] && break
  sleep 0.1
done
if [[ -z "$FIXTURE_PID" ]]; then echo "Could not launch the native menu fixture" >&2; exit 1; fi
AUGMA_MENU_BAR_SHELF_INTEGRATION=1 swift test --package-path "$ROOT_DIR/apps/mac" --filter MenuBarShelfIntegrationTests
