import Combine
import Foundation

@MainActor
final class MicrosoftToDoStore: ObservableObject {
  @Published private(set) var clientID: String
  @Published private(set) var connected = false
  @Published private(set) var busy = false
  @Published private(set) var lists: [MicrosoftTaskList] = []
  @Published private(set) var error: String?
  @Published var selectedListID: String {
    didSet { defaults.set(selectedListID, forKey: "captureMicrosoftListID") }
  }
  private let defaults: UserDefaults
  private let bundledClientID: String
  private let vault: any MicrosoftCredentialStorage
  private let client: MicrosoftGraphClient
  private let authentication = MicrosoftWebAuthentication()
  private var credentials: MicrosoftCredentials?
  private var accessToken: String?
  private var tokenExpiry = Date.distantPast
  private var refreshTask: Task<String, Error>?
  private var loginTask: Task<Void, Never>?
  private var generation = UUID()

  init(defaults: UserDefaults = .standard, vault: any MicrosoftCredentialStorage = MicrosoftKeychain(),
       client: MicrosoftGraphClient = MicrosoftGraphClient(),
       bundledClientID: String? = Bundle.main.object(forInfoDictionaryKey: "AugmaMicrosoftClientID") as? String) {
    self.defaults = defaults
    self.vault = vault
    self.client = client
    self.bundledClientID = Self.validClientID(bundledClientID) ?? ""
    clientID = Self.validClientID(defaults.string(forKey: "captureMicrosoftClientID")) ?? self.bundledClientID
    selectedListID = defaults.string(forKey: "captureMicrosoftListID") ?? ""
    // File-based Keychain reads may present a blocking authorization dialog.
    // Restore only in response to an explicit connection or delivery action.
  }

  var configured: Bool { Self.validClientID(clientID) != nil }
  var canUseBundledClientID: Bool { !bundledClientID.isEmpty && clientID != bundledClientID }

  private static func validClientID(_ input: String?) -> String? {
    guard let value = input?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
          UUID(uuidString: value) != nil, value != "00000000-0000-0000-0000-000000000000" else { return nil }
    return value
  }

  private var connectionRequiredMessage: String {
    configured ? String(localized: "请先在快速记录的连接设置中登录 Microsoft To Do。")
      : String(localized: "此版本尚未配置 Microsoft 登录，请联系 Augma 维护者或在连接设置中配置应用 ID。")
  }

  func deliveryTarget() -> CaptureDelivery {
    CaptureDelivery(destination: .microsoftToDo, listID: selectedListID.isEmpty ? nil : selectedListID,
                    connectionID: credentials?.connectionID)
  }

  func configure(clientID input: String) {
    guard let value = Self.validClientID(input) else {
      error = String(localized: "请输入有效的 Microsoft Application（Client）ID。")
      return
    }
    guard !busy, !connected else { return }
    selectedListID = ""
    clientID = value
    defaults.set(value, forKey: "captureMicrosoftClientID")
    error = nil
  }

  func useBundledClientID() {
    guard canUseBundledClientID, !busy, !connected else { return }
    configure(clientID: bundledClientID)
    defaults.removeObject(forKey: "captureMicrosoftClientID")
  }

  func signIn() {
    guard configured, !busy else { return }
    busy = true
    error = nil
    let revision = generation
    loginTask = Task {
      defer { if generation == revision { busy = false; loginTask = nil } }
      do {
        try restoreConnectionIfNeeded()
        if connected {
          try await loadLists()
          return
        }
        let request = try MicrosoftOAuthRequest()
        let code = try await authentication.signIn(request, clientID: clientID)
        let tokens = try await client.token(clientID: clientID, fields: [
          "grant_type": "authorization_code", "code": code,
          "redirect_uri": MicrosoftOAuthRequest.redirectURI, "code_verifier": request.verifier,
        ])
        try Task.checkCancellation()
        guard generation == revision, let refresh = tokens.refresh_token, !refresh.isEmpty else {
          throw CaptureError.message(String(localized: "Microsoft 未返回持续登录授权，请重新连接。"))
        }
        let credentials = MicrosoftCredentials(refreshToken: refresh, connectionID: UUID())
        try vault.save(credentials, clientID: clientID)
        self.credentials = credentials
        connected = true
        selectedListID = ""
        accessToken = tokens.access_token
        tokenExpiry = .now.addingTimeInterval(tokens.expires_in - 60)
        try await loadLists()
      } catch {
        if generation == revision { self.error = Self.message(for: error) }
      }
    }
  }

  func cancelSignIn() {
    generation = UUID()
    authentication.cancel()
    loginTask?.cancel()
    loginTask = nil
    busy = false
  }

  func disconnect() {
    guard !busy else { return }
    do {
      try vault.remove(clientID: clientID)
      generation = UUID()
      refreshTask?.cancel()
      refreshTask = nil
      credentials = nil
      accessToken = nil
      tokenExpiry = .distantPast
      lists = []
      selectedListID = ""
      connected = false
      error = nil
    } catch { self.error = error.localizedDescription }
  }

