import Foundation

struct ProjectFolder: Codable, Equatable, Sendable {
  var bookmark: Data
  var displayPath: String
  var securityScoped: Bool
}

struct ProjectApplication: Codable, Equatable, Sendable {
  var id: String
  var name: String
  var path: String

  init(_ app: InstalledApplication) { id = app.id; name = app.name; path = app.path }
  var building: ApplicationBuilding {
    ApplicationBuilding(id: id, applicationName: name, applicationPath: path, slot: 0)
  }
}

struct ProjectRegion: Identifiable, Codable, Equatable, Sendable {
  var id = UUID()
  var name: String
  var folder: ProjectFolder
  var editor: ProjectApplication?
  var browser: ProjectApplication?
  var websites: [String] = []
  var slot: Int
  static let capacity = 6
  var position: SIMD3<Float> { [Float(slot % 3) * 4.6 - 4.6, 0, Float(slot / 3) * 4 - 2] }
}

struct ProjectRegionDraft: Equatable {
  var name: String
  var websites: String
  init(_ region: ProjectRegion) { name = region.name; websites = region.websites.joined(separator: "\n") }
}

enum ProjectWebsite {
  static func parse(_ text: String) throws -> [String] {
    let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    guard lines.count <= 10 else { throw ProjectWorkspaceError.tooManyWebsites }
    var result: [String] = []
    for line in lines {
      guard line.count <= 2048, !line.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.union(.controlCharacters).contains($0) }),
            var components = URLComponents(string: line),
            let scheme = components.scheme?.lowercased(), ["https", "http"].contains(scheme),
            let host = components.host, !host.isEmpty,
            components.user == nil, components.password == nil,
            components.port.map({ (1...65535).contains($0) }) ?? true else { throw ProjectWorkspaceError.invalidWebsite }
      components.scheme = scheme
      components.host = host.lowercased()
      guard let url = components.url else { throw ProjectWorkspaceError.invalidWebsite }
      if !result.contains(url.absoluteString) { result.append(url.absoluteString) }
    }
    return result
  }
}

struct ProjectWorkspaceDocument: Codable, Equatable {
  var version = 1
  var regions: [ProjectRegion] = []

  func validated() throws -> Self {
    guard version == 1 else { throw ProjectWorkspaceError.newerVersion }
    guard regions.count <= ProjectRegion.capacity, Set(regions.map(\.id)).count == regions.count,
          Set(regions.map(\.slot)).count == regions.count else { throw ProjectWorkspaceError.invalidConfiguration }
    for region in regions {
      guard (0..<ProjectRegion.capacity).contains(region.slot), Self.validName(region.name),
            !region.folder.bookmark.isEmpty, region.folder.bookmark.count <= 64 * 1024,
            region.folder.displayPath.hasPrefix("/"), region.folder.displayPath.count <= 4096,
            try ProjectWebsite.parse(region.websites.joined(separator: "\n")) == region.websites else {
        throw ProjectWorkspaceError.invalidConfiguration
      }
      for (binding, expected) in [(region.editor, "com.microsoft.VSCode"), (region.browser, "com.google.Chrome")] {
        if let binding {
          guard binding.id == expected, !binding.name.isEmpty, binding.name.count <= 80,
                binding.path.hasPrefix("/"), binding.path.count <= 4096,
                URL(fileURLWithPath: binding.path).pathExtension.lowercased() == "app" else { throw ProjectWorkspaceError.invalidConfiguration }
        }
      }
    }
    return self
  }

  static func validName(_ name: String) -> Bool {
    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 60 &&
      !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
  }
}

enum ProjectWorkspaceError: LocalizedError {
  case full, invalidName, invalidWebsite, tooManyWebsites, invalidConfiguration, newerVersion
  case folderUnavailable, wrongApplication, applicationUnavailable, editorFailed, editorTimedOut
  var errorDescription: String? {
    switch self {
    case .full: String(localized: "最多可保存 6 个项目区域。")
    case .invalidName: String(localized: "项目名称不能为空，最多 60 个字符，不能包含换行。")
    case .invalidWebsite: String(localized: "请输入完整的 HTTP 或 HTTPS 网址，不含空格、用户名或密码。")
    case .tooManyWebsites: String(localized: "每个区域最多绑定 10 个工作网址。")
    case .invalidConfiguration: String(localized: "项目配置无效，原文件已保留。")
    case .newerVersion: String(localized: "项目配置来自较新版本，原文件已保留。")
    case .folderUnavailable: String(localized: "项目文件夹无法访问或书签已失效，请重新选择文件夹。")
    case .wrongApplication: String(localized: "请选择对应的 VS Code 或 Google Chrome 应用。")
    case .applicationUnavailable: String(localized: "绑定的应用不可用，请重新选择应用位置。")
    case .editorFailed: String(localized: "VS Code 未能打开项目，请检查应用安装后重试。")
    case .editorTimedOut: String(localized: "VS Code 打开请求超时，请检查编辑器后重试。")
    }
  }
}

enum ProjectOpenState: Equatable {
  case waiting, opening, opened, failed(String), cancelled
}

struct ProjectOpenItem: Identifiable, Equatable {
  let id: String
  let title: String
  var state: ProjectOpenState = .waiting
}

struct ProjectOpenReport: Equatable {
  let regionID: UUID
  var items: [ProjectOpenItem]
  var hasFailures: Bool { items.contains { if case .failed = $0.state { true } else { false } } }
}
