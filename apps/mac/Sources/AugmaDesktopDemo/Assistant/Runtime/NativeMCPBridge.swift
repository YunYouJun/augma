import Foundation
import MCP
import Network

/// A capability belongs to one window and one admitted task. Cancellation revokes it synchronously.
@MainActor
final class NativeToolScope {
  let id = UUID()
  var active = false
  var openPanel: ((NativeAssistantAction) -> NativeAssistantResult)?
  var onTool: ((String) -> Void)?
  private(set) var successfulTools: Set<String> = []
  private let reader = SystemMetricsReader()
  private var opened: Set<String> = []
  private var generation = 0
  static let panels = ["map", "weather", "notifications", "settings", "camera", "browser"]

  func begin() { generation += 1; active = true; opened = []; successfulTools = [] }
  func revoke() { generation += 1; active = false }

  func call(name: String, arguments: [String: Value]) async throws -> String {
    guard active, !Task.isCancelled else { throw MCPError.invalidRequest("Task is no longer active") }
    let token = generation
    onTool?(name)
    let result: ACPValue
    switch name {
    case "system_summary":
      guard arguments.isEmpty else { throw MCPError.invalidParams("No arguments expected") }
      let sample = await reader.sample(options: SystemSamplingOptions(includeDisks: true, includeApplications: false, includeSensors: false))
      var body: [String: ACPValue] = ["sampledAt": .string(sample.sampledAt.ISO8601Format())]
      if let memory = sample.memory {
        body["memory"] = .object(["total": .number(Double(memory.total)), "used": .number(Double(memory.used)),
          "compressed": .number(Double(memory.compressed)), "swap": .number(Double(memory.swapUsed)), "pressure": .string(memory.pressure.rawValue)])
      } else { body["memory"] = .null }
      body["disks"] = .array(sample.disks.prefix(5).map { .object(["total": .number(Double($0.total)), "available": .number(Double($0.available))]) })
      result = .object(body)
    case "application_usage":
      guard arguments.isEmpty else { throw MCPError.invalidParams("No arguments expected") }
      guard let sample = await ApplicationMemoryReader.sample() else { throw MCPError.internalError("Application memory is unavailable") }
      result = .object(["sampledAt": .string(Date.now.ISO8601Format()), "approximate": .bool(true),
        "applications": .array(sample.applications.prefix(10).map { .object([
          "name": .string(String($0.application.name.prefix(120))), "bytes": .number(Double($0.physicalFootprint)),
          "partial": .bool($0.unreadableProcessCount > 0)
        ]) })])
    case "open_panel":
      guard Set(arguments.keys) == ["panel"], let panel = arguments["panel"]?.stringValue,
        Self.panels.contains(panel), let action = NativeAssistantAction(rawValue: panel), let openPanel else {
        throw MCPError.invalidParams("Panel is not available in this window")
      }
      guard !opened.contains(panel) else { throw MCPError.invalidRequest("Panel already opened during this task") }
      opened.insert(panel)
      let actionResult = openPanel(action)
      guard !actionResult.isError else { throw MCPError.internalError("Native panel could not be opened") }
      result = .object(["message": .string(actionResult.message), "isError": .bool(actionResult.isError)])
    default: throw MCPError.methodNotFound("Unknown native tool")
    }
    guard active, generation == token, !Task.isCancelled else { throw MCPError.invalidRequest("Task was cancelled") }
    successfulTools.insert(name)
    return String(decoding: try JSONEncoder().encode(result), as: UTF8.self)
  }

  static var tools: [Tool] {
    let empty: Value = .object(["type": .string("object"), "properties": .object([:]), "additionalProperties": .bool(false)])
    let number: Value = .object(["type": .string("number"), "minimum": .int(0)])
    let string: Value = .object(["type": .string("string")])
    let boolean: Value = .object(["type": .string("boolean")])
    func object(_ properties: [String: Value]) -> Value {
      .object(["type": .string("object"), "properties": .object(properties),
        "required": .array(properties.keys.sorted().map(Value.string)), "additionalProperties": .bool(false)])
    }
    let memory = object(["total": number, "used": number, "compressed": number, "swap": number, "pressure": string])
    let summary = object(["sampledAt": string, "memory": .object(["anyOf": .array([memory, .object(["type": .string("null")])])]),
      "disks": .object(["type": .string("array"), "items": object(["total": number, "available": number]), "maxItems": .int(5)])])
    let usage = object(["sampledAt": string, "approximate": boolean,
      "applications": .object(["type": .string("array"), "items": object(["name": string, "bytes": number, "partial": boolean]), "maxItems": .int(10)])])
    return [
      Tool(name: "system_summary", description: "Read current memory pressure, swap and disk capacity. No file names or paths. High RAM use alone is not a fault.", inputSchema: empty,
        annotations: .init(readOnlyHint: true, openWorldHint: false), outputSchema: summary),
      Tool(name: "application_usage", description: "Read the ten largest app memory footprints, names and partial-read flags. Approximate; cannot quit apps.", inputSchema: empty,
        annotations: .init(readOnlyHint: true, openWorldHint: false), outputSchema: usage),
      Tool(name: "open_panel", description: "Open the requested Augma panel only. Does not activate camera, navigate URLs or read panel contents. Call only when explicitly requested.", inputSchema: .object([
        "type": .string("object"), "properties": .object(["panel": .object(["type": .string("string"), "enum": .array(panels.map(Value.string))])]),
        "required": .array([.string("panel")]), "additionalProperties": .bool(false)
      ]), annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false),
        outputSchema: object(["message": string, "isError": boolean]))
    ]
  }
}

