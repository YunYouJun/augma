import AppKit
import Foundation
import Observation
import XCTest
@testable import AugmaDesktopDemo

final class NativeLocalizationTests: XCTestCase {
  private var resources: URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().appending(path: "Localization")
  }

  func testEnglishAndChineseReachModulesErrorsAndInterpolatedMessages() {
    NativeLocalization.$context.withValue(.init(language: "en-US", resources: resources)) {
      XCTAssertEqual(DemoModule.library.title, "App Library")
      XCTAssertEqual(String(appLocalized: "重试"), "Retry")
      XCTAssertEqual(String(appLocalized: "天气服务暂不可用（HTTP \(503)）。"), "Weather service is temporarily unavailable (HTTP 503).")
      XCTAssertEqual(AugmaPluginError.notInstalled.localizedDescription, "The plugin is not installed.")
    }
    NativeLocalization.$context.withValue(.init(language: "zh-CN", resources: resources)) {
      XCTAssertEqual(DemoModule.library.title, "应用列表")
      XCTAssertEqual(String(appLocalized: "重试"), "重试")
    }
  }

  func testPluginMetadataAndPinnedTitleFollowLanguageWithStableIdentity() throws {
    let root = resources.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let package = try AugmaPluginPackageReader.inspect(root.appending(path: "plugins/breathing-orbit/BreathingOrbit.augmaplugin"))
    let shortcut = NativeDockItem.plugin(.init(id: package.manifest.id, name: package.manifest.name,
      symbol: package.manifest.symbol, localizations: package.manifest.localizations))
    let encoded = shortcut.rawValue
    NativeLocalization.$context.withValue(.init(language: "en-US", resources: resources)) {
      XCTAssertEqual(package.manifest.displayName, "Breathing Orbit")
      XCTAssertEqual(shortcut.title, "Breathing Orbit")
      XCTAssertEqual(NativeDockItem(rawValue: encoded)?.id, shortcut.id)
    }
    NativeLocalization.$context.withValue(.init(language: "zh-CN", resources: resources)) {
      XCTAssertEqual(package.manifest.displayName, "呼吸环")
      XCTAssertEqual(shortcut.title, "呼吸环")
      XCTAssertEqual(shortcut.rawValue, encoded)
    }
    var invalid = package.manifest
    invalid.localizations = ["fr": .init(name: "Example", summary: "")]
    XCTAssertThrowsError(try invalid.validated())
    invalid.localizations = ["en-US": .init(name: "", summary: "")]
    XCTAssertThrowsError(try invalid.validated())
  }

  func testConcurrentLanguageContextsDoNotLeakIntoOneAnother() async {
    await withTaskGroup(of: Void.self) { group in
      for language in ["en-US", "zh-CN", "ja-JP"] {
        group.addTask { [resources] in
          await NativeLocalization.$context.withValue(.init(language: language, resources: resources)) {
            await Task.yield()
            XCTAssertEqual(NativeLocalization.language, language)
            XCTAssertEqual(String(appLocalized: "重试"), language == "en-US" ? "Retry" : language == "ja-JP" ? "再試行" : "重试")
          }
        }
      }
    }
  }

  @MainActor func testStandardMenusTranslateWithoutReplacingActionsOrShortcuts() {
    let menu = NSMenu()
    let file = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
    let submenu = NSMenu(title: "File")
    let copy = NSMenuItem(title: "Copy", action: Selector(("copy:")), keyEquivalent: "c")
    submenu.addItem(copy); file.submenu = submenu; menu.addItem(file)
    let localization = NativeMenuLocalization()
    NativeLocalization.$context.withValue(.init(language: "zh-CN", resources: resources)) {
      localization.refresh(menu)
      XCTAssertEqual(file.title, "文件")
      XCTAssertEqual(copy.title, "复制")
    }
    NativeLocalization.$context.withValue(.init(language: "en-US", resources: resources)) {
      localization.refresh(menu)
      XCTAssertEqual(file.title, "File")
      XCTAssertEqual(copy.title, "Copy")
      XCTAssertTrue(file.submenu?.items.first === copy)
      XCTAssertEqual(copy.action, Selector(("copy:")))
      XCTAssertEqual(copy.keyEquivalent, "c")
    }
  }

  @MainActor func testRebuiltStandardMenusRefreshAfterLanguageChange() async {
    let app = NSApplication.shared
    let previousMenu = app.mainMenu
    let previousLanguage = NativeLocalization.shared.language
    defer { app.mainMenu = previousMenu; NativeLocalization.shared.select(previousLanguage) }
    await NativeLocalization.$context.withValue(.init(language: nil, resources: resources)) {
      NativeLocalization.shared.select("zh-CN")
      let initial = NSMenu()
      initial.addItem(NSMenuItem(title: "文件", action: nil, keyEquivalent: ""))
      app.mainMenu = initial
      let localization = NativeMenuLocalization()
      localization.start()
      NativeLocalization.shared.select("en-US")
      // SwiftUI can replace the menu after the language notification has already fired.
      let replacement = NSMenu()
      let file = NSMenuItem(title: "文件", action: nil, keyEquivalent: "")
      replacement.addItem(file)
      app.mainMenu = replacement
      let deadline = ContinuousClock.now.advanced(by: .seconds(1))
      while file.title != "File", ContinuousClock.now < deadline {
        try? await Task.sleep(for: .milliseconds(10))
      }
      XCTAssertEqual(file.title, "File")
      withExtendedLifetime(localization) {}
    }
  }

  @MainActor func testPreferenceSwitchPersistsWithoutResettingOtherSettings() throws {
    let previousLanguage = NativeLocalization.shared.language
    defer { NativeLocalization.shared.select(previousLanguage) }
    let name = "augma-i18n-\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let store = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["en"], synchronizesAppLanguage: true)
    store.value.opacity = 81
    store.locale = "zh-CN"
    XCTAssertEqual(NativeLocalization.shared.language, "zh-CN")
    store.locale = "en-US"
    let restored = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"], synchronizesAppLanguage: true)
    XCTAssertEqual(restored.locale, "en-US")
    XCTAssertEqual(restored.value.opacity, 81)
    store.locale = "unsupported"
    XCTAssertEqual(NativeLocalization.shared.language, "en-US")
  }

  @MainActor func testLanguageSelectionInvalidatesObservedTranslatedLabels() {
    let previousLanguage = NativeLocalization.shared.language
    defer { NativeLocalization.shared.select(previousLanguage) }
    NativeLocalization.shared.select("zh-CN")
    let changed = expectation(description: "Translated label invalidated")
    NativeLocalization.$context.withValue(.init(language: nil, resources: resources)) {
      withObservationTracking {
        XCTAssertEqual(DemoModule.library.title, "应用列表")
      } onChange: { changed.fulfill() }
      NativeLocalization.shared.select("en-US")
      XCTAssertEqual(DemoModule.library.title, "App Library")
    }
    wait(for: [changed], timeout: 1)
  }
}
