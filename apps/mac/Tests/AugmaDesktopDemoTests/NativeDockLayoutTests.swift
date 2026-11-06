import AppKit
import SwiftUI
import ScreenCaptureKit
import XCTest
@testable import AugmaDesktopDemo

private final class DockShadowTestPanel: NSPanel {
  override var canBecomeKey: Bool { true }
}

final class NativeDockLayoutTests: XCTestCase {
  @MainActor
  func testActiveDockGlassShadowFadesBeforeEveryWindowEdge() async throws {
    guard let directory = ProcessInfo.processInfo.environment["AUGMA_RENDER_DOCK_DIR"] else {
      throw XCTSkip("Set AUGMA_RENDER_DOCK_DIR to verify active Dock shadow pixels")
    }
    guard let screen = NSScreen.main, CGPreflightScreenCaptureAccess() else {
      throw XCTSkip("An active display and screen capture access are required")
    }
    let suite = "augma.dock.shadow.\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let dock = NativeDockStore(defaults: defaults)
    let preferences = NativePreferencesStore(defaults: defaults)
    let session = NativeDemoModel(preferences: preferences, dock: dock)
    defer { session.closeScene() }
    let camera = NativeCameraStore()
    try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
    for (count, width) in [(12, CGFloat(1000)), (24, CGFloat(400)), (60, screen.visibleFrame.width)] {
      fill(dock, count: count)
      let viewport = CGRect(x: screen.visibleFrame.midX - width / 2, y: screen.visibleFrame.minY,
                            width: width, height: screen.visibleFrame.height)
      let frame = ImmersiveLayout.windowFrame(for: .dock, in: viewport, dockItemCount: count, dockBottomInset: 160)
      let panel = DockShadowTestPanel(contentRect: frame, styleMask: [.borderless],
                          backing: .buffered, defer: false)
      panel.isOpaque = false
      panel.backgroundColor = .clear
      panel.hasShadow = false
      panel.level = .statusBar
      panel.hidesOnDeactivate = false
      panel.contentView = ImmersiveChromeHosting.view(
        ImmersiveDockView(session: session, preferences: preferences, camera: camera, dock: dock, select: { _ in }), for: .dock)
      defer { panel.orderOut(nil) }
      for appearance in [NSAppearance.Name.aqua, .darkAqua] {
        panel.appearance = NSAppearance(named: appearance)
        panel.makeKeyAndOrderFront(nil)
        try await Task.sleep(for: .milliseconds(250))
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        let window = try XCTUnwrap(content.windows.first { $0.windowID == CGWindowID(panel.windowNumber) })
        let configuration = SCStreamConfiguration()
        configuration.width = Int(panel.frame.width * 2)
        configuration.height = Int(panel.frame.height * 2)
        configuration.showsCursor = false
        let captured = try await SCScreenshotManager.captureImage(
          contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: configuration)
        let bitmap = NSBitmapImageRep(cgImage: captured)
        let w = bitmap.pixelsWide, h = bitmap.pixelsHigh
        let perimeter = (0..<w).flatMap { [(x: $0, y: 0), (x: $0, y: h - 1)] }
          + (0..<h).flatMap { [(x: 0, y: $0), (x: w - 1, y: $0)] }
        let edgeAlpha = perimeter.compactMap { bitmap.colorAt(x: $0.x, y: $0.y)?.alphaComponent }.max() ?? 0
        XCTAssertLessThanOrEqual(edgeAlpha, 1.0 / 255,
          "Dock glass and its adaptive shadow must fade to transparent before every rectangular window edge")
        let layout = ImmersiveLayout.frame(for: .dock, in: viewport, dockItemCount: count, dockBottomInset: 160)
        let metrics = NativeDockMetrics(itemCount: count, availableWidth: layout.width)
        let glassCenter = CGPoint(x: layout.midX, y: layout.minY + metrics.verticalPadding + metrics.iconSize / 2)
        let scale = CGFloat(h) / panel.frame.height
        let centerY = Int((panel.frame.maxY - glassCenter.y) * scale)
        XCTAssertGreaterThan(try XCTUnwrap(bitmap.colorAt(x: w / 2, y: centerY)).alphaComponent, 0.1)
        let visiblePixels = (0..<w).filter { (bitmap.colorAt(x: $0, y: centerY)?.alphaComponent ?? 0) > 0.2 }
        let first = try XCTUnwrap(visiblePixels.first), last = try XCTUnwrap(visiblePixels.last)
        XCTAssertEqual(CGFloat(last - first + 1) / scale, layout.width, accuracy: 2,
          "Shadow drawing space must not steal width from the actual Dock surface")
        for point in [CGPoint(x: layout.minX - 2, y: glassCenter.y),
                      CGPoint(x: layout.maxX + 2, y: glassCenter.y),
                      CGPoint(x: layout.midX, y: layout.minY - 2)] {
          XCTAssertNotEqual(NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0), panel.windowNumber,
            "The added transparent drawing space must let clicks reach the window underneath")
        }
        XCTAssertEqual(NSWindow.windowNumber(at: glassCenter, belowWindowWithWindowNumber: 0), panel.windowNumber)
        let filename = "dock-shadow-\(count)-\(appearance.rawValue).png"
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
          .write(to: URL(fileURLWithPath: directory).appending(path: filename))
      }
    }
  }

  func testDefaultDockGapMatchesTheVisibleTopControls() {
    let screen = CGRect(x: -1440, y: 100, width: 1440, height: 900)
    let top = ImmersiveLayout.frame(for: .voice, in: screen)
    let dock = ImmersiveLayout.frame(for: .dock, in: screen)
    // Corner glass has a one-point outer inset; Dock glass is bottom-aligned.
    XCTAssertEqual(dock.minY - screen.minY, screen.maxY - top.maxY + 1)
  }

  func testCustomDockGapKeepsContentClearOnSmallAndOffsetDisplays() {
    for size in [CGSize(width: 640, height: 480), CGSize(width: 1440, height: 900)] {
      let screen = CGRect(origin: CGPoint(x: -1440, y: 100), size: size)
      for gap: CGFloat in [0, 17, 64, 120] {
        for shelf in [false, true] {
          let dock = ImmersiveLayout.frame(for: .dock, in: screen, dockBottomInset: gap)
          let window = ImmersiveLayout.windowFrame(for: .dock, in: screen, dockBottomInset: gap)
          let content = ImmersiveLayout.content(in: size, menuBarShelfVisible: shelf, clockVisible: true,
                                                dockBottomInset: gap)
          let contentOnScreen = CGRect(x: screen.minX + content.minX, y: screen.maxY - content.maxY,
                                       width: content.width, height: content.height)
          XCTAssertEqual(dock.minY - screen.minY, gap)
          XCTAssertEqual(window.minY + ImmersiveLayout.dockShadowInset, dock.minY)
          XCTAssertEqual(window.insetBy(dx: ImmersiveLayout.dockShadowInset, dy: ImmersiveLayout.dockShadowInset), dock)
          XCTAssertTrue(screen.contains(dock))
          XCTAssertFalse(contentOnScreen.intersects(dock))
          XCTAssertEqual(contentOnScreen.minY - dock.maxY, 12, accuracy: 0.001)
        }
      }
    }
  }

  func testIconsAndSpacingFitAvailableWidthWithoutGrowingBeyondDefaultSize() {
    for count in [1, 12, 24, 40, 80] {
      for width: CGFloat in [320, 640, 1440, 2560, 3840] {
        let metrics = NativeDockMetrics(itemCount: count, availableWidth: width)
        let occupied = CGFloat(count) * metrics.iconSize + CGFloat(count - 1) * metrics.spacing
          + metrics.horizontalPadding * 2
        XCTAssertLessThanOrEqual(occupied, width + 0.001)
        XCTAssertGreaterThan(metrics.iconSize, 0)
        XCTAssertLessThanOrEqual(metrics.iconSize, 44)
        if width >= NativeDockMetrics.preferredWidth(itemCount: count) {
          XCTAssertEqual(metrics.iconSize, 44)
        } else {
          XCTAssertEqual(occupied, width, accuracy: 0.001)
        }
      }
    }
  }

  func testImmersiveDockGrowsUntilItReachesTheScreenMargins() {
    for size in [CGSize(width: 640, height: 480), CGSize(width: 1440, height: 900),
                 CGSize(width: 2560, height: 1440), CGSize(width: 3840, height: 2160)] {
      let screen = CGRect(origin: CGPoint(x: -1440, y: 100), size: size)
      for count in [0, 1, 12, 24, 40, 80] {
        let frame = ImmersiveLayout.frame(for: .dock, in: screen, dockItemCount: count)
        XCTAssertTrue(screen.insetBy(dx: 20, dy: 0).contains(frame))
        XCTAssertEqual(frame.midX, screen.midX, accuracy: 0.001)
        XCTAssertEqual(frame.width, min(NativeDockMetrics.preferredWidth(itemCount: count), size.width - 40))
        if count == 80 {
          XCTAssertEqual(frame.minX, screen.minX + 20)
          XCTAssertEqual(frame.maxX, screen.maxX - 20)
        }
      }
    }
  }

  @MainActor
  func testDockRendersWithAllIconsAtNarrowAndWideWidths() throws {
    let suite = "augma.dock.render.\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let dock = NativeDockStore(defaults: defaults)
    let preferences = NativePreferencesStore(defaults: defaults)
    let session = NativeDemoModel(preferences: preferences, dock: dock)
    defer { session.closeScene() }
    let camera = NativeCameraStore()
    for count in [0, 12, 24, 60] {
      fill(dock, count: count)
      XCTAssertEqual(dock.items.count, count)
      for width in [480, 1280, 2560] {
        let content = ImmersiveDockView(session: session, preferences: preferences, camera: camera, dock: dock, select: { _ in })
          .frame(width: CGFloat(width), height: 88)
          .background(Color(nsColor: .windowBackgroundColor))
        let host = NSHostingView(rootView: content)
        host.frame = NSRect(x: 0, y: 0, width: width, height: 88)
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(host.fittingSize.width, CGFloat(width), accuracy: 1)
        if let directory = ProcessInfo.processInfo.environment["AUGMA_RENDER_DOCK_DIR"] {
          try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
          let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
          host.cacheDisplay(in: host.bounds, to: bitmap)
          try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(to: URL(fileURLWithPath: directory).appending(path: "dock-\(count)-\(width).png"))
        }
      }
    }
  }

  @MainActor
  private func fill(_ dock: NativeDockStore, count: Int) {
    for item in dock.items { dock.remove(item) }
    for index in 0..<count {
      if index < NativeDockItem.allCases.count { dock.restore(NativeDockItem.allCases[index]) }
      else { dock.restore(.plugin(.init(id: "dev.example.fixture\(index)", name: "Fixture \(index)", symbol: "circle"))) }
    }
    XCTAssertEqual(dock.items.count, count)
  }
}
