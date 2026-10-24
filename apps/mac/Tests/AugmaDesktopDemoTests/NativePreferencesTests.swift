import Foundation
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class NativePreferencesTests: XCTestCase {
  func testInitialLanguageFollowsSupportedAppLocalization() {
    withDefaults { defaults in
      XCTAssertEqual(NativePreferencesStore(defaults: defaults, preferredLocalizations: ["en-GB"]).locale, "en-US")
      XCTAssertEqual(NativePreferencesStore(defaults: defaults, preferredLocalizations: ["fr", "ja"]).locale, "ja-JP")
      XCTAssertEqual(NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"]).locale, "zh-CN")
      XCTAssertEqual(NativePreferencesStore(defaults: defaults, preferredLocalizations: ["fr"]).locale, "zh-CN")
      XCTAssertNil(defaults.object(forKey: NativePreferencesStore.preferencesKey))
    }
  }

  func testNativeLanguageAndLegacyLanguageOverrideAppLocalization() {
    withDefaults { defaults in
      let store = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["en"])
      store.importLegacy([:], locale: "ja-JP")
      XCTAssertEqual(store.locale, "ja-JP")
      let restored = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
      XCTAssertEqual(restored.locale, "ja-JP")
    }
  }

  func testResetRestoresAppLanguageAndMissingLegacyLocaleUsesAppLanguage() {
    withDefaults { defaults in
      let store = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["en"])
      store.importLegacy(["dark": true], locale: nil)
      XCTAssertEqual(store.locale, "en-US")
      store.locale = "ja-JP"
      store.reset()
      XCTAssertEqual(store.locale, "en-US")
      XCTAssertFalse(store.value.dark)
    }
  }

  func testInitializationUsesNativeDefaultsWithoutClaimingLegacyMigration() {
    withDefaults { defaults in
      let store = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
      XCTAssertEqual(store.value, NativeScenePreferences())
      XCTAssertEqual(store.value.opacity, 100)
      XCTAssertNil(defaults.object(forKey: NativePreferencesStore.preferencesKey))
      XCTAssertFalse(defaults.bool(forKey: NativePreferencesStore.migrationKey))
    }
  }

  func testEveryPreferencePersistsWithoutASimulator() {
    withDefaults { defaults in
      let store = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
      store.set("opacity", value: 76.0)
      store.set("dark", value: true)
      store.set("showHud", value: false)
      store.set("mirror", value: true)
      store.set("focus", value: true)
      store.set("depthMotion", value: true)
      store.set("sceneBackdrop", value: false)
      store.set("curvedHud", value: true)
      store.set("speechFeedback", value: false)
      store.locale = "ja-JP"

      let restored = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
      XCTAssertEqual(restored.value, store.value)
      XCTAssertEqual(restored.locale, "ja-JP")
      XCTAssertEqual(restored.value.opacity, 76)
      XCTAssertTrue(restored.value.dark)
      XCTAssertFalse(restored.value.showHud)
      XCTAssertTrue(restored.value.mirror)
      XCTAssertTrue(restored.value.focus)
      XCTAssertTrue(restored.value.depthMotion)
      XCTAssertFalse(restored.value.sceneBackdrop)
      XCTAssertTrue(restored.value.curvedHud)
      XCTAssertFalse(restored.value.speechFeedback)
      XCTAssertTrue(defaults.bool(forKey: NativePreferencesStore.migrationKey))
    }
  }

  func testBindingsAndDirectEditsPersistAndNormalize() {
    withDefaults { defaults in
      let store = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
      store.binding(\.dark).wrappedValue = true
      store.binding(\.locale).wrappedValue = "en-US"
      store.value.opacity = 12
      XCTAssertEqual(store.value.opacity, 60)
      store.value.opacity = .infinity
      store.value.locale = "invalid"
      let restored = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
      XCTAssertTrue(restored.value.dark)
      XCTAssertEqual(restored.value.opacity, 60)
      XCTAssertEqual(restored.locale, "en-US")
    }
  }

  func testReadingBindingsAndWritingTheirCurrentValuesKeepsLegacyMigrationAvailable() {
    withDefaults { defaults in
      let store = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
      let opacity = store.binding(\.opacity)
      opacity.wrappedValue = opacity.wrappedValue
      let dark = store.binding(\.dark)
      dark.wrappedValue = dark.wrappedValue
      let locale = store.binding(\.locale)
      locale.wrappedValue = locale.wrappedValue
      store.set("opacity", value: store.value.opacity)
      store.set("locale", value: store.locale)
      XCTAssertNil(defaults.object(forKey: NativePreferencesStore.preferencesKey))
      XCTAssertFalse(defaults.bool(forKey: NativePreferencesStore.migrationKey))

      store.importLegacy(["dark": true, "opacity": 77], locale: "ja-JP")
      XCTAssertTrue(store.value.dark)
      XCTAssertEqual(store.value.opacity, 77)
      XCTAssertEqual(store.locale, "ja-JP")
      XCTAssertTrue(defaults.bool(forKey: NativePreferencesStore.migrationKey))
    }
  }

  func testBridgeRejectsUnknownKeysBooleanNumberCoercionAndNonfiniteNumbers() {
    withDefaults { defaults in
      let store = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
      store.set("dark", value: NSNumber(value: 1))
      store.set("showHud", value: NSNumber(value: 0))
      store.set("focus", value: "true")
      store.set("opacity", value: true)
      store.set("opacity", value: Double.nan)
      store.set("opacity", value: Double.infinity)
      store.set("opacity", value: "75")
      store.set("locale", value: "en")
      store.set("volume", value: 0)
      store.set("assistantAPIKey", value: "unexpected")
      XCTAssertEqual(store.value, NativeScenePreferences())
      XCTAssertNil(defaults.object(forKey: NativePreferencesStore.preferencesKey))

      store.set("dark", value: NSNumber(value: true))
      store.set("showHud", value: NSNumber(value: false))
      XCTAssertTrue(store.value.dark)
      XCTAssertFalse(store.value.showHud)
    }
  }

  func testOpacityClampsOnlyFiniteNumbersToSupportedRange() {
    withDefaults { defaults in
      let store = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
      store.set("opacity", value: -50)
      XCTAssertEqual(store.value.opacity, 60)
      store.set("opacity", value: 500)
      XCTAssertEqual(store.value.opacity, 100)
      store.set("opacity", value: NSNumber(value: 83.5))
      XCTAssertEqual(store.value.opacity, 83.5)
    }
  }

  func testCorruptAndNonDataNativePreferencesArePreservedUntilAnExplicitEdit() {
    withDefaults { defaults in
      let corrupt = Data("not json".utf8)
      defaults.set(corrupt, forKey: NativePreferencesStore.preferencesKey)
      let store = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
      XCTAssertEqual(store.value, NativeScenePreferences())
      XCTAssertEqual(defaults.data(forKey: NativePreferencesStore.preferencesKey), corrupt)
      store.importLegacy(["dark": true, "opacity": 75], locale: "en-US")
      XCTAssertEqual(store.value, NativeScenePreferences())
      XCTAssertTrue(defaults.bool(forKey: NativePreferencesStore.migrationKey))
      store.set("focus", value: true)
      XCTAssertTrue(NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"]).value.focus)

      defaults.set("wrong storage type", forKey: NativePreferencesStore.preferencesKey)
      let invalidType = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
      invalidType.importLegacy(["dark": true], locale: "ja-JP")
      XCTAssertEqual(invalidType.value, NativeScenePreferences())
      XCTAssertEqual(defaults.string(forKey: NativePreferencesStore.preferencesKey), "wrong storage type")
    }
  }

  func testNewerNativeSchemaIsNotOverwrittenByLegacyData() throws {
    try withDefaults { defaults in
      let store = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
      let future = try JSONSerialization.data(withJSONObject: ["version": 2, "value": store.bridgeValues])
      defaults.set(future, forKey: NativePreferencesStore.preferencesKey)
      let restored = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
      restored.importLegacy(["opacity": 65, "dark": true], locale: "ja-JP")
      XCTAssertEqual(restored.value, NativeScenePreferences())
      XCTAssertEqual(defaults.data(forKey: NativePreferencesStore.preferencesKey), future)
    }
  }

  func testStoredValuesAreNormalizedOnRead() throws {
    try withDefaults { defaults in
      var values = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"]).bridgeValues
      values["opacity"] = 200
      values["locale"] = "unsupported"
      values["dark"] = true
      let data = try JSONSerialization.data(withJSONObject: ["version": 1, "value": values])
      defaults.set(data, forKey: NativePreferencesStore.preferencesKey)
      let store = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
      XCTAssertEqual(store.value.opacity, 100)
      XCTAssertEqual(store.locale, "zh-CN")
      XCTAssertTrue(store.value.dark)
    }
  }

  func testLegacyMigrationIsValidatedAndRunsOnlyOnce() {
    withDefaults { defaults in
      let store = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
      store.importLegacy([
        "opacity": 22,
        "dark": true,
        "showHud": false,
        "focus": NSNumber(value: 1),
        "speechFeedback": false,
        "volume": 5,
      ], locale: "ja-JP")
      XCTAssertEqual(store.value.opacity, 60)
      XCTAssertTrue(store.value.dark)
      XCTAssertFalse(store.value.showHud)
      XCTAssertFalse(store.value.focus)
      XCTAssertFalse(store.value.speechFeedback)
      XCTAssertEqual(store.locale, "ja-JP")
      XCTAssertTrue(defaults.bool(forKey: NativePreferencesStore.migrationKey))

      store.importLegacy(["dark": false, "opacity": 99], locale: "en-US")
      XCTAssertEqual(store.value.opacity, 60)
      XCTAssertTrue(store.value.dark)
      XCTAssertEqual(store.locale, "ja-JP")
      let restored = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
      restored.importLegacy(["dark": false], locale: "en-US")
      XCTAssertEqual(restored.value, store.value)
    }
  }

  func testNativeEditOrResetBeforeWebLoadPreventsLegacyOverwrite() {
    withDefaults { defaults in
      let edited = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
      edited.locale = "en-US"
      edited.importLegacy(["opacity": 65, "dark": true], locale: "ja-JP")
      XCTAssertEqual(edited.locale, "en-US")
      XCTAssertFalse(edited.value.dark)
      XCTAssertEqual(edited.value.opacity, 100)

      defaults.removeObject(forKey: NativePreferencesStore.preferencesKey)
      defaults.removeObject(forKey: NativePreferencesStore.migrationKey)
      let reset = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
      reset.reset()
      reset.importLegacy(["dark": true], locale: "ja-JP")
      XCTAssertEqual(reset.value, NativeScenePreferences())
    }
  }

  func testEmptyMigrationAndMigrationMarkerStillPreventLateImport() {
    withDefaults { defaults in
      let store = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
      store.importLegacy([:], locale: nil)
      store.importLegacy(["dark": true], locale: "en-US")
      XCTAssertEqual(store.value, NativeScenePreferences())
      XCTAssertTrue(defaults.bool(forKey: NativePreferencesStore.migrationKey))
      defaults.removeObject(forKey: NativePreferencesStore.preferencesKey)
      let restored = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
      restored.importLegacy(["dark": true], locale: "ja-JP")
      XCTAssertEqual(restored.value, NativeScenePreferences())
    }
  }

  func testResetRestoresOnlyScenePreferences() {
    withDefaults { defaults in
      let otherKeys = ["augma.notes", "augma.assistant.apiKey", "augma.systemMonitor.v1", "augma.nativeAudio.v1"]
      for key in otherKeys { defaults.set("keep-\(key)", forKey: key) }
      let store = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
      store.set("dark", value: true)
      store.set("opacity", value: 70)
      store.locale = "en-US"
      store.reset()
      XCTAssertEqual(store.value, NativeScenePreferences())
      XCTAssertEqual(NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"]).value, NativeScenePreferences())
      for key in otherKeys { XCTAssertEqual(defaults.string(forKey: key), "keep-\(key)") }
    }
  }

  func testBridgeContainsSceneFieldsAndLocaleWithoutAudioVolume() {
    withDefaults { defaults in
      let bridge = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"]).bridgeValues
      XCTAssertEqual(Set(bridge.keys), [
        "opacity", "dark", "showHud", "mirror", "focus", "depthMotion", "sceneBackdrop", "curvedHud", "speechFeedback", "locale",
      ])
      XCTAssertNil(bridge["volume"])
      XCTAssertEqual(bridge["locale"] as? String, "zh-CN")
    }
  }

  private func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
    let name = "augma-native-preferences-tests-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    try body(defaults)
  }
}
