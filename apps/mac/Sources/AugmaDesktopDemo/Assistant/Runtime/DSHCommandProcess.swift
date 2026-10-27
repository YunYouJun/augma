import Foundation
import Darwin

struct DSHCommandResult: Sendable {
  var status: Int32
  var output: String
  var diagnostics: String = ""
}

/// Probes the installed DSH version with bounded output, cancellation and no shell interpolation.
@MainActor
final class DSHCommandProcess {
  enum Failure: LocalizedError {
    case timedOut, outputLimit
    var errorDescription: String? {
      switch self {
      case .timedOut: AssistantRuntimeError.timeout.localizedDescription
      case .outputLimit: AssistantRuntimeError.protocolViolation.localizedDescription
      }
    }
  }

  private let process = Process()
  private let output = Pipe(), diagnostics = Pipe()
  private let capture: DSHCommandCapture
  private let timeoutDuration: Duration
  private var continuation: CheckedContinuation<DSHCommandResult, Error>?
  private var timeout: Task<Void, Never>?
  private var status: Int32?
  private var pendingFailure: Error?

  init(timeout: Duration = .seconds(45), maximumOutput: Int = 262_144) {
    timeoutDuration = timeout
    capture = DSHCommandCapture(maximumBytes: maximumOutput)
  }

  func run(executable: URL, arguments: [String], environment: [String: String]) async throws -> DSHCommandResult {
    try await withTaskCancellationHandler {
      try Task.checkCancellation()
      return try await withCheckedThrowingContinuation { continuation in
        self.continuation = continuation
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = diagnostics
        for (index, pipe) in [output, diagnostics].enumerated() {
          pipe.fileHandleForReading.readabilityHandler = { [weak self, capture] handle in
            let data: Data
            do { data = try handle.read(upToCount: 16_384) ?? Data() }
            catch {
              Task { @MainActor [weak self] in self?.stop(error) }
              return
            }
            let exceeded = capture.receive(data, channel: index)
            if data.isEmpty { handle.readabilityHandler = nil }
            Task { @MainActor [weak self] in
              if exceeded { self?.stop(Failure.outputLimit) }
              else { self?.finishIfReady() }
            }
          }
        }
        process.terminationHandler = { [weak self] process in
          let status = process.terminationStatus
          Task { @MainActor [weak self] in self?.status = status; self?.finishIfReady() }
        }
        do {
          try process.run()
          try? output.fileHandleForWriting.close()
          try? diagnostics.fileHandleForWriting.close()
          timeout = Task { [weak self] in
            do { try await Task.sleep(for: self?.timeoutDuration ?? .seconds(45)) } catch { return }
            self?.stop(Failure.timedOut)
          }
        } catch { finish(.failure(error)) }
      }
    } onCancel: {
      Task { @MainActor [weak self] in self?.stop(CancellationError()) }
    }
  }

  private func finishIfReady() {
    let snapshot = capture.snapshot()
    guard let status else { return }
    if let pendingFailure { finish(.failure(pendingFailure)); return }
    if snapshot.exceeded { finish(.failure(Failure.outputLimit)); return }
    guard snapshot.complete else { return }
    finish(.success(DSHCommandResult(status: status,
      output: String(decoding: snapshot.output, as: UTF8.self),
      diagnostics: String(decoding: snapshot.diagnostics, as: UTF8.self))))
  }

  private func stop(_ error: Error) {
    guard continuation != nil, pendingFailure == nil else { return }
    pendingFailure = error
    if process.isRunning {
      process.terminate()
      let stoppedProcess = process
      Task {
        try? await Task.sleep(for: .seconds(1))
        if stoppedProcess.isRunning { kill(stoppedProcess.processIdentifier, SIGKILL) }
      }
    } else { finish(.failure(error)) }
  }

  private func finish(_ result: Result<DSHCommandResult, Error>) {
    guard let continuation else { return }
    self.continuation = nil
    timeout?.cancel(); timeout = nil
    process.terminationHandler = nil
    output.fileHandleForReading.readabilityHandler = nil
    diagnostics.fileHandleForReading.readabilityHandler = nil
    continuation.resume(with: result)
  }
}

/// FileHandle callbacks run off the main actor; the shared byte limit includes stderr.
private final class DSHCommandCapture: @unchecked Sendable {
  private let lock = NSLock()
  private let maximumBytes: Int
  private var data = [Data(), Data()]
  private var ended = [false, false]
  private var exceeded = false
  init(maximumBytes: Int) { self.maximumBytes = maximumBytes }

  func receive(_ chunk: Data, channel: Int) -> Bool {
    lock.lock(); defer { lock.unlock() }
    if chunk.isEmpty { ended[channel] = true; return false }
    let remaining = max(0, maximumBytes - data[0].count - data[1].count)
    data[channel].append(chunk.prefix(remaining))
    exceeded = exceeded || chunk.count > remaining
    return exceeded
  }

  func snapshot() -> (output: Data, diagnostics: Data, complete: Bool, exceeded: Bool) {
    lock.lock(); defer { lock.unlock() }
    return (data[0], data[1], ended.allSatisfy { $0 }, exceeded)
  }
}
