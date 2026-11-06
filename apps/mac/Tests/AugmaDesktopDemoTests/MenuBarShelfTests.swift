import AppKit
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class MenuBarShelfTests: XCTestCase {
  private let display = MenuBarShelfDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
    itemArea: CGRect(x: 500, y: 0, width: 500, height: 33))

  func testDisabledByDefaultWithoutCreatingActivityOrPermissions() async {
    let store = MenuBarShelfStore(defaults: makeDefaults())
    store.start()
    store.show()
    store.refresh()
    XCTAssertFalse(store.enabled)
    XCTAssertFalse(store.originalIcons)
    XCTAssertFalse(store.isShowing)
    XCTAssertFalse(store.isRefreshing)
    XCTAssertFalse(store.accessibilityAllowed)
    XCTAssertFalse(store.captureAllowed)
    XCTAssertFalse(store.shortcutAvailable)
    XCTAssertTrue(store.items.isEmpty)
    await store.shutdown()
  }

  func testGeometryIncludesOccludedWindowsButRejectsOtherDisplaysAndNonStatusWindows() {
    XCTAssertTrue(display.contains(item(1, x: 300).window))
    XCTAssertTrue(display.isOccluded(item(1, x: 480).window))
    XCTAssertFalse(display.isOccluded(item(1, x: 550).window))
    XCTAssertFalse(display.isOccluded(item(1, x: 950, width: 52).window))
    XCTAssertFalse(display.contains(item(1, x: -100).window))
    let panel = MenuBarShelfWindow(id: 8, ownerPID: 7, title: "panel", frame: CGRect(x: 300, y: 60, width: 50, height: 30),
      layer: 25, isOnScreen: true)
    XCTAssertFalse(display.contains(panel))
    let shifted = MenuBarShelfDisplay(id: 2, frame: CGRect(x: -1200, y: -800, width: 1000, height: 800),
      itemArea: CGRect(x: -700, y: -800, width: 500, height: 33))
    let window = MenuBarShelfWindow(id: 9, ownerPID: 7, title: "", frame: CGRect(x: -1000, y: -800, width: 50, height: 33),
      layer: 25, isOnScreen: false)
    XCTAssertTrue(shifted.contains(window))
    XCTAssertTrue(shifted.isOccluded(window))
  }

  func testShelfClickOpensTheOriginalMenuInsteadOfRebuildingItsContents() async {
    let client = ShelfTestClient(items: fixtures())
    client.holdMenu = true
    let waiting = expectation(description: "The source application owns the menu")
    client.onWait = { waiting.fulfill() }
    let defaults = makeDefaults()
    defaults.set(true, forKey: MenuBarShelfStore.enabledKey)
    let store = MenuBarShelfStore(defaults: defaults, client: client, currentDisplay: { self.display })
    store.show()
    store.open(client.current[0])
    await fulfillment(of: [waiting], timeout: 1)
    XCTAssertEqual(client.events, ["open", "wait"])
    XCTAssertFalse(client.rightClick)
    XCTAssertTrue(store.isBusy)
    XCTAssertFalse(store.isShowing, "The shelf must release focus before the source menu opens")
    await store.shutdown()
    XCTAssertEqual(client.events, ["open", "wait", "dismiss"])
    XCTAssertFalse(store.isBusy)
  }

  func testOccludedItemOpensDirectlyWithoutMovingOrCreatingARecoveryRecord() async throws {
    let original = fixtures()
    let client = ShelfTestClient(items: original)
    let defaults = makeDefaults()
    let session = MenuBarShelfSession(client: client, defaults: defaults)
    XCTAssertTrue(display.isOccluded(original[0].window))
    try await session.open(original[0], on: display, rightClick: true)
    XCTAssertEqual(client.events, ["open", "wait"])
    XCTAssertTrue(client.rightClick)
    XCTAssertEqual(client.current.map(\.window.frame), original.map(\.window.frame))
    XCTAssertNil(defaults.data(forKey: MenuBarShelfSession.legacyRecoveryKey))
    XCTAssertFalse(session.isBusy)
  }

  func testLegacyRecoveryCannotBlockDirectMenuOpening() async throws {
    let defaults = makeDefaults()
    defaults.set(Data("old recovery".utf8), forKey: MenuBarShelfSession.legacyRecoveryKey)
    let client = ShelfTestClient(items: fixtures())
    let session = MenuBarShelfSession(client: client, defaults: defaults)
    try await session.open(client.current[0], on: display)
    XCTAssertEqual(client.events, ["open", "wait"])
    XCTAssertNil(defaults.data(forKey: MenuBarShelfSession.legacyRecoveryKey))
  }

  func testOpeningFailureDismissesOnlyThatMenuAndReleasesTheSession() async {
    let original = fixtures()
    let client = ShelfTestClient(items: original)
    client.failOpen = true
    let session = MenuBarShelfSession(client: client, defaults: makeDefaults())
    do { try await session.open(original[0], on: display); XCTFail("Expected opening failure") }
    catch { XCTAssertTrue(error is ShelfTestError) }
    XCTAssertEqual(client.events, ["open", "dismiss"])
    XCTAssertEqual(client.current.map(\.id), original.map(\.id))
    XCTAssertFalse(session.isBusy)
  }

  func testUnobservedMenuIsReportedAsFailureAndDismissed() async {
    let client = ShelfTestClient(items: fixtures())
    client.failWait = true
    let session = MenuBarShelfSession(client: client, defaults: makeDefaults())
    do { try await session.open(client.current[0], on: display); XCTFail("Expected menu observation failure") }
    catch { XCTAssertEqual(error as? MenuBarShelfError, .menuDidNotOpen) }
    XCTAssertEqual(client.events, ["open", "wait", "dismiss"])
    XCTAssertFalse(session.isBusy)
  }

  func testCancellingAnOpenMenuClosesItWithoutTouchingItsStatusItem() async throws {
    let original = fixtures()
    let client = ShelfTestClient(items: original)
    client.holdMenu = true
    let waiting = expectation(description: "Original menu is open")
    client.onWait = { waiting.fulfill() }
    let session = MenuBarShelfSession(client: client, defaults: makeDefaults())
    let operation = Task { try await session.open(original[0], on: display) }
    await fulfillment(of: [waiting], timeout: 2)
    XCTAssertTrue(session.isBusy)
    do { try await session.open(original[1], on: display); XCTFail("A second menu must be rejected") }
    catch { XCTAssertEqual(error as? MenuBarShelfError, .busy) }
    operation.cancel()
    do { try await operation.value; XCTFail("Expected cancellation") }
    catch { XCTAssertTrue(error is CancellationError) }
    XCTAssertEqual(client.events, ["open", "wait", "dismiss"])
    XCTAssertFalse(client.cleanupWasCancelled)
    XCTAssertEqual(client.current.map(\.window.frame), original.map(\.window.frame))
    XCTAssertFalse(session.isBusy)
  }

  func testReusedWindowIDCannotOpenAnotherApplicationsMenu() async {
    let selected = fixtures()[0]
    let changed = MenuBarShelfItem(window: selected.window, applicationPID: 999,
      applicationName: "Other app", bundleID: "other", detail: "", accessibilityID: 99)
    let client = ShelfTestClient(items: [changed])
    let session = MenuBarShelfSession(client: client, defaults: makeDefaults())
    do { try await session.open(selected, on: display); XCTFail("Expected stale identity rejection") }
    catch { XCTAssertEqual(error as? MenuBarShelfError, .itemUnavailable) }
    XCTAssertTrue(client.events.isEmpty)
  }

  func testItemWithoutAnAccessibilityTargetCannotSendNativeInput() async {
    let known = fixtures()[0]
    let unknown = MenuBarShelfItem(window: known.window, applicationPID: 10,
      applicationName: "Fixture", bundleID: "fixture", detail: "")
    let client = ShelfTestClient(items: [unknown])
    let session = MenuBarShelfSession(client: client, defaults: makeDefaults())
    XCTAssertFalse(unknown.canOpenMenu)
    do { try await session.open(unknown, on: display); XCTFail("Expected missing AX target rejection") } catch { }
    XCTAssertTrue(client.events.isEmpty)
  }

  func testPermissionFailureBeforeOpeningDoesNotSendNativeInput() async {
    let client = ShelfTestClient(items: fixtures())
    client.failScan = true
    let session = MenuBarShelfSession(client: client, defaults: makeDefaults())
    do { try await session.open(client.current[0], on: display); XCTFail("Expected permission failure") } catch { }
    XCTAssertTrue(client.events.isEmpty)
    XCTAssertFalse(session.isBusy)
  }

  func testMenuTrackingIncludesOtherDisplayButExcludesExistingAndUnrelatedWindows() {
    let context = MenuBarShelfMenuContext(itemID: 1, applicationPID: 10, rendererPID: 20,
      baseline: [100])
    func window(_ id: UInt32, pid: Int32, layer: Int = 101) -> MenuBarShelfWindow {
      .init(id: id, ownerPID: pid, title: "", frame: CGRect(x: -1400, y: -900, width: 250, height: 300),
        layer: layer, isOnScreen: true)
    }
    XCTAssertEqual(context.interfaces(in: [window(100, pid: 10), window(101, pid: 30),
      window(102, pid: 10), window(103, pid: 20), window(104, pid: 20, layer: 25),
      window(105, pid: 10, layer: 0)]).map(\.id), [102, 103])
  }

  func testDisplayWindowCopiesKeepOneStableSelection() {
    let original = fixtures()[0]
    let first = MenuBarShelfItem(window: original.window, applicationPID: 10, applicationName: "Fixture",
      bundleID: "fixture", detail: "", windowIDs: [1, 11], accessibilityID: 42)
    let copy = MenuBarShelfWindow(id: 11, ownerPID: 7, title: "fixture", frame: original.window.frame,
      layer: 25, isOnScreen: true)
    let second = MenuBarShelfItem(window: copy, applicationPID: 10, applicationName: "Fixture",
      bundleID: "fixture", detail: "", windowIDs: [1, 11], accessibilityID: 42)
    XCTAssertEqual(first.id, second.id)
    XCTAssertEqual(first.accessibilityID, second.accessibilityID)
  }

  private func fixtures() -> [MenuBarShelfItem] {
    [item(1, x: 300), item(2, x: 520), item(3, x: 680), item(4, x: 800)]
  }

  private func item(_ id: UInt32, x: CGFloat, width: CGFloat = 50) -> MenuBarShelfItem {
    .init(window: .init(id: id, ownerPID: 7, title: "Item-\(id)", frame: CGRect(x: x, y: 0, width: width, height: 33),
      layer: 25, isOnScreen: true), applicationPID: 10, applicationName: "Fixture", bundleID: "fixture", detail: "",
      accessibilityID: UInt(id))
  }

  private func makeDefaults() -> UserDefaults {
    let name = "augma.menu-bar-shelf.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    addTeardownBlock { defaults.removePersistentDomain(forName: name) }
    return defaults
  }
}

