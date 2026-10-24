import Foundation

@MainActor
protocol CraftHubReading {
  func projects(_ connection: CraftHubConnection) async throws -> [CraftHubProject]
  func context(_ connection: CraftHubConnection, projectID: String) async throws -> CraftHubProjectContext
}

/// Direct, read-only HTTP adapter. It never starts the MCP command or forwards a native host credential.
@MainActor
final class CraftHubClient: CraftHubReading {
  typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
  private let transport: Transport
  private let credential: (String) throws -> Data

  init(transport: Transport? = nil, credential: @escaping (String) throws -> Data = CraftHubClient.readCredential) {
    self.credential = credential
    self.transport = transport ?? { request in
      let config = URLSessionConfiguration.ephemeral
      config.timeoutIntervalForRequest = 10
      config.timeoutIntervalForResource = 15
      config.httpShouldSetCookies = false
      config.httpCookieStorage = nil
      config.urlCredentialStorage = nil
      config.connectionProxyDictionary = [:]
      let session = URLSession(configuration: config, delegate: CraftHubRedirectPolicy(), delegateQueue: nil)
      defer { session.invalidateAndCancel() }
      let (bytes, response) = try await session.bytes(for: request)
      guard let http = response as? HTTPURLResponse, http.expectedContentLength <= 2 * 1024 * 1024 else { throw CraftHubError.invalidResponse }
      var data = Data()
      for try await byte in bytes {
        guard data.count < 2 * 1024 * 1024 else { throw CraftHubError.invalidResponse }
        data.append(byte)
      }
      return (data, http)
    }
  }

  func projects(_ connection: CraftHubConnection) async throws -> [CraftHubProject] {
    let data = try await call(connection, name: "craft_hub_projects")
    guard let projects = try? JSONDecoder().decode([CraftHubProject].self, from: data),
      projects.count <= 200, Set(projects.map(\.id)).count == projects.count else { throw CraftHubError.invalidResponse }
    return try projects.map { try $0.validated() }
  }

  func context(_ connection: CraftHubConnection, projectID: String) async throws -> CraftHubProjectContext {
    guard CraftHubProject.validID(projectID) else { throw CraftHubError.invalidResponse }
    let data = try await call(connection, name: "craft_hub_project_context", arguments: ["projectId": projectID])
    guard let context = try? JSONDecoder().decode(CraftHubProjectContext.self, from: data) else { throw CraftHubError.invalidResponse }
    return try context.validated(projectID: projectID)
  }

  private func call(_ connection: CraftHubConnection, name: String, arguments: [String: String] = [:]) async throws -> Data {
    let connection = try connection.validated()
    struct Credential: Decodable { let token: String }
    guard let data = try? credential(connection.credentialPath), data.count <= 64 * 1024,
      let secret = try? JSONDecoder().decode(Credential.self, from: data), secret.token.count == 64,
      secret.token.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { throw CraftHubError.credentialUnavailable }
    var request = URLRequest(url: connection.origin.appending(path: "api/agent-access"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer " + secret.token, forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONSerialization.data(withJSONObject: ["name": name, "arguments": arguments])
    do {
      let (data, response) = try await transport(request)
      try Task.checkCancellation()
      guard response.url == request.url, data.count <= 2 * 1024 * 1024 else { throw CraftHubError.invalidResponse }
      if response.statusCode == 401 || response.statusCode == 403 { throw CraftHubError.unauthorized }
      guard response.statusCode == 200 else { throw CraftHubError.unavailable }
      return data
    } catch is CancellationError { throw CancellationError() }
    catch let error as CraftHubError { throw error }
    catch { throw CraftHubError.unavailable }
  }

  nonisolated private static func readCredential(_ path: String) throws -> Data {
    let url = URL(fileURLWithPath: path)
    let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
    guard values.isRegularFile == true, (values.fileSize ?? 0) <= 64 * 1024 else { throw CraftHubError.credentialUnavailable }
    return try Data(contentsOf: url)
  }
}

private final class CraftHubRedirectPolicy: NSObject, URLSessionTaskDelegate, Sendable {
  func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
    completionHandler(nil)
  }
}
