import AppKit

@MainActor
protocol ApplicationManagementOpening {
  func openGuidance(bundleID: String) throws
}

/// Navigation only. Craft Hub owns discovery and file operations; no application paths or commands cross this link.
@MainActor
struct ApplicationManagementShortcut: ApplicationManagementOpening {
  static func navigationURL(bundleID: String, scheme: String) -> URL? {
    guard ["craft-hub", "craft-hub-native"].contains(scheme), bundleID.utf8.count <= 255,
      bundleID.range(of: "^[A-Za-z0-9-]+(?:\\.[A-Za-z0-9-]+)+\\z", options: .regularExpression) != nil else { return nil }
    var parts = URLComponents()
    parts.scheme = scheme
    parts.host = "software"
    parts.queryItems = [URLQueryItem(name: "v", value: "1"), URLQueryItem(name: "bundleId", value: bundleID)]
    return parts.url
  }

  func openGuidance(bundleID: String) throws {
    for scheme in ["craft-hub", "craft-hub-native"] {
      guard let url = Self.navigationURL(bundleID: bundleID, scheme: scheme) else { throw ShortcutError.invalidApplication }
      guard NSWorkspace.shared.urlForApplication(toOpen: url) != nil else { continue }
      guard NSWorkspace.shared.open(url) else { throw ShortcutError.openFailed }
      return
    }
    throw ShortcutError.unavailable
  }

  private enum ShortcutError: LocalizedError {
    case unavailable, invalidApplication, openFailed
    var errorDescription: String? {
      switch self {
      case .unavailable: String(localized: "未找到 Craft Hub。请安装支持卸载指引的版本后重试。")
      case .invalidApplication: String(localized: "此应用的标识无法用于管理跳转。")
      case .openFailed: String(localized: "无法打开 Craft Hub，请确认已安装支持卸载指引的版本。")
      }
    }
  }
}
