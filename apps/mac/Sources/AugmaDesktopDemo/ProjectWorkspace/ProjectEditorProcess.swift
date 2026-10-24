import Foundation

/// Invokes the installed VS Code CLI in its own short-lived process. Arguments
/// remain separate values, and --new-window preserves existing editor windows.
@MainActor
final class ProjectEditorProcess {
  private let process = Process()
  private var continuation: CheckedContinuation<Void, Error>?
  private var timeout: Task<Void, Never>?
  private let timeoutDuration: Duration
  init(timeoutDuration: Duration = .seconds(25)) { self.timeoutDuration = timeoutDuration }

  func open(applicationURL: URL, folderURL: URL) async throws {
    let executable = applicationURL.appending(path: "Contents/MacOS/Electron")
    let codeExecutable = applicationURL.appending(path: "Contents/MacOS/Code")
    let cli = applicationURL.appending(path: "Contents/Resources/app/out/cli.js")
    // VS Code distributions have used both executable names. The application
    // identity was checked by the caller before reaching this adapter.
    process.executableURL = FileManager.default.isExecutableFile(atPath: codeExecutable.path) ? codeExecutable : executable
    guard let executable = process.executableURL, FileManager.default.isExecutableFile(atPath: executable.path),
          FileManager.default.fileExists(atPath: cli.path) else { throw ProjectWorkspaceError.editorFailed }
    process.arguments = [cli.path, "--new-window", folderURL.path]
    var environment = ProcessInfo.processInfo.environment.filter { !$0.key.hasPrefix("VSCODE_") && !$0.key.hasPrefix("NODE_") }
    environment["ELECTRON_RUN_AS_NODE"] = "1"
    process.environment = environment
    process.currentDirectoryURL = applicationURL
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try await withTaskCancellationHandler {
      try Task.checkCancellation()
      try await withCheckedThrowingContinuation { continuation in
        self.continuation = continuation
        process.terminationHandler = { [weak self] process in
          let status = process.terminationStatus
          Task { @MainActor in self?.finish(status == 0 ? .success(()) : .failure(ProjectWorkspaceError.editorFailed)) }
        }
        do {
          try process.run()
          timeout = Task { [weak self] in
            guard let self else { return }
            do { try await Task.sleep(for: self.timeoutDuration) } catch { return }
            self.stop(with: ProjectWorkspaceError.editorTimedOut)
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