private enum ShelfTestError: Error { case failure }

@MainActor
private final class ShelfTestClient: MenuBarShelfInteracting {
  var current: [MenuBarShelfItem]
  var events: [String] = []
  var failOpen = false
  var failWait = false
  var failScan = false
  var holdMenu = false
  var cleanupWasCancelled = false
  var onWait: (() -> Void)?
  var rightClick = false

  init(items: [MenuBarShelfItem]) { current = items }
  func items(on display: MenuBarShelfDisplay) async throws -> [MenuBarShelfItem] {
    if failScan { throw ShelfTestError.failure }
    return current
  }
  func openMenu(_ item: MenuBarShelfItem, rightClick: Bool) async throws {
    events.append("open")
    self.rightClick = rightClick
    if failOpen { throw ShelfTestError.failure }
  }
  func images(for items: [MenuBarShelfItem]) async -> [CGWindowID: NSImage] { [:] }
  func waitForMenuToClose(_ item: MenuBarShelfItem, on display: MenuBarShelfDisplay) async throws {
    events.append("wait")
    onWait?()
    if failWait { throw MenuBarShelfError.menuDidNotOpen }
    while holdMenu { try await Task.sleep(for: .milliseconds(20)) }
  }
  func dismissMenu(_ item: MenuBarShelfItem) async throws {
    events.append("dismiss")
    cleanupWasCancelled = Task.isCancelled
    holdMenu = false
  }
}
