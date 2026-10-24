import AppKit
import AuthenticationServices
import CryptoKit
import Security

struct MicrosoftCredentials: Codable, Sendable {
  var refreshToken: String
  var connectionID: UUID
}

@MainActor
protocol MicrosoftCredentialStorage {
  func load(clientID: String) throws -> MicrosoftCredentials?
  func save(_ credentials: MicrosoftCredentials, clientID: String) throws
  func remove(clientID: String) throws
}

struct MicrosoftKeychain: MicrosoftCredentialStorage {
  private func identity(_ clientID: String) -> [String: Any] {
    [kSecClass as String: kSecClassGenericPassword,
     kSecAttrService as String: "cn.yunyoujun.augma.microsoft-todo",
     kSecAttrAccount as String: clientID]
  }

  func load(clientID: String) throws -> MicrosoftCredentials? {
    var query = identity(clientID)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    try check(status)
    guard let data = result as? Data else { throw CaptureError.message(String(localized: "无法读取 Microsoft 登录信息，请重新连接。")) }
    return try JSONDecoder().decode(MicrosoftCredentials.self, from: data)
  }

  func save(_ credentials: MicrosoftCredentials, clientID: String) throws {
    let data = try JSONEncoder().encode(credentials)
    let status = SecItemUpdate(identity(clientID) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    if status == errSecItemNotFound {
      var item = identity(clientID)
      item[kSecValueData as String] = data
      item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      try check(SecItemAdd(item as CFDictionary, nil))
    } else { try check(status) }
  }

  func remove(clientID: String) throws {
    let status = SecItemDelete(identity(clientID) as CFDictionary)
    if status != errSecItemNotFound { try check(status) }
  }

  private func check(_ status: OSStatus) throws {
    guard status == errSecSuccess else {
      throw CaptureError.message(String(format: String(localized: "无法访问钥匙串（错误 %@）。"), String(status)))
    }
  }
}

struct MicrosoftOAuthRequest: Sendable {
  static let redirectURI = "msauth.cn.yunyoujun.augma.desktop-demo://auth"
  static let callbackScheme = "msauth.cn.yunyoujun.augma.desktop-demo"
  static let scopes = "https://graph.microsoft.com/Tasks.ReadWrite offline_access"
  let verifier: String
  let state: String

  init() throws {
    func random() throws -> String {
      var bytes = [UInt8](repeating: 0, count: 32)
      guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
        throw CaptureError.message(String(localized: "无法安全启动登录，请重试。"))
      }
      return Self.base64URL(Data(bytes))
    }
    verifier = try random()
    state = try random()
  }

  static func base64URL(_ data: Data) -> String {
    data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
  }

  func authorizationURL(clientID: String) -> URL {
    var url = URLComponents(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!
    url.queryItems = [
      .init(name: "client_id", value: clientID), .init(name: "response_type", value: "code"),
      .init(name: "redirect_uri", value: Self.redirectURI), .init(name: "response_mode", value: "query"),
      .init(name: "scope", value: Self.scopes), .init(name: "state", value: state),
      .init(name: "code_challenge", value: Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))),
      .init(name: "code_challenge_method", value: "S256"), .init(name: "prompt", value: "select_account"),
    ]
    return url.url!
  }

  func code(from callback: URL) throws -> String {
    guard callback.scheme == Self.callbackScheme, callback.host == "auth",
          callback.path.isEmpty || callback.path == "/",
          let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems,
          items.filter({ $0.name == "state" }).count == 1,
          items.first(where: { $0.name == "state" })?.value == state else {
      throw CaptureError.message(String(localized: "登录回调校验失败，请重新连接。"))
    }
    guard !items.contains(where: { $0.name == "error" }),
          items.filter({ $0.name == "code" }).count == 1,
          let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
      throw CaptureError.message(String(localized: "Microsoft 登录未完成或未获授权。"))
    }
    return code
  }
}

@MainActor
final class MicrosoftWebAuthentication: NSObject, ASWebAuthenticationPresentationContextProviding {
  private var session: ASWebAuthenticationSession?
  private var attempt = UUID()

  func signIn(_ request: MicrosoftOAuthRequest, clientID: String) async throws -> String {
    let attempt = UUID()
    self.attempt = attempt
    defer { if self.attempt == attempt { session = nil } }
    let callback: URL = try await withCheckedThrowingContinuation { continuation in
      let session = ASWebAuthenticationSession(url: request.authorizationURL(clientID: clientID),
                                             callbackURLScheme: MicrosoftOAuthRequest.callbackScheme,
                                             completionHandler: Self.completionHandler(continuation))
      self.session = session
      session.presentationContextProvider = self
      session.prefersEphemeralWebBrowserSession = true
      if !session.start() {
        continuation.resume(throwing: CaptureError.message(String(localized: "无法打开登录窗口，请重试。")))
      }
    }
    return try request.code(from: callback)
  }

  // Safari can deliver this callback on its XPC queue. Construct it outside
  // MainActor isolation; resuming the continuation returns signIn to MainActor.
  nonisolated static func completionHandler(_ continuation: CheckedContinuation<URL, Error>) -> @Sendable (URL?, (any Error)?) -> Void {
    { url, error in
      if let url { continuation.resume(returning: url) }
      else { continuation.resume(throwing: error ?? CaptureError.message(String(localized: "Microsoft 登录未完成或未获授权。"))) }
    }
  }

  func cancel() { attempt = UUID(); session?.cancel(); session = nil }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    NSApp.keyWindow ?? NSApp.mainWindow ?? ASPresentationAnchor()
  }
}
