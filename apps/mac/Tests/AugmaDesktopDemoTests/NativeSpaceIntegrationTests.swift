import AppKit
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class NativeSpaceIntegrationTests: XCTestCase {
  func testScanAnchorAndViewSurvivePresentationWithoutWebKit() {
    var time = 0.0
    let space = NativeSpaceStore(uptime: { time }, autoTick: false, observeLifecycle: false)
    let model = NativeDemoModel(space: space)
    model.performSpaceAction(.scan)
    time = 0.8
    space.refreshScan()
    model.setImmersive(true)
    XCTAssertTrue(space.scanning)
    XCTAssertEqual(space.scanProgress, 40, accuracy: 0.001)
    time = 2
    space.refreshScan()
    space.selectLandmark("tree")
    space.togglePin()
    space.setView(yaw: 0.6, pitch: 0.2, scale: 1.2)
    model.setImmersive(false)
    XCTAssertEqual(space.selectedID, "tree")
    XCTAssertEqual(space.pinnedLandmarkID, "tree")
    XCTAssertEqual(space.viewYaw, 0.6)
    XCTAssertEqual(space.scanProgress, 100)
    model.closeScene()
    model.performSpaceAction(.scan)
    XCTAssertFalse(space.scanning, "Closing even a window without WebKit stops spatial work")
  }

  func testPendingMenuActionReopensDirectlyIntoNativeSpace() {
    _ = NSApplication.shared
    let registry = DemoSessionRegistry()
    var opens = 0
    registry.perform(.space(.scene(.city))) { opens += 1 }
    let space = NativeSpaceStore(autoTick: false, observeLifecycle: false)
    let model = NativeDemoModel(space: space)
    registry.register(model)
    XCTAssertEqual(opens, 1)
    XCTAssertEqual(model.selection, .space)
    XCTAssertEqual(space.sceneID, .city)
    registry.unregister(model)
    space.shutdown()
  }

  func testSpatialCommandBoundaryKeepsNotesAndRejectsArbitraryValues() {
    XCTAssertEqual(WorkspaceCommand.parse("扫描空间"), .space(.scan))
    XCTAssertEqual(WorkspaceCommand.parse("scan space"), .space(.scan))
    XCTAssertEqual(WorkspaceCommand.parse("空間をスキャン"), .space(.scan))
    XCTAssertEqual(WorkspaceCommand.parse("打开空间"), .open(.space))
    XCTAssertEqual(WorkspaceCommand.parse("记下 扫描空间"), .note("扫描空间"))
    XCTAssertNil(WorkspaceCommand.parse("不要扫描空间"))
    XCTAssertNil(NativeSpaceAction.decode("scene", value: true))
    XCTAssertNil(NativeSpaceAction.decode("scene", value: "unknown"))
    XCTAssertNil(NativeSpaceAction.decode("landmark", value: "file:///tmp/private"))
    XCTAssertNil(NativeSpaceAction.decode("evaluateJavaScript", value: "alert(1)"))
  }

  func testWorkspaceSpaceCommandsRequireHandlerAndUseSameNativeStore() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "augma-native-space-commands-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let workspace = WorkspaceStore(url: directory.appending(path: "workspace.json"), notifications: FocusNotifications(enabled: false), observeLifecycle: false)
    let commands = WorkspaceCommands(store: workspace)
    XCTAssertFalse(commands.isAvailable(.space(.scan)))
    XCTAssertFalse(commands.execute(.space(.scan)))
    XCTAssertTrue(commands.resultIsError)
    XCTAssertNil(commands.resultDestination)
    withNativeModel { fixture in
      commands.operateSpace = { fixture.model.performSpaceAction($0) }
      XCTAssertTrue(commands.isAvailable(.space(.scan)))
      XCTAssertTrue(commands.execute(.space(.scan)))
      XCTAssertTrue(fixture.space.scanning)
      XCTAssertEqual(fixture.model.selection, .space)
      XCTAssertEqual(commands.resultDestination, .space)
      XCTAssertFalse(commands.resultIsError)
      XCTAssertTrue(commands.execute(.space(.routeStart)))
      XCTAssertEqual(fixture.space.routeStep, 0)
      XCTAssertEqual(commands.resultDestination, .space)
    }
  }

  private func withNativeModel(_ check: (NativeSpaceIntegrationFixture) -> Void) {
    let fixture = NativeSpaceIntegrationFixture()
    defer { fixture.tearDown() }
    check(fixture)
  }

}

@MainActor
private final class NativeSpaceIntegrationFixture {
  private let suite = "augma-native-space-integration-" + UUID().uuidString
  private let defaults: UserDefaults
  let audio: NativeAudioStore
  let space: NativeSpaceStore
  let model: NativeDemoModel
  var time: TimeInterval {
    get { clock.value }
    set { clock.value = newValue }
  }
  private let clock: NativeSpaceIntegrationClock

  init() {
    let defaults = UserDefaults(suiteName: suite)!
    self.defaults = defaults
    let preferences = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
    let clock = NativeSpaceIntegrationClock()
    self.clock = clock
    audio = NativeAudioStore(defaults: defaults, engine: NativeSpaceIntegrationAudioEngine(), observeLifecycle: false, automaticallyTick: false)
    space = NativeSpaceStore(uptime: { clock.value }, autoTick: false, observeLifecycle: false)
    model = NativeDemoModel(preferences: preferences, audio: audio, space: space)
  }

  func tearDown() {
    model.closeScene()
    audio.shutdown()
    defaults.removePersistentDomain(forName: suite)
  }
}

@MainActor
private final class NativeSpaceIntegrationClock { var value: TimeInterval = 0 }

@MainActor
private final class NativeSpaceIntegrationAudioEngine: NativeAudioEngineBackend {
  var onConfigurationChange: (() -> Void)?
  func play(trackIndex: Int, from elapsed: TimeInterval) throws {}
  func pause() {}
  func setVolume(_ fraction: Double) {}
  func reset() {}
  func stop() {}
}
