import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class NativeNavigationTests: XCTestCase {
  func testFirstLaunchOpensThe3DApplicationWorkspace() {
    withDefaults { defaults in
      let navigation = NativeNavigationStore(defaults: defaults)
      XCTAssertEqual(navigation.startupMode, .resume)
      XCTAssertEqual(navigation.startupLocation, .workspace)
      let model = makeModel(defaults: defaults, navigation: navigation)
      defer { model.closeScene() }
      XCTAssertEqual(model.selection, .space)
      XCTAssertEqual(model.space.sceneID, .workspace)
    }
  }

  func testLastPageAnd3DSceneSurviveRestartWithoutChangingOtherWindows() {
    withDefaults { defaults in
      let navigation = NativeNavigationStore(defaults: defaults)
      let registry = DemoSessionRegistry()
      let first = makeModel(defaults: defaults, navigation: navigation)
      defer { first.closeScene() }
      registry.register(first)
      first.space.selectScene(.city)
      first.selection = .weather
      let second = makeModel(defaults: defaults, navigation: navigation)
      defer { second.closeScene() }
      XCTAssertEqual(second.selection, .weather)
      XCTAssertEqual(second.space.sceneID, .city)
      registry.register(second)
      first.selection = .notes
      XCTAssertEqual(navigation.lastLocation?.module, .weather, "Background windows must not overwrite the active page")
      second.space.selectScene(.projects)
      second.selection = .focus
      let restored = NativeNavigationStore(defaults: defaults)
      XCTAssertEqual(restored.startupLocation, NativePageLocation(module: .focus, spaceScene: .projects))
      XCTAssertEqual(first.selection, .notes)
      registry.activate(first)
      XCTAssertEqual(navigation.lastLocation, NativePageLocation(module: .notes, spaceScene: .city))
    }
  }

  func testFixedHomeOverridesLastPageAndChangesOnlyNewWindowsOrGoHome() {
    withDefaults { defaults in
      let navigation = NativeNavigationStore(defaults: defaults)
      let first = makeModel(defaults: defaults, navigation: navigation)
      defer { first.closeScene() }
      first.activateNavigation()
      first.space.selectScene(.projects)
      first.selection = .space
      navigation.setHome(first.pageLocation!)
      first.selection = .notes
      XCTAssertEqual(navigation.startupLocation, NativePageLocation(module: .space, spaceScene: .projects))
      navigation.homeModule = .monitor
      XCTAssertEqual(first.selection, .notes, "Changing a preference must not navigate existing windows")
      let second = makeModel(defaults: defaults, navigation: NativeNavigationStore(defaults: defaults))
      defer { second.closeScene() }
      XCTAssertEqual(second.selection, .monitor)
      first.goHome()
      XCTAssertEqual(first.selection, .monitor)
      XCTAssertEqual(first.space.sceneID, .projects, "A non-spatial home must preserve the window's 3D scene")
      navigation.startupMode = .resume
      first.selection = .focus
      XCTAssertEqual(NativeNavigationStore(defaults: defaults).startupLocation.module, .focus)
    }
  }

  func testUnknownStoredPagesFallBackToAUsableHome() {
    withDefaults { defaults in
      defaults.set("unknown", forKey: "augma.navigation.homeModule")
      defaults.set("unknown", forKey: "augma.navigation.lastModule")
      defaults.set("unknown", forKey: "augma.navigation.homeSpaceScene")
      defaults.set("unknown", forKey: "augma.navigation.startupMode")
      XCTAssertEqual(NativeNavigationStore(defaults: defaults).startupLocation, .workspace)
    }
  }

  private func makeModel(defaults: UserDefaults, navigation: NativeNavigationStore) -> NativeDemoModel {
    NativeDemoModel(preferences: NativePreferencesStore(defaults: defaults),
      space: NativeSpaceStore(autoTick: false, observeLifecycle: false), navigation: navigation)
  }

  private func withDefaults(_ body: (UserDefaults) -> Void) {
    let suite = "augma.navigation.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    body(defaults)
  }
}
