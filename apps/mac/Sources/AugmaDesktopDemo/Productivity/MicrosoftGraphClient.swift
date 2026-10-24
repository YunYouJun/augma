import Foundation

struct MicrosoftTaskList: Codable, Identifiable, Equatable, Sendable {
  let id: String
  let displayName: String
  var wellknownListName: String?
}

struct MicrosoftTokenResponse: Decodable, Sendable {
  let access_token: String
  let refresh_token: String?
  let expires_in: TimeInterval
}

struct MicrosoftHTTPError: Error {
  let status: Int
  let code: String?
}

// Do not follow redirects with bearer tokens or token request bodies.
private final class MicrosoftRedirectPolicy: NSObject, URLSessionTaskDelegate, Sendable {
  func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
    completionHandler(nil)
  }
}

struct MicrosoftGraphClient: Sendable {
  typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
  private let transport: Transport

  init(transport: Transport? = nil) {
    if let transport { self.transport = transport }
    else {
      let configuration = URLSessionConfiguration.ephemeral
      configuration.timeoutIntervalForRequest = 30
      configuration.timeoutIntervalForResource = 45
      let session = URLSession(configuration: configuration, delegate: MicrosoftRedirectPolicy(), delegateQueue: nil)
      self.transport = { request in
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
      }
    }
  }

  static func form(_ fields: [String: String]) -> Data {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
    return Data(fields.sorted { $0.key < $1.key }.map {
      "\($0.key.addingPercentEncoding(withAllowedCharacters: allowed)!)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed)!)"
    }.joined(separator: "&").utf8)
  }

  func token(clientID: String, fields: [String: String]) async throws -> MicrosoftTokenResponse {
    var request = URLRequest(url: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = Self.form(fields.merging(["client_id": clientID, "scope": MicrosoftOAuthRequest.scopes]) { _, new in new })
    return try JSONDecoder().decode(MicrosoftTokenResponse.self, from: await perform(request))
  }

  func lists(token: String) async throws -> [MicrosoftTaskList] {
    struct Page: Decodable {
      let value: [MicrosoftTaskList]
      var next: URL?
      enum CodingKeys: String, CodingKey { case value; case next = "@odata.nextLink" }
    }
    var next: URL? = URL(string: "https://graph.microsoft.com/v1.0/me/todo/lists")!
    var lists: [MicrosoftTaskList] = []
    var visited: Set<URL> = []
    while let url = next {
      guard url.scheme == "https", url.host == "graph.microsoft.com", url.port == nil || url.port == 443,
            url.user == nil, url.password == nil, url.path == "/v1.0/me/todo/lists",
            visited.insert(url).inserted, visited.count <= 100 else {
        throw CaptureError.message(String(localized: "Microsoft 返回了无效的清单分页地址。"))
      }
      var request = URLRequest(url: url)
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
      let page = try JSONDecoder().decode(Page.self, from: await perform(request))
      lists += page.value
      next = page.next
    }
    return lists
  }

  func createTask(text: String, listID: String, token: String) async throws -> String {
    // Encode an opaque Graph ID as exactly one path segment.
    let segment = listID.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
    var request = URLRequest(url: URL(string: "https://graph.microsoft.com/v1.0/me/todo/lists/\(segment)/tasks")!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "title": String((text.split(separator: "\n").first.map(String.init) ?? text).prefix(256)),
      "body": ["contentType": "text", "content": text],
    ])
    let data: Data
    do { data = try await perform(request) }
    catch let error as MicrosoftHTTPError where (400...499).contains(error.status) && error.status != 408 { throw error }
    catch { throw CaptureError.uncertain }
    struct Created: Decodable { let id: String }
    guard let result = try? JSONDecoder().decode(Created.self, from: data), !result.id.isEmpty else { throw CaptureError.uncertain }
    return result.id
  }

  private func perform(_ request: URLRequest) async throws -> Data {
    let (data, response) = try await transport(request)
    guard (200...299).contains(response.statusCode) else {
      // Never put server bodies (which can contain tokens or user content) into logs/UI.
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
      let code = json?["error"] as? String ?? (json?["error"] as? [String: Any])?["code"] as? String
      throw MicrosoftHTTPError(status: response.statusCode, code: code)
    }
    return data
  }
}
