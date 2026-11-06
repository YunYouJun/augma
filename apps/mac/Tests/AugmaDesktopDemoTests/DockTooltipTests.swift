import AppKit
import ScreenCaptureKit
import XCTest
@testable import AugmaDesktopDemo

final class DockTooltipTests: XCTestCase {
  @MainActor
  func testSwitchingIconsUpdatesTheSamePanelImmediatelyAcrossGaps() async throws {
    let (window, first, second) = try fixture()
    let session = DockTooltipSession()
    defer { session.dismiss(); window.orderOut(nil) }

    session.enter(title: "ChatGPT", anchor: first)
    XCTAssertNil(tooltip(in: window), "The first hover keeps a short delay")
    try await Task.sleep(for: .milliseconds(280))
    let panel = try XCTUnwrap(tooltip(in: window))
    XCTAssertTrue(panel.isVisible)
    let firstWidth = panel.frame.width
    let content = panel.contentView

    session.leave(anchor: first)
    session.enter(title: "Visual Studio Code", anchor: second)
    session.leave(anchor: first) // A late exit from the previous icon must not hide the new label.
    XCTAssertTrue(tooltip(in: window) === panel)
    XCTAssertTrue(panel.contentView === content)
    XCTAssertTrue(panel.isVisible, "An adjacent icon must show synchronously")
    XCTAssertGreaterThan(panel.frame.width, firstWidth)
    XCTAssertEqual(panel.frame.midX, window.convertToScreen(second.frame).midX, accuracy: 1)
    try await Task.sleep(for: .milliseconds(120))
    XCTAssertTrue(panel.isVisible)

    session.leave(anchor: second)
    try await Task.sleep(for: .milliseconds(120))
    XCTAssertFalse(panel.isVisible, "A gap should not leave a stale label on screen")
    session.enter(title: "ChatGPT", anchor: first)
    XCTAssertTrue(panel.isVisible, "The hover session stays ready while the pointer is inside the Dock")

    session.dismiss() // Leaving the entire Dock resets the initial delay.
    XCTAssertFalse(panel.isVisible)
    XCTAssertNil(panel.parent)
    session.enter(title: "ChatGPT", anchor: first)
    XCTAssertFalse(panel.isVisible)
  }

  @MainActor
  func testCancelledHoverAndWindowChangesCannotLeaveAnOrphanTooltip() async throws {
    let (window, first, second) = try fixture()
    let session = DockTooltipSession()
    defer { session.dismiss(); window.orderOut(nil) }

    session.enter(title: "ChatGPT", anchor: first)
    session.leave(anchor: first)
    try await Task.sleep(for: .milliseconds(280))
    XCTAssertNil(tooltip(in: window))

    session.enter(title: "ChatGPT", anchor: first)
    try await Task.sleep(for: .milliseconds(280))
    let panel = try XCTUnwrap(tooltip(in: window))
    XCTAssertFalse(panel.canBecomeKey)
    XCTAssertTrue(panel.ignoresMouseEvents)

    NotificationCenter.default.post(name: NSWindow.didResizeNotification, object: window)
    XCTAssertFalse(panel.isVisible)
    XCTAssertNil(panel.parent)
    session.enter(title: "ChatGPT", anchor: first)
    XCTAssertFalse(panel.isVisible, "Resizing resets the hover delay")
    session.remove(anchor: first)
    try await Task.sleep(for: .milliseconds(280))
    XCTAssertFalse(panel.isVisible)

    session.enter(title: "ChatGPT", anchor: second)
    try await Task.sleep(for: .milliseconds(280))
    XCTAssertTrue(panel.isVisible)
    NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
    XCTAssertFalse(panel.isVisible)
    XCTAssertNil(panel.parent)
  }

  @MainActor
  func testSeparateDocksDoNotShareTheHoverDelay() async throws {
    let (window, first, second) = try fixture()
    let session = DockTooltipSession()
    let other = DockTooltipSession()
    defer { session.dismiss(); other.dismiss(); window.orderOut(nil) }
    session.enter(title: "ChatGPT", anchor: first)
    try await Task.sleep(for: .milliseconds(280))
    let panel = try XCTUnwrap(tooltip(in: window))
    other.enter(title: "Visual Studio Code", anchor: second)
    XCTAssertEqual(window.childWindows?.count, 1)
    XCTAssertTrue(tooltip(in: window) === panel)
  }

