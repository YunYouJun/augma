import Foundation

@MainActor
protocol ApplicationDistrictPersisting {
  func load() throws -> ApplicationDistrictDocument
  func save(_ document: ApplicationDistrictDocument) throws
  func preserveUnreadableFile() throws
}

struct ApplicationDistrictFile: ApplicationDistrictPersisting {
  static var defaultURL: URL { URL.applicationSupportDirectory.appending(path: "Augma/application-district.json") }
  let url: URL

  func load() throws -> ApplicationDistrictDocument {
    guard FileManager.default.fileExists(atPath: url.path) else { return ApplicationDistrictDocument() }
    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    guard size <= 256 * 1024 else { throw ApplicationDistrictError.invalidLayout }
    return try JSONDecoder().decode(ApplicationDistrictDocument.self, from: Data(contentsOf: url)).validated()
  }

  func save(_ document: ApplicationDistrictDocument) throws {
    let checked = try document.validated()
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(checked).write(to: url, options: .atomic)
  }

  func preserveUnreadableFile() throws {
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    let backup = url.deletingLastPathComponent().appending(path: "application-district-preserved-\(UUID().uuidString).json")
    try FileManager.default.copyItem(at: url, to: backup)
  }
}
