import Combine
import CoreFoundation
import Foundation
import SwiftUI

struct NativeScenePreferences: Codable, Equatable, Sendable {
  var opacity: Double = 100
  var dark = false
  var showHud = true
  var mirror = false
  var focus = false
  var depthMotion = false
  var sceneBackdrop = true
  var curvedHud = false
  var speechFeedback = true
  var locale = "zh-CN"

  fileprivate func normalized(fallback: NativeScenePreferences) -> NativeScenePreferences {
    var result = self
    result.opacity = opacity.isFinite ? min(100, max(60, opacity)) : fallback.opacity
    if NativeSceneLanguage(rawValue: locale) == nil { result.locale = fallback.locale }
    return result
  }
}

enum NativeSceneLanguage: String, CaseIterable, Identifiable, Sendable {
  case simplifiedChinese = "zh-CN"
  case english = "en-US"
  case japanese = "ja-JP"

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .simplifiedChinese: "简体中文"
    case .english: "English"
    case .japanese: "日本語"
    }
  }
}

/// The app owns scene preferences even when no simulator WebView exists.
@MainActor
final class NativePreferencesStore: ObservableObject {
  static let preferencesKey = "augma.nativeScenePreferences.v1"
  static let migrationKey = "augma.nativeScenePreferences.migrated.v1"

  @Published var value: NativeScenePreferences {
    didSet {
      guard !isNormalizing else { return }
      let normalized = value.normalized(fallback: oldValue)
      if normalized != value {
        isNormalizing = true
        value = normalized
        isNormalizing = false
      }
      save()
    }
  }

  var locale: String {
    get { value.locale }
    set { set("locale", value: newValue) }
  }

  var bridgeValues: [String: Any] {
    [
      "opacity": value.opacity,
      "dark": value.dark,
      "showHud": value.showHud,
      "mirror": value.mirror,
      "focus": value.focus,
      "depthMotion": value.depthMotion,
      "sceneBackdrop": value.sceneBackdrop,
      "curvedHud": value.curvedHud,
      "speechFeedback": value.speechFeedback,
      "locale": value.locale,
    ]
  }

  private struct SavedPreferences: Codable {
    let version: Int
    let value: NativeScenePreferences
  }

  private let defaults: UserDefaults
  private let defaultValue: NativeScenePreferences
  private var hasNativeSource: Bool
  private var isNormalizing = false

  init(defaults: UserDefaults = .standard, preferredLocalizations: [String] = Bundle.main.preferredLocalizations) {
    self.defaults = defaults
    var initialValue = NativeScenePreferences()
    initialValue.locale = Self.defaultLocale(for: preferredLocalizations)
    defaultValue = initialValue
    let existing = defaults.object(forKey: Self.preferencesKey)
    hasNativeSource = existing != nil || defaults.bool(forKey: Self.migrationKey)
    if let data = existing as? Data,
       let saved = try? JSONDecoder().decode(SavedPreferences.self, from: data),
       saved.version == 1 {
      value = saved.value.normalized(fallback: initialValue)
    } else {
      // Keep corrupt or newer-version bytes until an explicit edit/reset. A
      // simulator's older localStorage must never replace native user data.
      value = initialValue
    }
    if hasNativeSource { defaults.set(true, forKey: Self.migrationKey) }
  }

  /// Accept only bridge fields and their actual JSON types. NSNumber's coercion
  /// of `1` to `true` (and `true` to `1`) must not turn malformed input into edits.
  func set(_ key: String, value incoming: Any) {
    var next = value
    guard Self.apply(key, incoming: incoming, to: &next) else { return }
    guard next != value else { return }
    value = next
  }

  func binding<Value: Equatable>(_ keyPath: WritableKeyPath<NativeScenePreferences, Value>) -> Binding<Value> {
    Binding(
      get: { self.value[keyPath: keyPath] },
      set: { next in
        guard self.value[keyPath: keyPath] != next else { return }
        self.value[keyPath: keyPath] = next
      }
    )
  }

  /// Migration runs at most once. Native edits, including a reset before the
  /// simulator first opens, establish native ownership and prevent late imports.
  func importLegacy(_ dictionary: [String: Any], locale: String?) {
    guard !hasNativeSource else { return }
    var imported = defaultValue
    for (key, incoming) in dictionary {
      _ = Self.apply(key, incoming: incoming, to: &imported)
    }
    if let locale { _ = Self.apply("locale", incoming: locale, to: &imported) }
    value = imported
  }

  func reset() {
    value = defaultValue
  }

  private static func defaultLocale(for localizations: [String]) -> String {
    for localization in localizations {
      switch localization.lowercased().split(separator: "-").first {
      case "zh": return NativeSceneLanguage.simplifiedChinese.rawValue
      case "en": return NativeSceneLanguage.english.rawValue
      case "ja": return NativeSceneLanguage.japanese.rawValue
      default: continue
      }
    }
    return NativeSceneLanguage.simplifiedChinese.rawValue
  }

  private func save() {
    hasNativeSource = true
    defaults.set(true, forKey: Self.migrationKey)
    if let data = try? JSONEncoder().encode(SavedPreferences(version: 1, value: value)) {
      defaults.set(data, forKey: Self.preferencesKey)
    }
  }

  private static func apply(_ key: String, incoming: Any, to preferences: inout NativeScenePreferences) -> Bool {
    switch key {
    case "locale":
      guard let locale = incoming as? String, NativeSceneLanguage(rawValue: locale) != nil else { return false }
      preferences.locale = locale
    case "opacity":
      guard let number = incoming as? NSNumber,
            CFGetTypeID(number) != CFBooleanGetTypeID(),
            number.doubleValue.isFinite else { return false }
      preferences.opacity = min(100, max(60, number.doubleValue))
    default:
      guard let keyPath = booleanFields[key],
            let number = incoming as? NSNumber,
            CFGetTypeID(number) == CFBooleanGetTypeID() else { return false }
      preferences[keyPath: keyPath] = number.boolValue
    }
    return true
  }

  private static let booleanFields: [String: WritableKeyPath<NativeScenePreferences, Bool>] = [
    "dark": \.dark,
    "showHud": \.showHud,
    "mirror": \.mirror,
    "focus": \.focus,
    "depthMotion": \.depthMotion,
    "sceneBackdrop": \.sceneBackdrop,
    "curvedHud": \.curvedHud,
    "speechFeedback": \.speechFeedback,
  ]
}
