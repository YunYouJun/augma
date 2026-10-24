import CryptoKit
import Foundation

/// References an explicitly selected local grant. Tokens are read on demand and never persisted by Augma.
struct CraftHubConnection: Codable, Equatable, Sendable {
  let origin: URL
  let credentialPath: String
  var sourceID: String { SHA256.hash(data: Data(credentialPath.utf8)).map { String(format: "%02x", $0) }.joined() }

  func validated() throws -> Self {
    guard let parts = URLComponents(url: origin, resolvingAgainstBaseURL: false),
      parts.scheme == "http", parts.host == "127.0.0.1", let port = parts.port, (1...65535).contains(port),
      parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
      parts.path.isEmpty || parts.path == "/",
      credentialPath.hasPrefix("/"), credentialPath.count <= 4096,
      !credentialPath.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
      URL(fileURLWithPath: credentialPath).standardizedFileURL.path == credentialPath
    else { throw CraftHubError.invalidConnection }
    return self
  }

  /// Reads only the generated JSON entry; command, executable and environment values are never executed.
  static func parse(_ text: String) throws -> Self {
    struct Configuration: Decodable {
      struct Server: Decodable { let args: [String] }
      let mcpServers: [String: Server]
    }
    guard text.utf8.count <= 64 * 1024,
      let config = try? JSONDecoder().decode(Configuration.self, from: Data(text.utf8)),
      let args = config.mcpServers["craft-hub"]?.args,
      let index = args.lastIndex(of: "mcp"), args.count == index + 5,
      args[index + 1] == "--url", args[index + 3] == "--credential-file",
      let url = URL(string: args[index + 2])
    else { throw CraftHubError.invalidConnection }
    return try Self(origin: url, credentialPath: args[index + 4]).validated()
  }
}

struct CraftHubProject: Decodable, Equatable, Identifiable, Sendable {
  let id: String
  let name: String
  let path: String
  let trust: String

  func validated() throws -> Self {
    guard Self.validID(id), !name.isEmpty, name.count <= 500,
      path.hasPrefix("/"), path.count <= 4096,
      !path.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
      ["trusted", "untrusted"].contains(trust)
    else { throw CraftHubError.invalidResponse }
    return self
  }
  static func validID(_ id: String) -> Bool {
    !id.isEmpty && id.utf8.count <= 128 && id.utf8.allSatisfy {
      (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95
    }
  }
}

struct CraftHubProjectContext: Decodable, Equatable, Sendable {
  struct Capability: Decodable, Equatable, Sendable {
    let id: String
    let name: String
    let kind: String
    let description: String?
  }
  struct Reference: Decodable, Equatable, Sendable {
    let repository: String
    let subdir: String?
  }
  let project: CraftHubProject
  let capabilities: [Capability]
  let reference: Reference?

  func validated(projectID: String) throws -> Self {
    _ = try project.validated()
    guard project.id == projectID, capabilities.count <= 2000,
      capabilities.allSatisfy({ !$0.id.isEmpty && $0.name.count <= 2000 && ["command", "skill"].contains($0.kind) })
    else { throw CraftHubError.invalidResponse }
    return self
  }

  /// Navigation only. A non-Git project opens the workbench home; no command or trust can be encoded.
  func navigationURL(scheme: String) -> URL? {
    guard ["craft-hub", "craft-hub-native"].contains(scheme) else { return nil }
    var parts = URLComponents()
    parts.scheme = scheme; parts.host = "open"
    parts.queryItems = [URLQueryItem(name: "v", value: "1")]
    if let reference, let repo = URLComponents(string: reference.repository), repo.scheme == "https",
      repo.host != nil, repo.user == nil, repo.password == nil, repo.fragment == nil,
      reference.repository.count <= 1600,
      reference.subdir.map({ !$0.hasPrefix("/") && !$0.contains("\\") && !$0.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) }) ?? true {
      parts.host = "project"
      parts.queryItems?.append(URLQueryItem(name: "repo", value: reference.repository))
      if let subdir = reference.subdir { parts.queryItems?.append(URLQueryItem(name: "subdir", value: subdir)) }
    }
    guard let url = parts.url, url.absoluteString.count <= 2048 else { return nil }
    return url
  }
}

/// A region keeps its independent folder, websites and layout. Only this reference links it to a shared project.
struct CraftHubProjectBinding: Codable, Equatable, Sendable {
  let sourceID: String
  let projectID: String
  var valid: Bool {
    sourceID.count == 64 && sourceID.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
      && CraftHubProject.validID(projectID)
  }
}

enum CraftHubError: LocalizedError {
  case invalidConnection, invalidResponse, credentialUnavailable, unauthorized, unavailable, disconnected, notShared, changed
  var errorDescription: String? {
    switch self {
    case .invalidConnection: String(localized: "请粘贴 Craft Hub「设置 → Agent 连接」生成的 JSON 配置。")
    case .invalidResponse: String(localized: "Craft Hub 返回了不兼容的项目资料，请更新应用后重试。")
    case .credentialUnavailable: String(localized: "无法读取连接凭据。请在 Craft Hub 启用只读访问并重新复制连接配置。")
    case .unauthorized: String(localized: "只读授权已撤销或项目未共享，请在 Craft Hub 检查授权。")
    case .unavailable: String(localized: "无法连接 Craft Hub。请保持应用运行；端口改变后需重新复制连接配置。")
    case .disconnected: String(localized: "尚未连接此项目所属的 Craft Hub。可重新连接，或解除绑定后独立使用。")
    case .notShared: String(localized: "项目已移除或不再共享。可重新选择项目，或解除绑定后独立使用。")
    case .changed: String(localized: "连接已变更，请重新选择项目。")
    }
  }
}
