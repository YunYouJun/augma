import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class NativeDockTests: XCTestCase {
  func testDropSavesOrderAcrossRestartButHoverDoesNot() {
    withDefaults { defaults in
      let dock = NativeDockStore(defaults: defaults)
      let original = dock.items
      dock.beginDrag(.mirror)
      dock.previewMove(over: .docs)
      XCTAssertEqual(dock.displayedItems.last, .mirror)
      XCTAssertEqual(dock.items, original)
      XCTAssertNil(defaults.object(forKey: NativeDockStore.storageKey))
      XCTAssertTrue(dock.commitDrop())
      XCTAssertEqual(NativeDockStore(defaults: defaults).items, Array(original.dropFirst()) + [.mirror])
      XCTAssertNil(dock.draggedItem)
    }
  }

  func testCancelledOrOutsideDropRestoresLayoutWithoutWritingPreferences() {
    withDefaults { defaults in
      let dock = NativeDockStore(defaults: defaults)
      dock.beginDrag(.docs)
      dock.previewMove(over: .mirror)
      XCTAssertEqual(dock.displayedItems.first, .docs)
      dock.cancelDrag()
      XCTAssertEqual(dock.displayedItems, NativeDockItem.allCases)
      XCTAssertFalse(dock.commitDrop())
      XCTAssertNil(defaults.object(forKey: NativeDockStore.storageKey))
    }
  }

  func testRemoveRestoreAndEmptyDockSurviveRestart() {
    withDefaults { defaults in
      let dock = NativeDockStore(defaults: defaults)
      for item in NativeDockItem.allCases { dock.remove(item) }
      XCTAssertTrue(NativeDockStore(defaults: defaults).items.isEmpty)
      XCTAssertEqual(dock.removedItems, NativeDockItem.allCases)
      dock.restore(.space)
      dock.restore(.space)
      XCTAssertEqual(NativeDockStore(defaults: defaults).items, [.space])
      dock.reset()
      XCTAssertEqual(NativeDockStore(defaults: defaults).items, NativeDockItem.allCases)
    }
  }

  func testOldOrMalformedEntriesDoNotDuplicateOrReAddRemovedItems() {
    withDefaults { defaults in
      defaults.set(["docs", "unknown", "mirror", "docs"], forKey: NativeDockStore.storageKey)
      let dock = NativeDockStore(defaults: defaults)
      XCTAssertEqual(dock.items, [.docs, .mirror])
      XCTAssertTrue(dock.removedItems.contains(.weather))
      dock.beginDrag(.weather)
      XCTAssertNil(dock.draggedItem)
      XCTAssertFalse(dock.commitDrop())
    }
  }

  func testMenuMovesRespectEdgesAndCancelPendingDrag() {
    withDefaults { defaults in
      let dock = NativeDockStore(defaults: defaults)
      dock.move(.mirror, by: -1)
      dock.move(.docs, by: 1)
      XCTAssertEqual(dock.items, NativeDockItem.allCases)
      dock.beginDrag(.docs)
      dock.previewMove(over: .mirror)
      dock.move(.weather, by: -1)
      XCTAssertNil(dock.draggedItem)
      XCTAssertEqual(Array(dock.displayedItems.prefix(2)), [.weather, .mirror])
      XCTAssertEqual(NativeDockStore(defaults: defaults).items, dock.items)
    }
  }

  func testApplicationsFeaturesAndPluginsCanGrowBeyondTwentyAndSurviveRestart() {
    withDefaults { defaults in
      defaults.set([], forKey: NativeDockStore.storageKey)
      let dock = NativeDockStore(defaults: defaults)
      for index in 0..<40 {
        dock.restore(.application(.init(id: "test.\(index)", name: "App \(index)", path: "/Applications/App\(index).app")))
      }
      dock.restore(.weather)
      dock.restore(.plugin(.init(id: "dev.example.extra", name: "Extra", symbol: "circle")))
      XCTAssertEqual(dock.items.count, 42)
      XCTAssertEqual(dock.items.suffix(2), [.weather, .plugin(.init(id: "dev.example.extra", name: "Extra", symbol: "circle"))])
      XCTAssertEqual(NativeDockStore(defaults: defaults).items, dock.items)
    }
  }

  func testExistingItemCanBeRefreshedInALargeDockWithoutChangingItsPosition() {
    withDefaults { defaults in
      let dock = NativeDockStore(defaults: defaults)
      for index in 0..<48 {
        dock.restore(.application(.init(id: "test.\(index)", name: "App", path: "/Applications/App.app")))
      }
      let index = dock.items.count - 1
      let updated = NativeDockItem.application(.init(id: "test.47", name: "Renamed", path: "/Applications/New.app"))
      dock.restore(updated)
      XCTAssertEqual(dock.items.count, NativeDockItem.allCases.count + 48)
      XCTAssertEqual(dock.items[index], updated)
      XCTAssertEqual(NativeDockStore(defaults: defaults).items[index], updated)
    }
  }

  func testOlderLargeLayoutsCanContinueGrowingAndSorting() {
    withDefaults { defaults in
      let saved = (0..<60).map { index in
        NativeDockItem.application(.init(id: "old.\(index)", name: "App", path: "/Applications/App.app"))
      }
      defaults.set(saved.map(\.rawValue), forKey: NativeDockStore.storageKey)
      let dock = NativeDockStore(defaults: defaults)
      XCTAssertEqual(dock.items, saved)
      dock.restore(.weather)
      XCTAssertEqual(dock.items.last, .weather)
      dock.move(saved[0], by: 1)
      XCTAssertEqual(NativeDockStore(defaults: defaults).items.count, saved.count + 1)
    }
  }

  private func withDefaults(_ body: (UserDefaults) -> Void) {
    let suite = "augma.dock.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    body(defaults)
  }
}
