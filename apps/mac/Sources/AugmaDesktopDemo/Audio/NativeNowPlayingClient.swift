import Foundation

enum NativeNowPlayingError: Error { case unavailable }

@MainActor
protocol NativeNowPlayingReading: AnyObject {
  func start(_ receive: @escaping (Result<NativeNowPlayingPayload, NativeNowPlayingError>) -> Void)
  func stop()
}

/// One app-wide, read-only helper; no transport-command API or network access.
@MainActor
final class NativeNowPlayingClient: NativeNowPlayingReading {
  private var process: Process?
  private var output: Pipe?
  private var buffer = Data()
  private var generation = UUID()
  private var receive: ((Result<NativeNowPlayingPayload, NativeNowPlayingError>) -> Void)?

  func start(_ receive: @escaping (Result<NativeNowPlayingPayload, NativeNowPlayingError>) -> Void) {
    stop()
    self.receive = receive
    guard let resources = Bundle.main.resourceURL else { receive(.failure(.unavailable)); return }
    let script = resources.appending(path: "NowPlaying/read-now-playing.pl")
    let library = resources.appending(path: "NowPlaying/ReadNowPlaying.dylib")
    guard FileManager.default.fileExists(atPath: script.path), FileManager.default.fileExists(atPath: library.path) else {
      receive(.failure(.unavailable)); return
    }
    let token = generation
    let process = Process(), pipe = Pipe()
    process.executableURL = URL(filePath: "/usr/bin/perl")
    process.arguments = [script.path, library.path]
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      if data.isEmpty { handle.readabilityHandler = nil }
      Task { @MainActor [weak self] in
        guard let self, self.generation == token else { return }
        self.consume(data)
      }
    }
    process.terminationHandler = { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self, self.generation == token else { return }
        let callback = self.receive
        self.stop()
        callback?(.failure(.unavailable))
      }
    }
    self.process = process
    output = pipe
    do { try process.run() }
    catch { stop(); receive(.failure(.unavailable)) }
  }

  private func consume(_ data: Data) {
    buffer.append(data)
    guard buffer.count <= 6_291_456 else {
      let callback = receive
      stop(); callback?(.failure(.unavailable)); return
    }
    while let newline = buffer.firstIndex(of: 10) {
      let line = Data(buffer[..<newline])
      buffer.removeSubrange(...newline)
      do {
        let payload = try JSONDecoder().decode(NativeNowPlayingPayload.self, from: line)
        receive?(payload.error == nil ? .success(payload) : .failure(.unavailable))
      } catch { receive?(.failure(.unavailable)) }
    }
  }

  func stop() {
    generation = UUID()
    output?.fileHandleForReading.readabilityHandler = nil
    process?.terminationHandler = nil
    if process?.isRunning == true { process?.terminate() }
    try? output?.fileHandleForReading.close()
    process = nil; output = nil; receive = nil
    buffer.removeAll(keepingCapacity: false)
  }

  deinit {
    output?.fileHandleForReading.readabilityHandler = nil
    if process?.isRunning == true { process?.terminate() }
  }
}
