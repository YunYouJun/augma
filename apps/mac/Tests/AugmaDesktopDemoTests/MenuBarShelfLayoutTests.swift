import AppKit
import SwiftUI
import ScreenCaptureKit
import XCTest
@testable import AugmaDesktopDemo

final class MenuBarShelfLayoutTests: XCTestCase {
  @MainActor
  func testImmersiveShelfFollowsEachDisplayAndHidesWithItsOwner() async throws {
    guard MenuBarShelfDisplay.current() != nil else { throw XCTSkip("An active notched display is required") }
    let suite = "augma.shelf.presentation.\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(true, forKey: MenuBarShelfStore.enabledKey)
    let store = MenuBarShelfStore(defaults: defaults)
    for screen in NSScreen.screens {
      store.showInImmersive(on: screen)
      XCTAssertTrue(store.isShowing)
      XCTAssertTrue(store.isPresentedInImmersive)
      let window = try XCTUnwrap(store.immersiveWindow)
      XCTAssertEqual(window.frame, MenuBarShelfLayout.windowFrame(for:
        MenuBarShelfLayout.immersiveFrame(in: screen.visibleFrame)))
      let content = window.contentView
      for clockVisible in [true, false] {
        store.showInImmersive(on: screen, clockVisible: clockVisible)
        XCTAssertTrue(store.immersiveWindow === window)
        XCTAssertTrue(window.contentView === content, "Changing the clock must preserve the shelf's mounted controls")
        XCTAssertEqual(window.frame, MenuBarShelfLayout.windowFrame(for:
          MenuBarShelfLayout.immersiveFrame(in: screen.visibleFrame, clockVisible: clockVisible)))
      }
      store.hideFromImmersive()
      XCTAssertFalse(store.isShowing)
      XCTAssertFalse(store.isPresentedInImmersive)
      XCTAssertFalse(window.isVisible)
      XCTAssertNil(store.immersiveWindow)
    }
    await store.shutdown()
  }

