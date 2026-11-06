import Foundation

/// Versioned, portable JSON container. Only regular file bytes can be materialized.
struct AugmaPluginArchive: Codable {
  static let maximumBytes = 12 * 1024 * 1024
  struct File: Codable { let path: String; let data: Data }
  let format: String
  let schemaVersion: Int
  let files: [File]

  static func unpack(_ data: Data, expected: AugmaPluginManifest) throws -> AugmaPluginPackage {
    guard data.count <= maximumBytes else { throw AugmaPluginDistributionError.limit }
    let archive: Self
    do { archive = try JSONDecoder().decode(Self.self, from: data) }
    catch { throw AugmaPluginDistributionError.invalidArchive }
    guard archive.format == "augma-web-plugin", archive.schemaVersion == 1,
          !archive.files.isEmpty, archive.files.count <= 256 else { throw AugmaPluginDistributionError.invalidArchive }
    var names = Set<String>(), total = 0
    for file in archive.files {
      let identity = file.path.precomposedStringWithCanonicalMapping.lowercased()
      guard AugmaPluginManifest.validPath(file.path), names.insert(identity).inserted,
            file.data.count <= AugmaPluginPackageReader.maximumFileBytes,
            file.data.count <= 8 * 1024 * 1024 - total else { throw AugmaPluginDistributionError.invalidArchive }
      total += file.data.count
    }
    let root = FileManager.default.temporaryDirectory.appending(path: "augma-plugin-download-\(UUID())")
      .standardizedFileURL.resolvingSymlinksInPath()
    var committed = false
    defer { if !committed { try? FileManager.default.removeItem(at: root) } }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    for file in archive.files {
      try Task.checkCancellation()
      let destination = root.appending(path: file.path)
      try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
      try file.data.write(to: destination, options: .withoutOverwriting)
    }
    let package = try AugmaPluginPackageReader.inspect(root)
    guard package.manifest == expected else { throw AugmaPluginDistributionError.integrity }
    committed = true
    return package
  }
}
