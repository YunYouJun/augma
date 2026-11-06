import AppKit

enum NativeBrowserExternalTarget: String, CaseIterable, Identifiable {
  case system, safari, chrome

  var id: String { rawValue }

  var bundleIdentifier: String? {
    switch self {
    case .system: nil
    case .safari: "com.apple.Safari"
    case .chrome: "com.google.Chrome"
    }
  }

  var title: String {
    switch self {
    case .system: String(appLocalized: "默认浏览器")
    case .safari: "Safari"
    case .chrome: "Google Chrome"
    }
  }

  var applicationURL: URL? {
    guard let bundleIdentifier else { return nil }
    return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
  }

  var isAvailable: Bool { self == .system || applicationURL != nil }

  static func open(_ url: URL, in target: Self) -> Bool {
    switch target {
    case .system:
      return NSWorkspace.shared.open(url)
    case .safari, .chrome:
      guard let applicationURL = target.applicationURL else { return false }
      let configuration = NSWorkspace.OpenConfiguration()
      configuration.activates = true
      NSWorkspace.shared.open([url], withApplicationAt: applicationURL, configuration: configuration) { _, _ in }
      return true
    }
  }
}