  @MainActor
  func testGlassTooltipFitsScreenEdgesAndPreservesItsShadow() async throws {
    guard let directory = ProcessInfo.processInfo.environment["AUGMA_RENDER_DOCK_DIR"],
          let screen = NSScreen.main, CGPreflightScreenCaptureAccess() else {
      throw XCTSkip("Set AUGMA_RENDER_DOCK_DIR with screen capture access to verify tooltip glass")
    }
    let (window, first, _) = try fixture()
    let session = DockTooltipSession()
    defer { session.dismiss(); window.orderOut(nil) }
    try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
    for appearance in [NSAppearance.Name.aqua, .darkAqua] {
      window.appearance = NSAppearance(named: appearance)
      for edge in ["center", "left", "right"] {
        session.dismiss()
        first.setFrameOrigin(CGPoint(x: edge == "left" ? 0 : edge == "right" ? window.frame.width - 44 : 140, y: 12))
        window.setFrameOrigin(CGPoint(
          x: edge == "left" ? screen.visibleFrame.minX : edge == "right" ? screen.visibleFrame.maxX - window.frame.width : screen.visibleFrame.midX - window.frame.width / 2,
          y: screen.visibleFrame.minY + 180))
        session.enter(title: edge == "center" ? "ChatGPT" : String(repeating: "Visual Studio Code ", count: 20), anchor: first)
        try await Task.sleep(for: .milliseconds(400))
        let panel = try XCTUnwrap(tooltip(in: window))
        XCTAssertTrue(screen.visibleFrame.contains(panel.frame), "Long titles must stay on the current screen")
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        let target = try XCTUnwrap(content.windows.first { $0.windowID == CGWindowID(panel.windowNumber) })
        let configuration = SCStreamConfiguration()
        configuration.ignoreShadowsSingleWindow = true
        configuration.scalesToFit = true
        // Capture only the tooltip; otherwise ScreenCaptureKit also fits its parent Dock into the image.
        configuration.includeChildWindows = false
        configuration.width = Int(panel.frame.width * 2)
        configuration.height = Int(panel.frame.height * 2)
        configuration.showsCursor = false
        let filter = SCContentFilter(desktopIndependentWindow: target)
        let captured = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        let bitmap = NSBitmapImageRep(cgImage: captured)
        let w = bitmap.pixelsWide, h = bitmap.pixelsHigh
        let perimeter = (0..<w).flatMap { [(x: $0, y: 0), (x: $0, y: h - 1)] }
          + (0..<h).flatMap { [(x: 0, y: $0), (x: w - 1, y: $0)] }
        XCTAssertLessThanOrEqual(perimeter.compactMap { bitmap.colorAt(x: $0.x, y: $0.y)?.alphaComponent }.max() ?? 0,
                                 1.0 / 255, "Glass shadows must fade before the rectangular panel boundary")
        XCTAssertGreaterThan(try XCTUnwrap(bitmap.colorAt(x: w / 2, y: h / 2)).alphaComponent, 0.1)
        XCTAssertNotEqual(NSWindow.windowNumber(at: panel.frame.origin, belowWindowWithWindowNumber: 0), panel.windowNumber)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to:
          URL(fileURLWithPath: directory).appending(path: "dock-tooltip-\(edge)-\(appearance.rawValue).png"))
      }
    }
  }

  @MainActor
  private func fixture() throws -> (NSWindow, NSView, NSView) {
    _ = NSApplication.shared
    let screen = try XCTUnwrap(NSScreen.main)
    let window = NSPanel(contentRect: CGRect(x: screen.visibleFrame.midX - 200,
      y: screen.visibleFrame.minY + 180, width: 400, height: 68),
      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.level = .statusBar
    window.isOpaque = false
    window.backgroundColor = .clear
    let first = NSView(frame: CGRect(x: 140, y: 12, width: 44, height: 44))
    let second = NSView(frame: CGRect(x: 194, y: 12, width: 44, height: 44))
    window.contentView?.addSubview(first)
    window.contentView?.addSubview(second)
    window.orderFront(nil)
    return (window, first, second)
  }

  @MainActor
  private func tooltip(in window: NSWindow) -> NSWindow? {
    window.childWindows?.first { $0.title == "Augma Dock Tooltip" }
  }
}
