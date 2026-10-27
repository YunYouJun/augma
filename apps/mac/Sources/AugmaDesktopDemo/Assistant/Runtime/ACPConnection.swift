import Foundation

/// The ACP wire uses newline-delimited JSON-RPC, independently of MCP's transport.
indirect enum ACPValue: Codable, Equatable, Sendable {
  case object([String: ACPValue]), array([ACPValue]), string(String), number(Double), bool(Bool), null
  init(from decoder: Decoder) throws {
    let c = try decoder.singleValueContainer()
    if c.decodeNil() { self = .null }
    else if let v = try? c.decode(Bool.self) { self = .bool(v) }
    else if let v = try? c.decode(String.self) { self = .string(v) }
    else if let v = try? c.decode(Double.self) { self = .number(v) }
    else if let v = try? c.decode([String: ACPValue].self) { self = .object(v) }
    else { self = .array(try c.decode([ACPValue].self)) }
  }
  func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    switch self {
    case .object(let v): try c.encode(v)
    case .array(let v): try c.encode(v)
    case .string(let v): try c.encode(v)
    case .number(let v): try c.encode(v)
    case .bool(let v): try c.encode(v)
    case .null: try c.encodeNil()
    }
  }
  subscript(_ key: String) -> ACPValue { if case .object(let v) = self { v[key] ?? .null } else { .null } }
  var string: String? { if case .string(let v) = self { v } else { nil } }
  var array: [ACPValue] { if case .array(let v) = self { v } else { [] } }
  var object: [String: ACPValue]? { if case .object(let v) = self { v } else { nil } }
  static func text(_ s: String) -> ACPValue { .object(["type": .string("text"), "text": .string(s)]) }
}

struct ACPFramer {
  static let limit = 1_048_576
  private var buffer = Data()
  mutating func append(_ data: Data) throws -> [ACPValue] {
    buffer.append(data)
    var result: [ACPValue] = []
    while let end = buffer.firstIndex(of: 10) {
      guard end <= Self.limit else { throw AssistantRuntimeError.protocolViolation }
      let line = buffer.prefix(upTo: end)
      buffer.removeSubrange(...end)
      guard !line.isEmpty, let value = try? JSONDecoder().decode(ACPValue.self, from: line),
        value["jsonrpc"].string == "2.0", value.object != nil else { throw AssistantRuntimeError.protocolViolation }
      result.append(value)
    }
    guard buffer.count <= Self.limit else { throw AssistantRuntimeError.protocolViolation }
    return result
  }
}

/// Only this object owns the spawned process. It never searches for or kills other DSH instances.
@MainActor
final class ACPConnection {
  var notification: ((String, ACPValue) -> Void)?
  var incomingRequest: ((String, ACPValue) async -> ACPValue?)?
  var disconnected: (() -> Void)?
  private var process: Process?
  private let writes = DispatchQueue(label: "cn.yunyoujun.augma.acp-writes")
  private var stdin: FileHandle?
  private var stdout: FileHandle?
  private var stderr: FileHandle?
  private var framer = ACPFramer()
  private var serial = 0
  private var epoch = UUID()
  private var pending: [String: CheckedContinuation<ACPValue, Error>] = [:]
  private var deadlines: [String: Task<Void, Never>] = [:]
  private var incoming: [UUID: Task<Void, Never>] = [:]
  private(set) var stderrBytes = 0
  var isRunning: Bool { process?.isRunning == true }
  var processIdentifier: Int32? { process?.processIdentifier }
  var ownedProcess: Process? { process }

