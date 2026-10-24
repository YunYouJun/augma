import Foundation
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class ProjectEditorProcessTests: XCTestCase {
  func testEditorArgumentsPreserveSpacesAndShellCharactersLiterally() async throws {
    let app = try fixture(script: "printf '%s\\n' \"$@\" > arguments.txt\nprintf '%s' \"$ELECTRON_RUN_AS_NODE\" > environment.txt\n")
    defer { try? FileManager.default.removeItem(at: app.deletingLastPathComponent()) }
    let folder = app.deletingLastPathComponent().appending(path: "Project $(literal) '中文' #1")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try await ProjectEditorProcess().open(applicationURL: app, folderURL: folder)
    let arguments = try String(contentsOf: app.appending(path: "arguments.txt"), encoding: .utf8)
    XCTAssertEqual(arguments.components(separatedBy: "\n"), [app.appending(path: "Contents/Resources/app/out/cli.js").path, "--new-window", folder.path, ""])
    XCTAssertEqual(try String(contentsOf: app.appending(path: "environment.txt"), encoding: .utf8), "1")
  }

  func testEditorFailureIsReported() async throws {
    let app = try fixture(script: "exit 7\n")
    defer { try? FileManager.default.removeItem(at: app.deletingLastPathComponent()) }
    do {
      try await ProjectEditorProcess().open(applicationURL: app, folderURL: app.deletingLastPathComponent())
      XCTFail("Expected an editor failure")
    } catch { XCTAssertEqual(error.localizedDescription, ProjectWorkspaceError.editorFailed.localizedDescription) }
  }

  func testEditorTimeoutStopsOnlyItsRequestProcess() async throws {
    let app = try fixture(script: "exec /bin/sleep 30\n")
    defer { try? FileManager.default.removeItem(at: app.deletingLastPathComponent()) }
    do {
      try await ProjectEditorProcess(timeoutDuration: .milliseconds(100)).open(applicationURL: app, folderURL: app.deletingLastPathComponent())
      XCTFail("Expected a timeout")
    } catch { XCTAssertEqual(error.localizedDescription, ProjectWorkspaceError.editorTimedOut.localizedDescription) }
  }

  func testCancelledEditorRequestFinishesWithoutWaitingForApp() async throws {
    let app = try fixture(script: "printf ready > started.txt\nexec /bin/sleep 30\n")
    defer { try? FileManager.default.removeItem(at: app.deletingLastPathComponent()) }
    let task = Task { try await ProjectEditorProcess().open(applicationURL: app, folderURL: app.deletingLastPathComponent()) }
    for _ in 0..<100 where !FileManager.default.fileExists(atPath: app.appending(path: "started.txt").path) {
      try await Task.sleep(for: .milliseconds(10))
    }
    task.cancel()
    do { try await task.value; XCTFail("Expected cancellation") }
    catch { XCTAssertTrue(error is CancellationError) }
  }

  private func fixture(script: String) throws -> URL {
    let root = FileManager.default.temporaryDirectory.appending(path: "augma-editor-request-test-" + UUID().uuidString)
    let app = root.appending(path: "Test Editor.app")
    do {
      let executable = app.appending(path: "Contents/MacOS/Code")
      let cli = app.appending(path: "Contents/Resources/app/out/cli.js")
      try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
      try FileManager.default.createDirectory(at: cli.deletingLastPathComponent(), withIntermediateDirectories: true)
      try Data(("#!/bin/sh\n" + script).utf8).write(to: executable)
      try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
      try Data().write(to: cli)
      return app
    } catch { try? FileManager.default.removeItem(at: root); throw error }
  }
}