  /// The active glass shadow is composed by WindowServer, so cacheDisplay alone cannot catch it.
  /// Opt in to real window capture with AUGMA_RENDER_SHELF_DIR=/tmp/augma-shelf-render.
  @MainActor
  func testActiveGlassPreservesItsShadowWithoutClippingAtTheWindowBoundary() async throws {
    guard let directory = ProcessInfo.processInfo.environment["AUGMA_RENDER_SHELF_DIR"] else {
      throw XCTSkip("Set AUGMA_RENDER_SHELF_DIR to verify the active glass pixels")
    }
    guard let notchedScreen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }),
          CGPreflightScreenCaptureAccess() else {
      throw XCTSkip("An active notched display and screen capture access are required")
    }
    let suite = "augma.shelf.shadow.\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(true, forKey: MenuBarShelfStore.enabledKey)
    let store = MenuBarShelfStore(defaults: defaults)
    let panel = MenuBarShelfPanel(store: store)
    defer { panel.hide() }
    try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
    let presentations = NSScreen.screens.map { (screen: $0, compact: true) }
      + [(screen: notchedScreen, compact: false)]
    for (screen, compact) in presentations {
      for appearance in [NSAppearance.Name.aqua, .darkAqua] {
        panel.show(in: compact ? screen : nil)
        let window = try XCTUnwrap(panel.window)
        window.appearance = NSAppearance(named: appearance)
        window.makeKeyAndOrderFront(nil)
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertFalse(window.hasShadow)
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        let target = try XCTUnwrap(content.windows.first { $0.windowID == CGWindowID(window.windowNumber) })
        let configuration = SCStreamConfiguration()
        configuration.width = Int(window.frame.width * 2)
        configuration.height = Int(window.frame.height * 2)
        configuration.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(
          contentFilter: SCContentFilter(desktopIndependentWindow: target), configuration: configuration)
        let bitmap = NSBitmapImageRep(cgImage: image)
        let width = bitmap.pixelsWide, height = bitmap.pixelsHigh
        for (x, y) in [(0, 0), (width / 2, 0), (width - 1, 0), (0, height / 2),
                       (width - 1, height / 2), (0, height - 1), (width / 2, height - 1), (width - 1, height - 1)] {
          XCTAssertLessThanOrEqual(try XCTUnwrap(bitmap.colorAt(x: x, y: y)).alphaComponent, 1.0 / 255,
            "Active glass must not leave a shadow cut off at the rectangular window edge")
        }
        XCTAssertGreaterThan(try XCTUnwrap(bitmap.colorAt(x: width / 2, y: height / 2)).alphaComponent, 0.1,
          "The glass surface must remain visible")
        let shelfFrame = MenuBarShelfLayout.shelfFrame(in: window.frame)
        let scale = CGFloat(height) / window.frame.height
        let inset = compact ? MenuBarShelfLayout.compactInset : MenuBarShelfLayout.expandedInset
        let glassBottom = Int((window.frame.maxY - shelfFrame.minY - inset) * scale)
        let shadowRows = (glassBottom + Int(2 * scale))..<min(height, glassBottom + Int(12 * scale))
        let shadowOpacity = shadowRows.compactMap { bitmap.colorAt(x: width / 2, y: $0)?.alphaComponent }.max() ?? 0
        XCTAssertGreaterThan(shadowOpacity, 0.01, "Preserve the system glass shadow outside the rounded surface")
        for point in [CGPoint(x: window.frame.minX + 2, y: window.frame.midY),
                      CGPoint(x: shelfFrame.midX, y: shelfFrame.minY - 2),
                      CGPoint(x: shelfFrame.midX, y: shelfFrame.minY - 18)] {
          XCTAssertNotEqual(NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0), window.windowNumber,
            "The shadow must let clicks reach the window underneath")
        }
        XCTAssertEqual(NSWindow.windowNumber(at: CGPoint(x: shelfFrame.midX, y: shelfFrame.midY), belowWindowWithWindowNumber: 0), window.windowNumber,
          "The visible shelf must remain interactive")
        let filename = "shelf-active-\(compact ? "compact" : "expanded")-\(Int(screen.frame.minX))-\(appearance.rawValue).png"
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
          .write(to: URL(fileURLWithPath: directory).appending(path: filename))
        panel.hide()
      }
    }
    await store.shutdown()
  }

  func testImmersiveShelfStaysCenteredAndClearOfChromeAndContentOnOffsetDisplays() {
    for size in [CGSize(width: 640, height: 480), CGSize(width: 831, height: 600), CGSize(width: 832, height: 600),
                 CGSize(width: 1440, height: 900), CGSize(width: 2560, height: 1440)] {
      for origin in [CGPoint.zero, CGPoint(x: -1440, y: 120), CGPoint(x: 500, y: -900)] {
        for clockVisible in [false, true] {
          let screen = CGRect(origin: origin, size: size)
          let shelf = MenuBarShelfLayout.immersiveFrame(in: screen, clockVisible: clockVisible)
          XCTAssertTrue(screen.insetBy(dx: 20, dy: 0).contains(shelf))
          XCTAssertEqual(shelf.midX, screen.midX, accuracy: 0.001)
          for chrome in ImmersiveLayout.Chrome.allCases where chrome != .clock || clockVisible {
            XCTAssertFalse(shelf.intersects(ImmersiveLayout.frame(for: chrome, in: screen)))
          }
          let content = ImmersiveLayout.content(in: size, menuBarShelfVisible: true, clockVisible: clockVisible)
          let contentOnScreen = CGRect(x: screen.minX + content.minX, y: screen.maxY - content.maxY,
                                       width: content.width, height: content.height)
          XCTAssertFalse(shelf.intersects(contentOnScreen))
          XCTAssertEqual(shelf.minY - contentOnScreen.maxY, 16, accuracy: 0.001)
          XCTAssertEqual(content.maxY, ImmersiveLayout.content(in: size).maxY, accuracy: 0.001)
        }
      }
    }
  }

  func testHidingClockReclaimsTheTopRowWhenTheShelfFitsBetweenCornerControls() {
    let screen = CGRect(x: -1440, y: 120, width: 1440, height: 900)
    let compact = MenuBarShelfLayout.immersiveFrame(in: screen)
    let stacked = MenuBarShelfLayout.immersiveFrame(in: screen, clockVisible: true)
    XCTAssertGreaterThan(compact.minY, stacked.minY)
    let compactContent = ImmersiveLayout.content(in: screen.size, menuBarShelfVisible: true)
    let stackedContent = ImmersiveLayout.content(in: screen.size, menuBarShelfVisible: true, clockVisible: true)
    XCTAssertEqual(compactContent.height - stackedContent.height, compact.minY - stacked.minY)
    let narrowScreen = CGRect(x: 0, y: 0, width: 640, height: 480)
    XCTAssertEqual(MenuBarShelfLayout.immersiveFrame(in: narrowScreen),
                   MenuBarShelfLayout.immersiveFrame(in: narrowScreen, clockVisible: true))
  }

  @MainActor
  func testCompactShelfAndWideStatusIconRenderWithinTheirFrames() throws {
    let suite = "augma.shelf.render.\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = MenuBarShelfStore(defaults: defaults)
    for width: CGFloat in [320, 600, 760] {
      let host = NSHostingView(rootView: MenuBarShelfView(store: store, compact: true))
      host.frame = CGRect(x: 0, y: 0, width: width, height: MenuBarShelfLayout.immersiveHeight)
      host.layoutSubtreeIfNeeded()
      XCTAssertLessThanOrEqual(host.fittingSize.height, MenuBarShelfLayout.immersiveHeight + 1)
      try render(host, name: "shelf-\(Int(width))")
    }
    let image = NSImage(size: CGSize(width: 100, height: 22), flipped: false) { rect in
      NSColor.systemCyan.setFill()
      rect.fill()
      return true
    }
    let item = MenuBarShelfItem(window: .init(id: 1, ownerPID: 7, title: "CPU",
      frame: CGRect(x: 300, y: 0, width: 100, height: 33), layer: 25, isOnScreen: true),
      applicationPID: 10, applicationName: "Monitor", bundleID: "fixture.monitor", detail: "CPU")
    let host = NSHostingView(rootView: MenuBarShelfItemView(item: item, image: image, compact: true, open: {}))
    host.frame = CGRect(x: 0, y: 0, width: 108, height: 36)
    host.layoutSubtreeIfNeeded()
    XCTAssertEqual(host.fittingSize.width, 108, accuracy: 1)
    XCTAssertEqual(host.fittingSize.height, 36, accuracy: 1)
    try render(host, name: "shelf-wide-status-icon")
  }

  @MainActor private func render(_ host: NSView, name: String) throws {
    guard let directory = ProcessInfo.processInfo.environment["AUGMA_RENDER_SHELF_DIR"] else { return }
    try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
    host.cacheDisplay(in: host.bounds, to: bitmap)
    try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
      .write(to: URL(fileURLWithPath: directory).appending(path: "\(name).png"))
  }
}
