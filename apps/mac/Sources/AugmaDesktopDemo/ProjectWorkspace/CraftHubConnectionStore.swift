import Combine
import Foundation

@MainActor
protocol CraftHubConnectionPersisting {
  func load() throws -> CraftHubConnection?
  func save(_ connection: CraftHubConnection?) throws
}

struct CraftHubConnectionFile: CraftHubConnectionPersisting {
  static var defaultURL: URL { URL.applicationSupportDirectory.appending(path: "Augma/craft-hub-connection.json") }
  let url: URL
  func load() throws -> CraftHubConnection? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    guard try (url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 64 * 1024 else { throw CraftHubError.invalidConnection }
    return try JSONDecoder().decode(CraftHubConnection.self, from: Data(contentsOf: url)).validated()
  }
  func save(_ connection: CraftHubConnection?) throws {
    guard let connection else {
      if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
      return
    }
    _ = try connection.validated()
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(connection).write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
  }
}

/// One optional app-wide source; catalog and summaries are session-only and cleared on disconnect or failed reads.
@MainActor
final class CraftHubConnectionStore: ObservableObject {
  @Published private(set) var connection: CraftHubConnection?
  @Published private(set) var projects: [CraftHubProject] = []
  @Published private(set) var contexts: [String: CraftHubProjectContext] = [:]
  @Published private(set) var connected = false
  @Published private(set) var busy = false
  @Published private(set) var error: String?
  private let client: CraftHubReading
  private let persistence: CraftHubConnectionPersisting?
  private var generation = UUID()
  private var contextRequests: [String: UUID] = [:]
  private var closed = false

  init(client: CraftHubReading? = nil, persistence: CraftHubConnectionPersisting? = nil) {
    self.client = client ?? CraftHubClient(); self.persistence = persistence
    do { connection = try persistence?.load() }
    catch { self.error = String(localized: "无法读取 Craft Hub 连接配置，请重新连接或断开连接。") }
  }

  @discardableResult func connect(json: String) async -> Bool {
    guard !closed, !busy else { return false }
    do {
      let candidate = try CraftHubConnection.parse(json)
      return await refresh(candidate, save: true)
    } catch { self.error = error.localizedDescription; return false }
  }

  @discardableResult func refresh() async -> Bool {
    guard let connection, !closed, !busy else { return false }
    return await refresh(connection, save: false)
  }

  private func refresh(_ candidate: CraftHubConnection, save: Bool) async -> Bool {
    let generation = UUID(); self.generation = generation
    busy = true; connected = false; projects = []; contexts = [:]; error = nil
    contextRequests = [:]
    defer { if self.generation == generation { busy = false } }
    do {
      let projects = try await client.projects(candidate)
      guard self.generation == generation, !closed, !Task.isCancelled else { return false }
      if save { try persistence?.save(candidate) }
      connection = candidate; self.projects = projects; connected = true; busy = false
      return true
    } catch {
      guard self.generation == generation, !closed else { return false }
      busy = false; self.error = safeError(error)
      return false
    }
  }

  func context(for binding: CraftHubProjectBinding?) -> CraftHubProjectContext? {
    guard let binding, connected, binding.sourceID == connection?.sourceID else { return nil }
    return contexts[binding.projectID]
  }

  func binding(for projectID: String) throws -> CraftHubProjectBinding {
    guard connected, let connection else { throw CraftHubError.disconnected }
    guard projects.contains(where: { $0.id == projectID }) else { throw CraftHubError.notShared }
    return CraftHubProjectBinding(sourceID: connection.sourceID, projectID: projectID)
  }

  @discardableResult func read(_ binding: CraftHubProjectBinding) async throws -> CraftHubProjectContext {
    guard connected, let connection, connection.sourceID == binding.sourceID, !closed else { throw CraftHubError.disconnected }
    guard projects.contains(where: { $0.id == binding.projectID }) else { throw CraftHubError.notShared }
    let generation = generation
    let request = UUID(); contextRequests[binding.projectID] = request
    do {
      let context = try await client.context(connection, projectID: binding.projectID).validated(projectID: binding.projectID)
      guard self.generation == generation, contextRequests[binding.projectID] == request, !closed, !Task.isCancelled else { throw CraftHubError.changed }
      contexts[binding.projectID] = context
      if let index = projects.firstIndex(where: { $0.id == binding.projectID }) { projects[index] = context.project }
      return context
    } catch {
      guard self.generation == generation, contextRequests[binding.projectID] == request, !closed, !Task.isCancelled else { throw CraftHubError.changed }
      contexts[binding.projectID] = nil
      if case CraftHubError.unauthorized = error { connected = false; projects = []; contexts = [:] }
      if case CraftHubError.credentialUnavailable = error { connected = false; projects = []; contexts = [:] }
      self.error = safeError(error)
      throw error
    }
  }

  func disconnect() {
    generation = UUID(); contextRequests = [:]; busy = false; connected = false; projects = []; contexts = [:]; connection = nil
    do { try persistence?.save(nil); error = nil }
    catch { self.error = String(localized: "连接已断开，但清除保存配置失败，请重试。") }
  }
  func shutdown() { closed = true; generation = UUID(); connected = false; busy = false; projects = []; contexts = [:] }

  private func safeError(_ error: Error) -> String {
    (error as? CraftHubError)?.localizedDescription ?? String(localized: "无法保存或读取 Craft Hub 连接，请重试。")
  }
}