/// Loopback HTTP adapter; MCP negotiation, schemas, RPC dispatch and results use the official SDK.
/// Each bridge has an unguessable in-memory bearer and its own SDK Server, preventing cross-session calls.
@MainActor
final class NativeMCPBridge {
  private let scope: NativeToolScope
  private let server = Server(name: "Augma native tools", version: "1", capabilities: .init(tools: .init()))
  private let transport = StatelessHTTPServerTransport()
  private let bearer = UUID().uuidString + UUID().uuidString
  private var listener: NWListener?
  private var connections: [UUID: NWConnection] = [:]
  private var requests: [UUID: Task<Void, Never>] = [:]
  private var port: UInt16?
  init(scope: NativeToolScope) { self.scope = scope }

  func start() async throws -> ACPValue {
    let scope = scope
    await server.withMethodHandler(ListTools.self) { _ in
      await MainActor.run { .init(tools: NativeToolScope.tools.filter { $0.name != "open_panel" || scope.openPanel != nil }) }
    }
    await server.withMethodHandler(CallTool.self) { params in
      do {
        let text = try await scope.call(name: params.name, arguments: params.arguments ?? [:])
        let structured = try JSONDecoder().decode(Value.self, from: Data(text.utf8))
        return .init(content: [.text(text: text, annotations: nil, _meta: nil)], structuredContent: Optional.some(structured), isError: false)
      } catch { return .init(content: [.text(text: "Native tool unavailable, invalid or cancelled; no success is claimed.", annotations: nil, _meta: nil)], isError: true) }
    }
    try await server.start(transport: transport)
    let parameters = NWParameters.tcp
    parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
    let listener = try NWListener(using: parameters); self.listener = listener
    listener.newConnectionHandler = { [weak self] connection in
      Task { @MainActor in self?.accept(connection) }
    }
    let port: UInt16 = try await withCheckedThrowingContinuation { continuation in
      listener.stateUpdateHandler = { state in
        switch state {
        case .ready:
          listener.stateUpdateHandler = nil
          if let port = listener.port { continuation.resume(returning: port.rawValue) }
          else { continuation.resume(throwing: AssistantRuntimeError.launchFailed) }
        case .failed, .cancelled:
          listener.stateUpdateHandler = nil
          continuation.resume(throwing: AssistantRuntimeError.launchFailed)
        default: break
        }
      }
      listener.start(queue: .main)
    }
    self.port = port
    return .object(["type": .string("http"), "name": .string("augma"), "url": .string("http://127.0.0.1:\(port)/mcp"),
      "headers": .array([.object(["name": .string("Authorization"), "value": .string("Bearer " + bearer)])])])
  }

  private func accept(_ connection: NWConnection) {
    guard listener != nil, connections.count < 8 else { connection.cancel(); return }
    let id = UUID(); connections[id] = connection
    connection.start(queue: .main)
    requests[id] = Task { [weak self] in
      try? await Task.sleep(for: .seconds(10))
      guard !Task.isCancelled else { return }
      self?.finish(id)
    }
    read(connection, id: id, buffer: Data())
  }

  private func read(_ connection: NWConnection, id: UUID, buffer: Data) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, complete, error in
      Task { @MainActor in
        guard let self, self.connections[id] != nil else { return }
        var bytes = buffer; bytes.append(data ?? Data())
        guard bytes.count <= 65_536, error == nil else { self.finish(id); return }
        guard let range = bytes.range(of: Data("\r\n\r\n".utf8)) else {
          if complete || bytes.count > 8_192 { self.finish(id) }
          else { self.read(connection, id: id, buffer: bytes) }
          return
        }
        guard range.lowerBound < 8_192, let header = String(data: bytes[..<range.lowerBound], encoding: .utf8) else { self.finish(id); return }
        let lines = header.components(separatedBy: "\r\n")
        let start = lines[0].split(separator: " ")
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
          guard let colon = line.firstIndex(of: ":") else { self.finish(id); return }
          let name = String(line[..<colon]).lowercased()
          guard headers[name] == nil else { self.finish(id); return }
          headers[name] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        guard start.count == 3, start[1] == "/mcp", headers["authorization"] == "Bearer " + self.bearer,
          headers["host"] == "127.0.0.1:\(self.port ?? 0)", headers["origin"] == nil,
          headers["transfer-encoding"] == nil,
          let length = Int(headers["content-length"] ?? "0"), length >= 0, length <= 57_344 else {
          self.respond(id, status: 403, body: Data()); return
        }
        let count = bytes.count - range.upperBound
        guard count >= length else {
          if complete { self.finish(id) } else { self.read(connection, id: id, buffer: bytes) }
          return
        }
        guard count == length else { self.finish(id); return }
        let body = Data(bytes[range.upperBound...])
        let request = HTTPRequest(method: String(start[0]), headers: headers, body: body)
        // The existing 10-second connection deadline also bounds a stalled SDK handler.
        let response = await self.transport.handleRequest(request)
        guard self.connections[id] != nil else { return }
        self.respond(id, status: response.statusCode, body: response.bodyData ?? Data())
      }
    }
  }

  private func respond(_ id: UUID, status: Int, body: Data) {
    guard let connection = connections[id] else { return }
    let head = "HTTP/1.1 \(status) Response\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
    connection.send(content: Data(head.utf8) + body, completion: .contentProcessed { [weak self] _ in
      Task { @MainActor in self?.finish(id) }
    })
  }
  private func finish(_ id: UUID) {
    requests.removeValue(forKey: id)?.cancel()
    connections.removeValue(forKey: id)?.cancel()
  }
  func stop() {
    scope.revoke(); listener?.cancel(); listener = nil
    for id in Array(connections.keys) { finish(id) }
    let server = server
    Task { await server.stop() }
  }
}
