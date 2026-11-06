import Foundation

struct AugmaPluginManifest: Codable, Equatable, Sendable, Identifiable {
  let schemaVersion: Int
  let id: String
  let name: String
  let version: String
  let author: String
  let summary: String
  let entry: String
  let symbol: String
  let permissions: [String]
  var localizations: [String: AugmaPluginMetadata]? = nil

  var displayName: String { localizedMetadata?.name ?? name }
  var displaySummary: String { localizedMetadata?.summary ?? summary }
  private var localizedMetadata: AugmaPluginMetadata? { localizations?[NativeLocalization.language] }

  func validated() throws -> Self {
    guard schemaVersion == 1 else { throw AugmaPluginError.incompatible }
    guard Self.validID(id), !name.isEmpty, name.count <= 60, !author.isEmpty, author.count <= 80,
          summary.count <= 240, !symbol.isEmpty, symbol.count <= 80,
          version.range(of: #"^[0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,4}$"#, options: .regularExpression) != nil,
          [name, author, summary, symbol].allSatisfy(Self.hasNoControls),
          Self.validPath(entry), entry.hasSuffix(".html"),
          Self.validLocalizations(localizations) else { throw AugmaPluginError.invalidManifest }
    guard permissions.isEmpty else { throw AugmaPluginError.unsupportedPermissions }
    return self
  }

  static func validID(_ id: String) -> Bool {
    id.count <= 160 && id.range(of: #"^[a-z0-9]+(?:[.-][a-z0-9]+)+$"#, options: .regularExpression) != nil
  }

  static func validLocalizations(_ values: [String: AugmaPluginMetadata]?) -> Bool {
    guard let values else { return true }
    return values.count <= 3 && values.allSatisfy { language, value in
      ["zh-CN", "en-US", "ja-JP"].contains(language) && !value.name.isEmpty && value.name.count <= 60
        && value.summary.count <= 240 && hasNoControls(value.name) && hasNoControls(value.summary)
    }
  }

  static func validPath(_ path: String) -> Bool {
    !path.isEmpty && path.count <= 512 && !path.hasPrefix("/") && !path.contains("\\")
      && !path.contains("%") && !path.contains(":")
      && !path.contains("?") && !path.contains("#")
      && path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
      && hasNoControls(path)
  }

  private static func hasNoControls(_ value: String) -> Bool {
    !value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
  }
}

struct AugmaPluginMetadata: Codable, Hashable, Sendable {
  let name: String
  let summary: String
}

struct AugmaPluginInstallation: Codable, Equatable, Sendable, Identifiable {
  let manifest: AugmaPluginManifest
  var enabled: Bool
  let installedAt: Date
  var problem: String? = nil
  var id: String { manifest.id }
}

struct AugmaPluginPackage: Equatable, Sendable {
  let manifest: AugmaPluginManifest
  let root: URL
  let files: Set<String>
}

enum AugmaPluginError: LocalizedError {
  case invalidManifest, incompatible, unsupportedPermissions, invalidPackage, tooLarge
  case alreadyInstalled, notInstalled, unavailable, unreadableRegistry, invalidRegistry

  var errorDescription: String? {
    switch self {
    case .invalidManifest: String(appLocalized: "插件清单无效，请检查标识、版本和入口。")
    case .incompatible: String(appLocalized: "此插件需要其他版本的 Augma Link。")
    case .unsupportedPermissions: String(appLocalized: "此版本仅支持无原生权限的本地网页插件。")
    case .invalidPackage: String(appLocalized: "插件包包含无效路径、链接或不支持的文件。")
    case .tooLarge: String(appLocalized: "插件包超过限制：最多 256 个文件、总计 8 MB，单个文件最多 2 MB。")
    case .alreadyInstalled: String(appLocalized: "插件已安装。请先卸载，再安装其他版本。")
    case .notInstalled: String(appLocalized: "插件尚未安装。")
    case .unavailable: String(appLocalized: "插件尚未启用或已不可用。")
    case .unreadableRegistry: String(appLocalized: "无法读取插件配置。原文件已保留，请重试。")
    case .invalidRegistry: String(appLocalized: "插件配置或安装文件无效。原文件已保留。")
    }
  }
}