  func refreshLists() async {
    guard !busy else { return }
    busy = true
    error = nil
    defer { busy = false }
    do {
      try restoreConnectionIfNeeded()
      try await loadLists()
    }
    catch { self.error = Self.message(for: error) }
  }

  private func restoreConnectionIfNeeded() throws {
    guard credentials == nil, configured else { return }
    credentials = try vault.load(clientID: clientID)
    connected = credentials != nil
  }

  private func loadLists() async throws {
    let revision = generation
    let token = try await authorizedToken()
    do {
      let loaded = try await client.lists(token: token)
      guard generation == revision else { throw CancellationError() }
      lists = loaded
      if selectedListID.isEmpty {
        selectedListID = loaded.first(where: { $0.wellknownListName == "defaultList" })?.id ?? loaded.first?.id ?? ""
      }
    } catch {
      invalidateTokenIfNeeded(error)
      throw error
    }
  }

  func prepare(_ delivery: CaptureDelivery) async throws -> CaptureDelivery {
    try restoreConnectionIfNeeded()
    guard let credentials, connected else {
      throw CaptureError.message(connectionRequiredMessage)
    }
    if let connection = delivery.connectionID, connection != credentials.connectionID {
      throw CaptureError.message(String(localized: "登录账户已变更。请检查内容后选择“改用当前目标重试”。"))
    }
    if lists.isEmpty { try await loadLists() }
    let id = delivery.listID ?? selectedListID
    guard lists.contains(where: { $0.id == id }) else {
      throw CaptureError.message(String(localized: "目标清单不可用。请在连接设置中刷新并选择清单，然后改用当前目标重试。"))
    }
    var result = delivery
    result.listID = id
    result.connectionID = credentials.connectionID
    return result
  }

  func createTask(_ note: QuickNote) async throws -> CaptureReceipt {
    try restoreConnectionIfNeeded()
    guard let list = note.delivery?.listID, note.delivery?.connectionID == credentials?.connectionID, connected else {
      throw CaptureError.message(String(localized: "Microsoft 连接已变更，请检查目标后重试。"))
    }
    do {
      let token = try await authorizedToken()
      let id = try await client.createTask(text: note.text, listID: list, token: token)
      return CaptureReceipt(destination: .microsoftToDo, remoteID: id)
    } catch {
      invalidateTokenIfNeeded(error)
      if error is CaptureError { throw error }
      throw CaptureError.message(Self.message(for: error))
    }
  }

  private func authorizedToken() async throws -> String {
    if let accessToken, tokenExpiry > .now { return accessToken }
    if let refreshTask { return try await refreshTask.value }
    guard let credentials else {
      throw CaptureError.message(connectionRequiredMessage)
    }
    let revision = generation
    let task = Task { @MainActor in
      let tokens = try await client.token(clientID: clientID, fields: [
        "grant_type": "refresh_token", "refresh_token": credentials.refreshToken,
      ])
      try Task.checkCancellation()
      guard generation == revision else { throw CancellationError() }
      let refreshed = MicrosoftCredentials(refreshToken: tokens.refresh_token ?? credentials.refreshToken,
                                           connectionID: credentials.connectionID)
      try vault.save(refreshed, clientID: clientID)
      self.credentials = refreshed
      accessToken = tokens.access_token
      tokenExpiry = .now.addingTimeInterval(tokens.expires_in - 60)
      return tokens.access_token
    }
    refreshTask = task
    defer { if generation == revision { refreshTask = nil } }
    do { return try await task.value }
    catch {
      if let failure = error as? MicrosoftHTTPError, failure.code == "invalid_grant" {
        self.error = String(localized: "Microsoft 登录已过期，请断开后重新连接。")
      }
      throw error
    }
  }

  private func invalidateTokenIfNeeded(_ error: Error) {
    if let failure = error as? MicrosoftHTTPError, failure.status == 401 {
      accessToken = nil
      tokenExpiry = .distantPast
    }
  }

  static func message(for error: Error) -> String {
    if let failure = error as? MicrosoftHTTPError {
      if failure.code == "invalid_grant" || failure.code == "interaction_required" {
        return String(localized: "Microsoft 登录已过期，请断开后重新连接。")
      }
      switch failure.status {
      case 401: return String(localized: "Microsoft 登录已过期，请重新连接或重试。")
      case 403: return String(localized: "Microsoft 拒绝了待办访问，请检查账户授权或组织策略。")
      case 404: return String(localized: "Microsoft 清单不存在，请刷新并重新选择清单。")
      case 429: return String(localized: "Microsoft 请求过于频繁，请稍后重试。")
      default: return String(format: String(localized: "Microsoft 请求失败（%@），请检查连接设置后重试。"), String(failure.status))
      }
    }
    return error.localizedDescription
  }
}