  func start(executable: URL, arguments: [String], directory: URL, environment: [String: String]) throws {
    stop()
    let p = Process(), input = Pipe(), output = Pipe(), errors = Pipe()
    p.executableURL = executable; p.arguments = arguments; p.currentDirectoryURL = directory
    p.environment = environment; p.standardInput = input; p.standardOutput = output; p.standardError = errors
    let token = UUID(); epoch = token; framer = ACPFramer(); stderrBytes = 0
    stdin = input.fileHandleForWriting; stdout = output.fileHandleForReading; stderr = errors.fileHandleForReading
    output.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      Task { @MainActor in
        guard let self, self.epoch == token else { return }
        if data.isEmpty { self.stop(error: AssistantRuntimeError.disconnected) }
        else { self.receive(data) }
      }
    }
    errors.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      Task { @MainActor in
        guard let self, self.epoch == token else { return }
        // Drain but never retain runtime logs: provider errors can contain credentials or prompts.
        self.stderrBytes = min(65_536, self.stderrBytes + data.count)
      }
    }
    p.terminationHandler = { [weak self] _ in
      Task { @MainActor in
        guard let self, self.epoch == token else { return }
        self.stop(error: AssistantRuntimeError.disconnected)
      }
    }
    process = p
    do { try p.run() } catch { stop(); throw AssistantRuntimeError.launchFailed }
  }

  func request(_ method: String, _ params: ACPValue, timeout: Double = 15) async throws -> ACPValue {
    try Task.checkCancellation()
    guard isRunning else { throw AssistantRuntimeError.disconnected }
    serial += 1; let id = "augma-\(serial)"
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        pending[id] = continuation
        deadlines[id] = Task { [weak self] in
          try? await Task.sleep(for: .seconds(timeout))
          guard !Task.isCancelled else { return }
          self?.settle(id, .failure(AssistantRuntimeError.timeout))
        }
        do { try send(.object(["jsonrpc": .string("2.0"), "id": .string(id), "method": .string(method), "params": params])) }
        catch { settle(id, .failure(error)) }
      }
    } onCancel: {
      Task { @MainActor [weak self] in self?.settle(id, .failure(CancellationError())) }
    }
  }

  func notify(_ method: String, _ params: ACPValue) {
    try? send(.object(["jsonrpc": .string("2.0"), "method": .string(method), "params": params]))
  }

  private func send(_ value: ACPValue) throws {
    guard let stdin, isRunning else { throw AssistantRuntimeError.disconnected }
    var data = try JSONEncoder().encode(value)
    guard data.count <= ACPFramer.limit else { throw AssistantRuntimeError.protocolViolation }
    data.append(10)
    let token = epoch, payload = data
    writes.async { [weak self] in
      do { try stdin.write(contentsOf: payload) }
      catch {
        Task { @MainActor in
          guard let self, self.epoch == token else { return }
          self.stop(error: AssistantRuntimeError.disconnected)
        }
      }
    }
  }

  private func receive(_ data: Data) {
    do {
      for message in try framer.append(data) {
        if let method = message["method"].string {
          if message["id"] != .null {
            let id = message["id"], key = UUID(), token = epoch
            guard incoming.count < 16 else { throw AssistantRuntimeError.protocolViolation }
            incoming[key] = Task { [weak self] in
              guard let self else { return }
              let result = await self.incomingRequest?(method, message["params"])
              guard self.epoch == token, !Task.isCancelled else { return }
              let response: ACPValue = result.map { .object(["jsonrpc": .string("2.0"), "id": id, "result": $0]) }
                ?? .object(["jsonrpc": .string("2.0"), "id": id, "error": .object(["code": .number(-32601), "message": .string("Unsupported client capability")])])
              try? self.send(response); self.incoming.removeValue(forKey: key)
            }
          } else { notification?(method, message["params"]) }
        } else if let id = message["id"].string {
          if message["error"] != .null {
            settle(id, .failure(AssistantRuntimeError.remote(message["error"]))) }
          else if message.object?["result"] != nil { settle(id, .success(message["result"])) }
          else { throw AssistantRuntimeError.protocolViolation }
        }
      }
    } catch { stop(error: AssistantRuntimeError.protocolViolation) }
  }

  private func settle(_ id: String, _ result: Result<ACPValue, Error>) {
    deadlines.removeValue(forKey: id)?.cancel()
    pending.removeValue(forKey: id)?.resume(with: result)
  }

  func stop(error: Error = CancellationError()) {
    epoch = UUID()
    stdout?.readabilityHandler = nil; stderr?.readabilityHandler = nil
    try? stdin?.close(); try? stdout?.close(); try? stderr?.close()
    stdin = nil; stdout = nil; stderr = nil
    let p = process; process = nil; p?.terminationHandler = nil
    if let p, p.isRunning {
      p.terminate()
      Task {
        try? await Task.sleep(for: .seconds(2))
        if p.isRunning { kill(p.processIdentifier, SIGKILL) }
      }
    }
    for id in Array(pending.keys) { settle(id, .failure(error)) }
    incoming.values.forEach { $0.cancel() }; incoming.removeAll()
    if p != nil { disconnected?() }
  }
}
