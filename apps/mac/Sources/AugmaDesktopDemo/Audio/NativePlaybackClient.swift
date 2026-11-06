import Foundation

enum NativePlaybackCommand: Equatable, Sendable {
  case play, pause
  case previousTrack, nextTrack
  case seek(position: TimeInterval, trackIdentifier: String)

  var targetPlaying: Bool? {
    switch self {
    case .play: true
    case .pause: false
    case .previousTrack, .nextTrack, .seek: nil
    }
  }

  var arguments: [String]? {
    switch self {
    case .play: ["--play"]
    case .pause: ["--pause"]
    case .previousTrack: ["--previous"]
    case .nextTrack: ["--next"]
    case .seek(let position, let identifier):
      position.isFinite && (0...604_800).contains(position) && !identifier.isEmpty && identifier.utf8.count <= 4096
        ? ["--seek", String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), position), identifier] : nil
    }
  }
}

@MainActor
protocol NativePlaybackControlling: AnyObject {
  func send(_ command: NativePlaybackCommand) async throws
}

/// A separate, short-lived helper runs only after an explicit playback action.
@MainActor
final class NativePlaybackClient: NativePlaybackControlling {
  func send(_ command: NativePlaybackCommand) async throws {
    guard let arguments = command.arguments, let resources = Bundle.main.resourceURL else { throw NativeNowPlayingError.unavailable }
    let script = resources.appending(path: "NowPlaying/read-now-playing.pl")
    let library = resources.appending(path: "NowPlaying/ReadNowPlaying.dylib")
    guard FileManager.default.fileExists(atPath: script.path), FileManager.default.fileExists(atPath: library.path) else {
      throw NativeNowPlayingError.unavailable
    }
    let request = NativePlaybackRequest()
    try await request.run(arguments: [script.path, library.path] + arguments)
  }
}

@MainActor
private final class NativePlaybackRequest {
  private let process = Process()
  private var continuation: CheckedContinuation<Void, Error>?
  private var timeout: Task<Void, Never>?

  func run(arguments: [String]) async throws {
    process.executableURL = URL(filePath: "/usr/bin/perl")
    process.arguments = arguments
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try await withTaskCancellationHandler {
      try Task.checkCancellation()
      try await withCheckedThrowingContinuation { continuation in
        self.continuation = continuation
        process.terminationHandler = { [weak self] process in
          let status = process.terminationStatus
          Task { @MainActor in
            self?.finish(status == 0 ? .success(()) : .failure(NativeNowPlayingError.unavailable))
          }
        }
        do {
          try process.run()
          timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            self?.stop(with: NativeNowPlayingError.unavailable)
          }
        } catch { finish(.failure(error)) }
      }
    } onCancel: {
      Task { @MainActor [weak self] in self?.stop(with: CancellationError()) }
    }
  }

  private func stop(with error: Error) {
    if process.isRunning { process.terminate() }
    finish(.failure(error))
  }

  private func finish(_ result: Result<Void, Error>) {
    guard let continuation else { return }
    self.continuation = nil
    timeout?.cancel(); timeout = nil
    process.terminationHandler = nil
    continuation.resume(with: result)
  }
}
