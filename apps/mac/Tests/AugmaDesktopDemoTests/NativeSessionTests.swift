import Combine
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class NativeSessionTests: XCTestCase {
  func testAllInternalPanelsAndEmptyBrowserKeepWebKitUnallocated() {
    withModel { model in
      for module in DemoModule.allCases {
        model.selection = module
        model.setImmersive(true)
        model.setImmersive(false)
        XCTAssertNil(model.browser.webView, module.rawValue)
      }
    }
  }

  func testNotificationsDeviceAndAssistantDraftSurvivePresentationChanges() {
    withModel { model in
      model.notifications.post(title: "Event", detail: "Detail")
      model.assistant.draft = "打开地图"
      model.device.sleep()
      let ids = model.notifications.notices.map(\.id)
      for immersive in [true, false, true, false] {
        model.setImmersive(immersive)
        XCTAssertEqual(model.notifications.notices.map(\.id), ids)
        XCTAssertEqual(model.device.connection, .sleeping)
        XCTAssertEqual(model.assistant.draft, "打开地图")
      }
      model.notifications.clear()
      model.setImmersive(true)
      XCTAssertTrue(model.notifications.notices.isEmpty)
    }
  }

  func testAssistantNavigationStaysInImmersionAndKeepsReplyWithoutStartingCameraOrBrowser() {
    withModel { model in
      model.setImmersive(true)
      model.selection = .commands
      model.assistant.submit("打开网页")
      XCTAssertEqual(model.selection, .browser)
      XCTAssertTrue(model.isImmersive)
      XCTAssertFalse(model.assistant.reply.isEmpty)
      XCTAssertNil(model.browser.webView)
      model.selection = .commands
      model.assistant.submit("打开摄像头")
      XCTAssertEqual(model.selection, .camera)
      XCTAssertTrue(model.isImmersive)
      XCTAssertFalse(model.assistant.reply.isEmpty)
      model.selection = .commands
      model.assistant.submit("不要打开网页")
      XCTAssertEqual(model.selection, .commands)
      XCTAssertNil(model.browser.webView)
    }
  }

  func testNativeSpaceEventsAreDeliveredOnceWithoutWholeWindowInvalidation() {
    var time = 0.0
    let space = NativeSpaceStore(uptime: { time }, autoTick: false, observeLifecycle: false)
    withModel(space: space) { model in
      model.performSpaceAction(.scan)
      var invalidations = 0
      let observer = model.objectWillChange.sink { invalidations += 1 }
      time = 1
      space.refreshScan()
      XCTAssertTrue(model.notifications.notices.isEmpty)
      time = 2
      space.refreshScan()
      space.refreshScan()
      XCTAssertEqual(model.notifications.notices.count, 1)
      space.togglePin()
      XCTAssertEqual(model.notifications.notices.count, 2)
      XCTAssertEqual(invalidations, 0, "Progress and notifications are subscribed by leaf views")
      withExtendedLifetime(observer) {}
    }
  }

  func testDeviceStandbyCancelsWindowSpatialWorkAndCloseCannotRestartIt() {
    withModel { model in
      model.space.scan()
      model.space.startRoute()
      model.device.disconnect()
      XCTAssertFalse(model.space.scanning)
      XCTAssertNil(model.space.routeStep)
      model.closeScene()
      model.performSpaceAction(.scan)
      model.device.connect()
      model.assistant.submit("打开网页")
      XCTAssertFalse(model.space.scanning)
      XCTAssertEqual(model.device.connection, .disconnected)
      XCTAssertNotEqual(model.selection, .browser)
      XCTAssertNil(model.browser.webView)
    }
  }

  func testWindowSessionStateIsIndependent() {
    withModel { first in
      withModel { second in
        first.notifications.post(title: "First", detail: "")
        first.device.sleep()
        first.assistant.draft = "Only first"
        first.browser.addressInput = "example.com"
        XCTAssertTrue(second.notifications.notices.isEmpty)
        XCTAssertTrue(second.device.online)
        XCTAssertTrue(second.assistant.draft.isEmpty)
        XCTAssertTrue(second.browser.addressInput.isEmpty)
      }
    }
  }

  private func withModel(space: NativeSpaceStore? = nil, _ run: (NativeDemoModel) -> Void) {
    let suite = "augma-native-session-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    let preferences = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
    preferences.value.speechFeedback = false
    let model = NativeDemoModel(preferences: preferences,
                               space: space ?? NativeSpaceStore(autoTick: false, observeLifecycle: false))
    defer { model.closeScene(); defaults.removePersistentDomain(forName: suite) }
    run(model)
  }
}
