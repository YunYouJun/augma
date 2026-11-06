import Foundation

struct AugmaPluginCatalog: Codable, Sendable {
  let schemaVersion: Int
  let plugins: [AugmaPluginCatalogEntry]
}

struct AugmaPluginCatalogEntry: Codable, Equatable, Sendable, Identifiable {
  let manifest: AugmaPluginManifest
  let packageURL: String
  let size: Int
  let sha256: String
  var id: String { manifest.id }

  func validated(source: URL, allowLocalHTTP: Bool = false) throws -> URL {
    _ = try manifest.validated()
    guard size > 0, size <= AugmaPluginArchive.maximumBytes,
          sha256.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil,
          let url = URL(string: packageURL, relativeTo: source)?.absoluteURL,
          AugmaPluginCatalogSource.isAllowed(source, allowLocalHTTP: allowLocalHTTP),
          AugmaPluginCatalogSource.isAllowed(url, allowLocalHTTP: allowLocalHTTP),
          url.scheme == source.scheme, url.host == source.host, url.port == source.port,
          url.standardized.path.hasPrefix(source.deletingLastPathComponent().path + "/") else {
      throw AugmaPluginDistributionError.invalidCatalog
    }
    return url
  }
}

enum AugmaPluginCatalogSource {
  static let official = URL(string: "https://augma.yyj.moe/plugins/catalog.json")!
  static var allowsLocalDevelopmentHTTP: Bool {
    #if DEBUG
    ProcessInfo.processInfo.environment["AUGMA_PLUGIN_ALLOW_LOCAL_HTTP"] == "1"
    #else
    false
    #endif
  }
  static var configured: URL {
    guard let value = ProcessInfo.processInfo.environment["AUGMA_PLUGIN_CATALOG_URL"],
          let url = URL(string: value) else { return official }
    return url
  }

  static func isAllowed(_ url: URL, allowLocalHTTP: Bool = false) -> Bool {
    guard url.user == nil, url.password == nil, url.query == nil, url.fragment == nil, url.host != nil else { return false }
    return url.scheme == "https" || (allowLocalHTTP && url.scheme == "http" && ["127.0.0.1", "localhost", "::1"].contains(url.host!))
  }
}

enum AugmaPluginDistributionError: LocalizedError {
  case invalidSource, invalidCatalog, invalidArchive, integrity, response, limit
  var errorDescription: String? {
    switch self {
    case .invalidSource: String(appLocalized: "插件目录必须使用不含凭据的 HTTPS 地址。")
    case .invalidCatalog: String(appLocalized: "远程插件目录无效，请刷新后重试。")
    case .invalidArchive: String(appLocalized: "下载的插件包无效，尚未安装。")
    case .integrity: String(appLocalized: "插件包大小或 SHA-256 校验失败，尚未安装。")
    case .response: String(appLocalized: "插件服务器未返回有效文件，请稍后重试。")
    case .limit: String(appLocalized: "远程插件目录或下载文件超过大小限制。")
    }
  }
}
