import AppKit
import Combine
import Foundation

struct AssistantConfigOption: Identifiable, Equatable {
  struct Choice: Identifiable, Equatable { let id: String; let name: String }
  let id: String
  let name: String
  let current: String
  let choices: [Choice]
  static func parse(_ value: ACPValue) -> [AssistantConfigOption] {
    value.array.compactMap { item in
      guard let id = item["id"].string, ["model", "reasoning_effort"].contains(id),
        item["type"].string == "select", let current = item["currentValue"].string else { return nil }
      func choices(_ values: [ACPValue]) -> [Choice] {
        values.flatMap { option in
          if let id = option["value"].string, let name = option["name"].string { return [Choice(id: id, name: name)] }
          return option["options"].array.compactMap { child in
            guard let id = child["value"].string, let name = child["name"].string else { return nil }
            return Choice(id: id, name: name)
          }
        }
      }
      return .init(id: id, name: item["name"].string ?? id, current: current, choices: choices(item["options"].array))
    }
  }
}

struct AssistantPermission: Identifiable {
  let id = UUID()
  let owner: UUID
  let title: String
  let resolve: (Bool) -> Void
}

/// One process per app, one ACP session per window/business scope. DSH owns model history.
@MainActor
final class NativeAssistantRuntime: ObservableObject {
  static let shared = NativeAssistantRuntime()
  @Published private(set) var status = ""
  @Published private(set) var options: [AssistantConfigOption] = []
  @Published private(set) var permission: AssistantPermission?
  @Published private(set) var connected = false
  private let connection = ACPConnection()
  private(set) var lastStartupSeconds: Double = 0
  private(set) var lastFirstFeedbackSeconds: Double?
  private(set) var lastTaskSeconds: Double = 0
  private let defaults: UserDefaults
  private let supportRoot: URL?
  private let loadCatalog: @Sendable () async throws -> MagpieCatalog
  private var startup: Task<Void, Error>?
  private var startupGeneration = UUID()
  private var runtimeHome: URL?
  private var sessions: [UUID: RuntimeSession] = [:]
  private var taskTickets: [UUID: UUID] = [:]
  private var resumable: [UUID: String] = [:]
  private var observers: [AnyCancellable] = []
  private var idleStop: Task<Void, Never>?
  private var discoveredModel = ""
  private var configuration = ""

  private final class RuntimeSession {
    let id: String
    let scope: NativeToolScope?
    let bridge: NativeMCPBridge?
    var active = false
    var startedAt = Date()
    var text = ""
    var onEvent: ((String) -> Void)?
    init(id: String, scope: NativeToolScope?, bridge: NativeMCPBridge?) { self.id = id; self.scope = scope; self.bridge = bridge }
  }

