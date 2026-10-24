import Foundation

/// File I/O is serialized off the main actor. A stale debounce can never replace a newer revision.
actor WorkspaceFile {
  let url: URL
  private var latestRevision = -1

  init(url: URL) { self.url = url }

  static var defaultURL: URL {
    URL.applicationSupportDirectory.appending(path: "Augma/workspace.json")
  }

  nonisolated static func read(_ url: URL) throws -> WorkspaceData {
    guard FileManager.default.fileExists(atPath: url.path) else { return WorkspaceData() }
    return try decode(Data(contentsOf: url))
  }

  nonisolated private static func decode(_ data: Data) throws -> WorkspaceData {
    var result = try JSONDecoder().decode(WorkspaceData.self, from: data)
    try result.validate()
    result.version = 2
    // A write may have reached its destination before the process exited or this backup was taken.
    for index in result.notes.indices where result.notes[index].delivery?.status == .sending {
      result.notes[index].delivery?.status = .uncertain
      result.notes[index].delivery?.error = CaptureError.uncertain.localizedDescription
    }
    return result
  }

  func save(_ value: WorkspaceData, revision: Int) throws {
    guard revision > latestRevision else { return }
    try value.validate()
    let data = try JSONEncoder().encode(value)
    let directory = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    if FileManager.default.fileExists(atPath: url.path) {
      let old = try Data(contentsOf: url)
      _ = try Self.decode(old) // Never overwrite an unreadable or newer-format original.
      try old.write(to: url.appendingPathExtension("backup"), options: .atomic)
    }
    try data.write(to: url, options: .atomic)
    latestRevision = revision
  }

  func restoreBackup() throws -> WorkspaceData {
    let backup = try Data(contentsOf: url.appendingPathExtension("backup"))
    let recovered = try Self.decode(backup)
    if FileManager.default.fileExists(atPath: url.path) {
      // Preserve the original for recovery instead of deleting potentially unique user data.
      let original = url.deletingLastPathComponent().appending(path: "workspace-preserved-\(UUID().uuidString).json")
      try FileManager.default.copyItem(at: url, to: original)
    }
    try backup.write(to: url, options: .atomic)
    latestRevision = -1
    return recovered
  }
}
