import AppKit
import ApplicationServices
import XCTest
@testable import AugmaDesktopDemo

/// Opt in with script/verify-menu-bar-shelf.sh. Only operates the dedicated, disposable fixture app.
@MainActor
final class MenuBarShelfIntegrationTests: XCTestCase {
  func testHiddenFixtureOpensItsNativeMenuWithoutMovingItsStatusItem() async throws {
    try await exercise(cancel: false)
  }

  func testCancellingAnOpenNativeMenuLeavesItsOriginalNeighborsUntouched() async throws {
    try await exercise(cancel: true)
  }

  private func exercise(cancel: Bool) async throws {
    guard ProcessInfo.processInfo.environment["AUGMA_MENU_BAR_SHELF_INTEGRATION"] == "1" else {
      throw XCTSkip("Run script/verify-menu-bar-shelf.sh to exercise native menu bar interaction")
    }
    guard AXIsProcessTrusted(), let display = MenuBarShelfDisplay.current() else {
      throw XCTSkip("A trusted accessibility process and an active notched display are required")
    }
    let fixture = try XCTUnwrap(NSRunningApplication.runningApplications(
      withBundleIdentifier: "cn.yunyoujun.augma.shelf-fixture").first)
    let client = MenuBarShelfClient()
    let original = try await client.items(on: display)
    let target = try XCTUnwrap(original.first {
      $0.applicationPID == fixture.processIdentifier && display.isOccluded($0.window)
    }, "The fixture must have an occluded item on the built-in display")
    let domain = "augma.menu-bar-shelf.integration.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let session = MenuBarShelfSession(client: client, defaults: defaults)
    let operation = Task { try await session.open(target, on: display) }
    let watchdog = Task {
      try? await Task.sleep(for: .seconds(12))
      if !Task.isCancelled { operation.cancel() }
    }
    defer { watchdog.cancel(); operation.cancel() }
    var menuAction: AXUIElement?
    for _ in 0..<60 {
      if let context = client.menuContext,
         !context.interfaces(in: MenuBarShelfSystem.windows()).isEmpty,
         let action = Self.fixtureAction(pid: fixture.processIdentifier) { menuAction = action; break }
      try await Task.sleep(for: .milliseconds(100))
    }
    guard let menuAction else {
      operation.cancel()
      do { try await operation.value }
      catch { print("Native shelf operation failed: \(error)") }
      XCTFail("The actual fixture NSMenu did not open")
      return
    }
    let unchanged = try XCTUnwrap(MenuBarShelfSystem.windows().first(where: { target.windowIDs.contains($0.id) && display.contains($0) }))
    XCTAssertTrue(display.isOccluded(unchanged), "Opening a dropdown must not relocate its status item")
    XCTAssertTrue(session.isBusy)
    if cancel {
      operation.cancel()
      do { try await operation.value; XCTFail("Expected cancellation") }
      catch { XCTAssertTrue(error is CancellationError) }
    } else {
      XCTAssertEqual(AXUIElementPerformAction(menuAction, kAXPressAction as CFString), .success)
      try await operation.value
    }
    let restored = try await client.items(on: display)
    let surviving = Set(original.map(\.id)).intersection(restored.map(\.id))
    XCTAssertEqual(original.map(\.id).filter { surviving.contains($0) }, restored.map(\.id).filter { surviving.contains($0) })
    XCTAssertTrue(display.isOccluded(try XCTUnwrap(restored.first(where: { $0.id == target.id })).window))
    XCTAssertNil(defaults.data(forKey: MenuBarShelfSession.legacyRecoveryKey))
  }

  private static func fixtureAction(pid: pid_t) -> AXUIElement? {
    let root = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(root, 0.2)
    guard let bar = MenuBarShelfSystem.element(MenuBarShelfSystem.attribute(root, kAXExtrasMenuBarAttribute)) else { return nil }
    func find(_ element: AXUIElement, depth: Int) -> AXUIElement? {
      guard depth < 5 else { return nil }
      AXUIElementSetMessagingTimeout(element, 0.2)
      let title = MenuBarShelfSystem.attribute(element, kAXTitleAttribute) as? String ?? ""
      if title.hasPrefix("Test menu action") { return element }
      for child in MenuBarShelfSystem.attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
        if let found = find(child, depth: depth + 1) { return found }
      }
      return nil
    }
    return find(bar, depth: 0)
  }
}
