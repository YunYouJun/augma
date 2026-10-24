import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class NativeSpaceTests: XCTestCase {
  func testCatalogPreservesLandmarksDistancesAndTranslations() {
    let garden = NativeSpaceScene.scene(for: .garden)
    let city = NativeSpaceScene.scene(for: .city)
    XCTAssertEqual(NativeSpaceSceneID.allCases, [.garden, .city, .workspace, .projects])
    XCTAssertEqual(garden.landmarks.map(\.id), ["terrace", "pavilion", "tree"])
    XCTAssertEqual(garden.landmarks.map(\.distance), [120, 80, 45])
    XCTAssertEqual(city.landmarks.map(\.id), ["gallery", "station", "square"])
    XCTAssertEqual(city.landmarks.map(\.distance), [240, 160, 60])
    XCTAssertEqual(garden.title(locale: "zh-CN"), "空中庭院")
    XCTAssertEqual(city.title(locale: "en-US"), "City Stroll")
    XCTAssertEqual(garden.landmarks[1].title(locale: "ja-JP"), "ガラスの回廊")
    for scene in NativeSpaceScene.catalog {
      for locale in ["zh-CN", "en-US", "ja-JP"] {
        XCTAssertFalse(scene.detail(locale: locale).isEmpty)
        XCTAssertTrue(scene.landmarks.allSatisfy { !$0.title(locale: locale).isEmpty && !$0.detail(locale: locale).isEmpty })
      }
      XCTAssertTrue(scene.landmarks.allSatisfy { $0.position.x.isFinite && $0.position.y.isFinite && $0.position.z.isFinite })
    }
  }

  func testInitializationNeedsNoSimulatorAndDoesNotScan() {
    let store = makeStore()
    XCTAssertEqual(store.sceneID, .garden)
    XCTAssertEqual(store.selected.id, "terrace")
    XCTAssertFalse(store.scanning)
    XCTAssertEqual(store.scanProgress, 0)
    XCTAssertNil(store.pinnedLandmarkID)
    XCTAssertNil(store.routeStep)
    XCTAssertEqual(store.routeProgress, 0)
    XCTAssertEqual(store.remaining, 120)
  }

  func testScanCompletesAfterTwoSecondsAndStopsAdvancing() {
    let clock = SpaceTestClock()
    let store = makeStore(clock)
    store.scan()
    XCTAssertTrue(store.scanning)
    clock.time += 0.5
    store.refreshScan()
    XCTAssertEqual(store.scanProgress, 25, accuracy: 0.001)
    clock.time += 1.5
    store.refreshScan()
    XCTAssertEqual(store.scanProgress, 100)
    XCTAssertFalse(store.scanning)
    clock.time += 20
    store.refreshScan()
    XCTAssertEqual(store.scanProgress, 100)
  }

  func testScanProgressIsMonotonicAndIgnoresInvalidClockValues() {
    let clock = SpaceTestClock()
    let store = makeStore(clock)
    store.scan()
    clock.time += 1
    store.refreshScan()
    XCTAssertEqual(store.scanProgress, 50)
    clock.time -= 0.8
    store.refreshScan()
    XCTAssertEqual(store.scanProgress, 50)
    clock.time = .infinity
    store.refreshScan()
    XCTAssertEqual(store.scanProgress, 50)
    clock.time = .nan
    store.refreshScan()
    XCTAssertEqual(store.scanProgress, 50)
    store.cancelScan()
    store.scan()
    XCTAssertFalse(store.scanning)
  }

  func testCancelRejectsLateScanTicksAndRestartHasFreshBaseline() {
    let clock = SpaceTestClock()
    let store = makeStore(clock)
    store.scan()
    clock.time += 0.5
    store.refreshScan()
    store.cancelScan()
    clock.time += 10
    store.refreshScan()
    XCTAssertEqual(store.scanProgress, 25)
    XCTAssertFalse(store.scanning)
    store.scan()
    XCTAssertEqual(store.scanProgress, 0)
    clock.time += 0.1
    store.refreshScan()
    XCTAssertEqual(store.scanProgress, 5, accuracy: 0.001)
  }

  func testRepeatedScanAndSameSceneKeepCurrentProgress() {
    let clock = SpaceTestClock()
    let store = makeStore(clock)
    store.scan()
    clock.time += 0.5
    store.refreshScan()
    store.scan()
    store.selectScene(.garden)
    XCTAssertEqual(store.scanProgress, 25)
    XCTAssertTrue(store.scanning)
    clock.time += 0.5
    store.refreshScan()
    XCTAssertEqual(store.scanProgress, 50)
  }

  func testLandmarkSelectionDoesNotInterruptScanOrMovePin() {
    let clock = SpaceTestClock()
    let store = makeStore(clock)
    store.scan()
    clock.time += 1
    store.refreshScan()
    store.selectLandmark("pavilion")
    XCTAssertTrue(store.scanning)
    XCTAssertEqual(store.scanProgress, 50)
    clock.time += 1
    store.refreshScan()
    store.togglePin()
    XCTAssertEqual(store.pinnedLandmarkID, "pavilion")
    XCTAssertTrue(store.pinned)
    store.selectLandmark("tree")
    XCTAssertEqual(store.pinnedLandmarkID, "pavilion")
    XCTAssertFalse(store.pinned)
    store.selectLandmark("pavilion")
    XCTAssertTrue(store.pinned)
  }

  func testPinRequiresCompletedScanAndExplicitlyChangesTarget() {
    let clock = SpaceTestClock()
    let store = makeStore(clock)
    store.togglePin()
    XCTAssertNil(store.pinnedLandmarkID)
    store.scan()
    store.togglePin()
    XCTAssertNil(store.pinnedLandmarkID)
    clock.time += 2
    store.refreshScan()
    store.togglePin()
    XCTAssertEqual(store.pinnedLandmarkID, "terrace")
    store.selectLandmark("tree")
    store.togglePin()
    XCTAssertEqual(store.pinnedLandmarkID, "tree")
    store.togglePin()
    XCTAssertNil(store.pinnedLandmarkID)
    store.togglePin()
    store.scan()
    XCTAssertNil(store.pinnedLandmarkID)
  }

  func testNewSceneResetsSceneSpecificStateAndIgnoresOldTicks() {
    let clock = SpaceTestClock()
    let store = makeStore(clock)
    store.scan()
    clock.time += 2
    store.refreshScan()
    store.togglePin()
    store.startRoute()
    store.advanceRoute()
    store.setView(yaw: 1, pitch: 0.2, scale: 1.4)
    store.selectScene(.city)
    XCTAssertEqual(store.sceneID, .city)
    XCTAssertEqual(store.selected.id, "gallery")
    XCTAssertEqual(store.scanProgress, 0)
    XCTAssertFalse(store.scanning)
    XCTAssertNil(store.pinnedLandmarkID)
    XCTAssertNil(store.routeStep)
    XCTAssertEqual(store.viewYaw, 0)
    clock.time += 50
    store.refreshScan()
    XCTAssertEqual(store.scanProgress, 0)
    store.selectScene(.garden)
    store.scan()
    clock.time += 1
    store.selectScene(.city)
    clock.time += 1
    store.refreshScan()
    XCTAssertFalse(store.scanning)
    XCTAssertEqual(store.scanProgress, 0)
  }

  func testRouteAdvancesToArrivalAndResetsWhenDestinationChanges() {
    let store = makeStore()
    store.advanceRoute()
    XCTAssertNil(store.routeStep)
    store.startRoute()
    XCTAssertEqual(store.routeStep, 0)
    for step in 1...4 {
      store.advanceRoute()
      XCTAssertEqual(store.routeStep, step)
      XCTAssertEqual(store.routeProgress, Double(step) * 25)
      XCTAssertEqual(store.remaining, 120 - 30 * step)
    }
    store.advanceRoute()
    XCTAssertEqual(store.routeStep, 4)
    store.selectLandmark("terrace")
    XCTAssertEqual(store.routeStep, 4)
    store.selectLandmark("not-a-landmark")
    store.selectLandmark("gallery")
    XCTAssertEqual(store.selected.id, "terrace")
    XCTAssertEqual(store.routeStep, 4)
    store.selectLandmark("tree")
    XCTAssertNil(store.routeStep)
    XCTAssertEqual(store.remaining, 45)
    store.startRoute()
    store.advanceRoute()
    XCTAssertEqual(store.remaining, 34)
    store.cancelRoute()
    XCTAssertNil(store.routeStep)
  }

  func testViewValuesRemainFiniteWithinBoundsAndCanReset() {
    let store = makeStore()
    store.setView(yaw: 9 * .pi, pitch: 4, scale: 100)
    XCTAssertEqual(store.viewYaw, .pi, accuracy: 0.0001)
    XCTAssertEqual(store.viewPitch, 0.7)
    XCTAssertEqual(store.viewScale, 1.6)
    store.setView(yaw: -9 * .pi, pitch: -5, scale: -1)
    XCTAssertEqual(store.viewYaw, -.pi, accuracy: 0.0001)
    XCTAssertEqual(store.viewPitch, -0.7)
    XCTAssertEqual(store.viewScale, 0.65)
    for invalid in [Double.nan, .infinity, -.infinity] {
      store.setView(yaw: invalid, pitch: 0, scale: 1)
      store.setView(yaw: 0, pitch: invalid, scale: 1)
      store.setView(yaw: 0, pitch: 0, scale: invalid)
      XCTAssertEqual(store.viewYaw, -.pi, accuracy: 0.0001)
      XCTAssertEqual(store.viewPitch, -0.7)
      XCTAssertEqual(store.viewScale, 0.65)
    }
    store.resetView()
    XCTAssertEqual(store.viewYaw, 0)
    XCTAssertEqual(store.viewPitch, -0.15)
    XCTAssertEqual(store.viewScale, 1)
  }

  func testSleepCancelsScanAndWakeRequiresExplicitNewScan() {
    let clock = SpaceTestClock()
    let store = makeStore(clock)
    store.scan()
    clock.time += 0.5
    store.refreshScan()
    store.setSleeping(true)
    clock.time += 10
    store.refreshScan()
    XCTAssertFalse(store.scanning)
    XCTAssertEqual(store.scanProgress, 25)
    store.scan()
    XCTAssertFalse(store.scanning)
    store.setSleeping(false)
    XCTAssertFalse(store.scanning)
    store.scan()
    XCTAssertTrue(store.scanning)
    XCTAssertEqual(store.scanProgress, 0)
  }

  func testShutdownCancelsScanAndRejectsNewOperations() {
    let clock = SpaceTestClock()
    let store = makeStore(clock)
    store.scan()
    clock.time += 0.5
    store.refreshScan()
    store.shutdown()
    clock.time += 10
    store.refreshScan()
    store.scan()
    store.selectScene(.city)
    store.selectLandmark("tree")
    store.startRoute()
    store.togglePin()
    store.setView(yaw: 1, pitch: 0, scale: 1.2)
    XCTAssertFalse(store.scanning)
    XCTAssertEqual(store.scanProgress, 25)
    XCTAssertEqual(store.sceneID, .garden)
    XCTAssertEqual(store.selected.id, "terrace")
    XCTAssertNil(store.routeStep)
    XCTAssertNil(store.pinnedLandmarkID)
    XCTAssertEqual(store.viewYaw, 0)
  }

  private func makeStore(_ clock: SpaceTestClock = SpaceTestClock()) -> NativeSpaceStore {
    NativeSpaceStore(uptime: { clock.time }, autoTick: false, observeLifecycle: false)
  }
}

@MainActor
private final class SpaceTestClock {
  var time: TimeInterval = 1_000
}