  init(defaults: UserDefaults = .standard, supportRoot: URL? = nil,
       loadCatalog: @escaping @Sendable () async throws -> MagpieCatalog = { try await MagpieCatalog.load() }) {
    self.defaults = defaults
    self.supportRoot = supportRoot
    self.loadCatalog = loadCatalog
    connection.notification = { [weak self] method, params in self?.receive(method, params) }
    connection.incomingRequest = { [weak self] method, params in
      guard method == "session/request_permission" else { return nil }
      guard let self else { return .object(["outcome": .object(["outcome": .string("cancelled")])]) }
      return await self.requestPermission(method, params)
    }
    connection.disconnected = { [weak self] in self?.didDisconnect() }
    NotificationCenter.default.publisher(for: .augmaDeepSeekConfigChanged)
      .sink { [weak self] _ in self?.shutdown(preserveIdle: false) }.store(in: &observers)
    NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)
      .receive(on: RunLoop.main).sink { [weak self] _ in self?.shutdown(preserveIdle: true) }.store(in: &observers)
    NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
      .sink { [weak self] _ in self?.shutdown(preserveIdle: true) }.store(in: &observers)
  }

  var processIdentifier: Int32? { connection.processIdentifier }
  func sessionIdentifier(owner: UUID) -> String? { sessions[owner]?.id }

  func connect() async throws {
    if defaults === UserDefaults.standard {
      AssistantMagpieConfiguration.shared.refresh()
      guard AssistantMagpieConfiguration.shared.failure.isEmpty else { throw AssistantRuntimeError.unsafeConfiguration }
    }
    idleStop?.cancel()
    if connected, connection.isRunning, configuration == AssistantRuntimeSettings.fingerprint(defaults) { return }
    if let startup { return try await startup.value }
    let token = UUID(); startupGeneration = token
    let task = Task { [weak self] in
      guard let self else { throw CancellationError() }
      let startedAt = Date()
      self.status = String(localized: "正在连接 DSH…")
      do {
        let executable = try await DSHInstallation.resolve(path: self.defaults.string(forKey: AssistantRuntimeSettings.executableKey) ?? "")
        try Task.checkCancellation()
        guard self.startupGeneration == token else { throw CancellationError() }
        let catalog = try await self.loadCatalog()
        try Task.checkCancellation()
        guard self.startupGeneration == token else { throw CancellationError() }
        let selected = self.defaults.string(forKey: AssistantRuntimeSettings.modelKey) ?? ""
        let model = selected.isEmpty ? catalog.models[0].id : selected
        self.discoveredModel = model
        let support = self.supportRoot ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
          .appendingPathComponent("Augma/Assistant")
        let home = support.appendingPathComponent("Runtime/\(UUID().uuidString)")
        try AugmaDSHProfile.write(home: home, sessions: support.appendingPathComponent("Sessions"), catalog: catalog, model: model)
        self.runtimeHome = home
        try self.connection.start(executable: executable, arguments: ["--profile", "augma"], directory: home,
                                  environment: DSHInstallation.environment(home: home))
        let result = try await self.connection.request("initialize", .object([
          "protocolVersion": .number(1), "clientCapabilities": .object([:]),
          "clientInfo": .object(["name": .string("Augma"), "version": .string("1")])
        ]))
        guard result["protocolVersion"] == .number(1), result["agentInfo"]["name"].string == "deepseek-harness-acp",
          result["agentCapabilities"]["mcpCapabilities"]["http"] == .bool(true),
          result["agentCapabilities"]["sessionCapabilities"]["close"].object != nil,
          result["agentCapabilities"]["sessionCapabilities"]["resume"].object != nil else { throw AssistantRuntimeError.protocolViolation }
        try Task.checkCancellation()
        guard self.startupGeneration == token else { throw CancellationError() }
        self.configuration = AssistantRuntimeSettings.fingerprint(self.defaults)
        self.lastStartupSeconds = Date().timeIntervalSince(startedAt)
        self.connected = true
        self.status = String(localized: "DSH 已连接")
      } catch {
        if self.startupGeneration == token {
          self.connection.stop(); self.connected = false
          self.status = (error as? AssistantRuntimeError)?.localizedDescription ?? AssistantRuntimeError.launchFailed.localizedDescription
          self.removeRuntimeHome()
        }
        throw error
      }
    }
    startup = task
    defer { if startupGeneration == token { startup = nil } }
    try await task.value
  }

  private func session(owner: UUID, scope: NativeToolScope?, ticket: UUID? = nil) async throws -> RuntimeSession {
    try await connect()
    if let ticket, taskTickets[owner] != ticket { throw CancellationError() }
    if let existing = sessions[owner] { return existing }
    guard let runtimeHome else { throw AssistantRuntimeError.disconnected }
    let bridge = scope.map(NativeMCPBridge.init)
    do {
      let mcp = try await bridge?.start()
      try Task.checkCancellation()
      var params: [String: ACPValue] = ["cwd": .string(runtimeHome.deletingLastPathComponent().deletingLastPathComponent().path),
        "mcpServers": .array(mcp.map { [$0] } ?? [])]
      let resumedID = resumable.removeValue(forKey: owner)
      if let resumedID { params["sessionId"] = .string(resumedID) }
      let result = try await connection.request(resumedID == nil ? "session/new" : "session/resume", .object(params))
      guard let id = resumedID ?? result["sessionId"].string else { throw AssistantRuntimeError.protocolViolation }
      if let ticket, taskTickets[owner] != ticket {
        _ = try? await connection.request("session/close", .object(["sessionId": .string(id)]), timeout: 5)
        throw CancellationError()
      }
      let session = RuntimeSession(id: id, scope: scope, bridge: bridge)
      sessions[owner] = session
      options = AssistantConfigOption.parse(result["configOptions"])
      let selected = self.defaults.string(forKey: AssistantRuntimeSettings.modelKey) ?? discoveredModel
      if !selected.isEmpty {
        guard let choice = options.first(where: { $0.id == "model" })?.choices.first(where: {
          guard let data = $0.id.data(using: .utf8), let parts = try? JSONDecoder().decode([String].self, from: data) else { return false }
          return parts == ["magpie", selected]
        }) else { throw AssistantRuntimeError.modelUnavailable }
        try await setOption(session: session, id: "model", value: choice.id)
      }
      let reasoning = self.defaults.string(forKey: AssistantRuntimeSettings.reasoningKey) ?? ""
      if !reasoning.isEmpty { try await setOption(session: session, id: "reasoning_effort", value: reasoning) }
      return session
    } catch {
      bridge?.stop()
      // An interrupted admission may leave an unused remote session until idle shutdown.
      // Its bridge is revoked; do not interrupt other windows by killing their shared process.
      cancel(owner: owner, expectedTicket: ticket)
      throw error
    }
  }

  private func setOption(session: RuntimeSession, id: String, value: String) async throws {
    guard options.first(where: { $0.id == id })?.choices.contains(where: { $0.id == value }) == true else {
      throw AssistantRuntimeError.modelUnavailable
    }
    let result = try await connection.request("session/set_config_option", .object([
      "sessionId": .string(session.id), "configId": .string(id), "value": .string(value)]))
    options = AssistantConfigOption.parse(result["configOptions"])
  }

  func discoverOptions() async throws -> [AssistantConfigOption] {
    let owner = UUID()
    defer { cancel(owner: owner) }
    _ = try await session(owner: owner, scope: nil)
    return options
  }

  func complete(messages: [[String: String]], owner: UUID, scope: NativeToolScope? = nil,
                testing: Bool = false, onEvent: ((String) -> Void)? = nil) async throws -> String {
    if defaults === UserDefaults.standard { AssistantMagpieConfiguration.shared.refresh() }
    guard testing || AssistantRuntimeSettings.isReady else { throw AssistantRuntimeError.notEnabled }
    if !testing, AssistantRuntimeSettings.backend() == .deepseek {
      guard let key = DeepSeekKeychain.load() else { throw DeepSeekClient.Failure.invalidKey }
      return try await DeepSeekClient.complete(messages, apiKey: key)
    }
    let validated = try DeepSeekClient.validate(messages)
    // Exactly the current task: UI history is never replayed into DSH's persistent context.
    guard validated.count == 2 else { throw AssistantRuntimeError.protocolViolation }
    guard taskTickets[owner] == nil else { throw AssistantRuntimeError.taskFailed }
    let ticket = UUID(); taskTickets[owner] = ticket
    defer {
      if taskTickets[owner] == ticket { taskTickets.removeValue(forKey: owner) }
      scheduleIdleStop()
    }
    return try await withTaskCancellationHandler {
      let session = try await session(owner: owner, scope: scope, ticket: ticket)
      try Task.checkCancellation()
      guard !session.active else { throw AssistantRuntimeError.taskFailed }
      session.text = ""; session.active = true; session.startedAt = Date(); lastFirstFeedbackSeconds = nil; session.onEvent = onEvent; session.scope?.begin()
      defer { lastTaskSeconds = Date().timeIntervalSince(session.startedAt); session.active = false; session.scope?.revoke(); session.onEvent = nil; scheduleIdleStop() }
      do {
        let result = try await connection.request("session/prompt", .object(["sessionId": .string(session.id),
          "prompt": .array([.text(validated.compactMap { $0["content"] }.joined(separator: "\n\n"))])]), timeout: 90)
        try Task.checkCancellation()
        guard sessions[owner] === session else { throw CancellationError() }
        guard result["stopReason"].string == "end_turn", !session.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          throw result["stopReason"].string == "cancelled" ? CancellationError() : AssistantRuntimeError.taskFailed
        }
        return session.text
      } catch { cancel(owner: owner, expectedTicket: ticket); throw error }
    } onCancel: { Task { @MainActor [weak self] in self?.cancel(owner: owner, expectedTicket: ticket) } }
  }

  func cancel(owner: UUID, expectedTicket: UUID? = nil) {
    if let expectedTicket, taskTickets[owner] != expectedTicket { return }
    taskTickets.removeValue(forKey: owner)
    resumable.removeValue(forKey: owner)
    if permission?.owner == owner { permission?.resolve(false) }
    guard let session = sessions.removeValue(forKey: owner) else { scheduleIdleStop(); return }
    session.scope?.revoke(); session.bridge?.stop(); session.onEvent = nil
    connection.notify("session/cancel", .object(["sessionId": .string(session.id)]))
    let pid = connection.processIdentifier
    Task { [weak self] in
      guard let self else { return }
      do { _ = try await self.connection.request("session/close", .object(["sessionId": .string(session.id)]), timeout: 5) }
      catch { if self.connection.isRunning && self.connection.processIdentifier == pid { self.shutdown(preserveIdle: true) } }
      self.scheduleIdleStop()
    }
  }

  private func receive(_ method: String, _ params: ACPValue) {
    guard method == "session/update", let id = params["sessionId"].string,
      let session = sessions.values.first(where: { $0.id == id && $0.active }) else { return }
    if lastFirstFeedbackSeconds == nil { lastFirstFeedbackSeconds = Date().timeIntervalSince(session.startedAt) }
    let update = params["update"]
    switch update["sessionUpdate"].string {
    case "agent_message_chunk":
      guard update["content"]["type"].string == "text", let text = update["content"]["text"].string else { return }
      guard session.text.utf8.count + text.utf8.count <= 16_384 else { connection.stop(error: AssistantRuntimeError.protocolViolation); return }
      session.text += text; session.onEvent?(String(localized: "正在生成回答…"))
    case "tool_call", "tool_call_update": session.onEvent?(String(localized: "正在读取原生工具结果…"))
    case "config_option_update": options = AssistantConfigOption.parse(update["configOptions"])
    default: break
    }
  }

  private func requestPermission(_ method: String, _ params: ACPValue) async -> ACPValue {
    let cancelled = ACPValue.object(["outcome": .object(["outcome": .string("cancelled")])])
    guard method == "session/request_permission", permission == nil,
      let pair = sessions.first(where: { $0.value.id == params["sessionId"].string && $0.value.active }),
      let scope = pair.value.scope, scope.active,
      let allow = params["options"].array.first(where: { $0["kind"].string == "allow_once" })?["optionId"].string,
      let deny = params["options"].array.first(where: { $0["kind"].string == "reject_once" })?["optionId"].string else { return cancelled }
    // The isolated profile only mounts our three tools. Do not show arbitrary provider text in confirmations.
    return await withCheckedContinuation { continuation in
      var resolved = false
      permission = AssistantPermission(owner: pair.key, title: String(localized: "允许本次原生工具请求？")) { [weak self, weak scope] accepted in
        guard !resolved else { return }; resolved = true
        let valid = accepted && scope?.active == true && self?.sessions[pair.key] === pair.value
        self?.permission = nil
        continuation.resume(returning: .object(["outcome": .object(["outcome": .string("selected"), "optionId": .string(valid ? allow : deny)])]))
      }
    }
  }

  private func scheduleIdleStop() {
    idleStop?.cancel()
    guard taskTickets.isEmpty, !sessions.values.contains(where: \.active) else { return }
    idleStop = Task { [weak self] in
      try? await Task.sleep(for: .seconds(60))
      guard !Task.isCancelled else { return }
      self?.shutdown(preserveIdle: true)
    }
  }
  private func didDisconnect() {
    connected = false; permission?.resolve(false)
    status = AssistantRuntimeError.disconnected.localizedDescription
    for (owner, session) in sessions {
      if !session.active { resumable[owner] = session.id }
      session.scope?.revoke(); session.bridge?.stop()
    }
    sessions.removeAll()
    removeRuntimeHome()
  }
  func shutdown(preserveIdle: Bool = false) {
    idleStop?.cancel(); idleStop = nil
    startupGeneration = UUID(); startup?.cancel(); startup = nil
    if !preserveIdle { resumable.removeAll() }
    permission?.resolve(false)
    for (owner, session) in sessions {
      if preserveIdle && !session.active { resumable[owner] = session.id }
      session.scope?.revoke(); session.bridge?.stop()
    }
    sessions.removeAll(); taskTickets.removeAll()
    connection.stop(); connected = false
    status = preserveIdle ? String(localized: "DSH 已暂停，将在下次请求时连接。") : ""
    removeRuntimeHome()
  }
  func shutdownAndWait() async {
    let process = connection.ownedProcess
    shutdown()
    if let process { await Task.detached { process.waitUntilExit() }.value }
  }
  private func removeRuntimeHome() {
    if let runtimeHome { try? FileManager.default.removeItem(at: runtimeHome) }
    runtimeHome = nil
  }
}
