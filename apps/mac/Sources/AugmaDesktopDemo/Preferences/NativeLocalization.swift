import AppKit
import Foundation
import Observation
import SwiftUI
import Synchronization

/// One application language for SwiftUI, commands, and strings produced outside a view.
/// Observation invalidates translated labels without recreating windows or their editing state.
@Observable
final class NativeLocalization: @unchecked Sendable {
  static let shared = NativeLocalization()
  @ObservationIgnored private let selection = Mutex<String>("zh-CN")

  struct Context: Sendable {
    let language: String?
    let resources: URL
  }
  // Scoped overrides keep concurrent tests and background translations independent.
  @TaskLocal static var context: Context?

  var language: String {
    access(keyPath: \.language)
    return selection.withLock { $0 }
  }

  @MainActor func select(_ language: String) {
    guard NativeSceneLanguage(rawValue: language) != nil, language != NativeSceneLanguage.system.rawValue,
          language != self.language else { return }
    withMutation(keyPath: \.language) { selection.withLock { $0 = language } }
    NotificationCenter.default.post(name: .augmaAppLanguageChanged, object: nil)
  }

  static var language: String { context?.language ?? shared.language }
  static var locale: Locale { Locale(identifier: language) }

  static var bundle: Bundle {
    bundle(for: language)
  }

  static func bundle(for language: String) -> Bundle {
    let localization = language.hasPrefix("en") ? "en" : language.hasPrefix("ja") ? "ja" : "zh-Hans"
    let resources = context?.resources ?? Bundle.main.resourceURL ?? Bundle.main.bundleURL
    return Bundle(url: resources.appendingPathComponent("\(localization).lproj")) ?? .main
  }

  static func string(_ key: String, language: String? = nil) -> String {
    (language.map { bundle(for: $0) } ?? bundle).localizedString(forKey: key, value: key, table: nil)
  }
}

extension Notification.Name {
  static let augmaAppLanguageChanged = Notification.Name("cn.yunyoujun.augma.app-language-changed")
}

extension String {
  init(appLocalized value: String.LocalizationValue, comment: StaticString? = nil) {
    let language = NativeLocalization.language
    self.init(localized: value, bundle: NativeLocalization.bundle(for: language), locale: Locale(identifier: language), comment: comment)
  }
}

private struct NativeLanguageEnvironment: ViewModifier {
  var windowTitle: String?
  func body(content: Content) -> some View {
    content.environment(\.locale, NativeLocalization.locale)
      .background {
        if let windowTitle {
          NativeLocalizedWindowTitle(title: NativeLocalization.string(windowTitle)).frame(width: 0, height: 0)
        }
      }
  }
}

extension View {
  func appLocalized(windowTitle: String? = nil) -> some View {
    modifier(NativeLanguageEnvironment(windowTitle: windowTitle))
  }
}

/// Only AppKit-owned panel titles cross this boundary; SwiftUI still owns all content and state.
private struct NativeLocalizedWindowTitle: NSViewRepresentable {
  let title: String
  final class TitleView: NSView {
    var localizedTitle = ""
    override var intrinsicContentSize: NSSize { .zero }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); window?.title = localizedTitle }
  }
  func makeNSView(context: Context) -> TitleView { TitleView() }
  func updateNSView(_ view: TitleView, context: Context) {
    view.localizedTitle = title
    view.window?.title = title
  }
  func sizeThatFits(_ proposal: ProposedViewSize, nsView: TitleView, context: Context) -> CGSize? { .zero }
}
