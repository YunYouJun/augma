import AppKit
import Foundation

/// Fail closed while any known desktop/CLI writer is running. Never quits another app.
enum CodexStorageActivity {
  @MainActor static func ensureStopped() async throws {
    let bundleIDs: Set<String> = ["com.openai.codex", "com.openai.chat"]
    guard
      !NSWorkspace.shared.runningApplications.contains(where: {
        $0.bundleIdentifier.map(bundleIDs.contains) == true && !$0.isTerminated
      })
    else { throw CodexStorageError.running }
    let result = try await CleanupCommandProcess(timeout: .seconds(5), maximumOutput: 1_048_576)
      .run(
        executable: URL(filePath: "/bin/ps"), arguments: ["-axo", "comm="],
        environment: ["PATH": "/usr/bin:/bin", "LC_ALL": "C"])
    guard result.status == 0, result.diagnostics.isEmpty else {
      throw CodexStorageError.unavailable
    }
    let names: Set<String> = ["codex", "codexcli", "chatgpt", "codex-app-server", "codex-tui"]
    guard
      !result.output.split(separator: "\n").contains(where: {
        names.contains(
          URL(filePath: String($0).trimmingCharacters(in: .whitespaces)).lastPathComponent
            .lowercased())
      })
    else { throw CodexStorageError.running }
  }
}

/// Last local receipt only. A persisted in-flight item remains uncertain after restart.
struct CodexStorageJournal: Sendable {
  let url: URL
  private let writer: ProtectedFileWriter

  init(url: URL, writer: ProtectedFileWriter = ProtectedFileWriter()) {
    self.url = url
    self.writer = writer
  }

  func save(_ receipt: CodexStorageReceipt) throws {
    let files = FileManager.default
    let parent = url.deletingLastPathComponent()
    try files.createDirectory(
      at: parent, withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700])
    try validatePath()
    let data = try JSONEncoder().encode(receipt)
    try writer.write(data, to: url)
    try files.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
  }

  func load() throws -> CodexStorageReceipt? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    try validatePath()
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    guard (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= 1_048_576 else {
      throw CodexStorageError.unavailable
    }
    var receipt = try JSONDecoder().decode(CodexStorageReceipt.self, from: Data(contentsOf: url))
    if receipt.finishedAt == nil {
      receipt.warning = String(appLocalized: "上次操作未完成；请核实待确认项，不会自动重试。")
    }
    return receipt
  }

  private func validatePath() throws {
    guard url.standardizedFileURL.path == url.resolvingSymlinksInPath().path else {
      throw CodexStorageError.unavailable
    }
    if FileManager.default.fileExists(atPath: url.path) {
      let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
      guard attributes[.type] as? FileAttributeType == .typeRegular,
        (attributes[.referenceCount] as? NSNumber)?.intValue == 1
      else { throw CodexStorageError.unavailable }
    }
  }
}
