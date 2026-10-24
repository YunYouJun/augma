import Foundation

@MainActor
protocol ProjectWorkspacePersisting {
  func load() throws -> ProjectWorkspaceDocument
  func save(_ document: ProjectWorkspaceDocument) throws
  func preserveUnreadableFile() throws
}

struct ProjectWorkspaceFile: ProjectWorkspacePersisting {
  static var defaultURL: URL { URL.applicationSupportDirectory.appending(path: "Augma/project-regions.json") }
  let url: URL
  func load() throws -> ProjectWorkspaceDocument {
    guard FileManager.default.fileExists(atPath: url.path) else { return ProjectWorkspaceDocument() }
    guard try (url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 1024 * 1024 else { throw ProjectWorkspaceError.invalidConfiguration }
    return try JSONDecoder().decode(ProjectWorkspaceDocument.self, from: Data(contentsOf: url)).validated()
  }
  func save(_ document: ProjectWorkspaceDocument) throws {
    let document = try document.validated()
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(document).write(to: url, options: .atomic)
  }
  func preserveUnreadableFile() throws {
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    try FileManager.default.copyItem(at: url, to: url.deletingLastPathComponent().appending(path: "project-regions-preserved-\(UUID().uuidString).json"))
  }
}
