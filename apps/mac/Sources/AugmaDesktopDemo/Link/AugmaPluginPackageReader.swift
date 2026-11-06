import Foundation

enum AugmaPluginPackageReader {
  static let maximumFileBytes = 2 * 1024 * 1024
  private static let extensions: Set<String> = ["json", "html", "css", "js", "svg", "png", "jpg", "jpeg", "gif", "webp", "woff", "woff2", "txt"]

  static func inspect(_ root: URL) throws -> AugmaPluginPackage {
    let files = FileManager.default
    guard root.isFileURL,
          try files.attributesOfItem(atPath: root.path)[.type] as? FileAttributeType == .typeDirectory,
          root.lastPathComponent != "/" else { throw AugmaPluginError.invalidPackage }
    let root = root.standardizedFileURL.resolvingSymlinksInPath()
    guard
          let entries = files.enumerator(at: root, includingPropertiesForKeys: nil, options: []) else {
      throw AugmaPluginError.invalidPackage
    }
    var paths = Set<String>(), bytes = 0, entriesCount = 0
    for case let url as URL in entries {
      try Task.checkCancellation()
      entriesCount += 1
      guard entriesCount <= 512 else { throw AugmaPluginError.tooLarge }
      let attributes = try files.attributesOfItem(atPath: url.path)
      guard [.typeRegular, .typeDirectory].contains(attributes[.type] as? FileAttributeType) else { throw AugmaPluginError.invalidPackage }
      let url = url.standardizedFileURL.resolvingSymlinksInPath()
      guard url.path.hasPrefix(root.path + "/") else { throw AugmaPluginError.invalidPackage }
      let relative = String(url.path.dropFirst(root.path.count + 1))
      guard AugmaPluginManifest.validPath(relative),
            relative.split(separator: "/").count <= 8 else { throw AugmaPluginError.invalidPackage }
      if attributes[.type] as? FileAttributeType == .typeDirectory { continue }
      guard attributes[.type] as? FileAttributeType == .typeRegular,
            (attributes[.referenceCount] as? NSNumber)?.intValue == 1,
            extensions.contains(url.pathExtension.lowercased()) else { throw AugmaPluginError.invalidPackage }
      let size = (attributes[.size] as? NSNumber)?.intValue ?? Int.max
      guard size <= maximumFileBytes, size <= 8 * 1024 * 1024 - bytes, paths.count < 256 else { throw AugmaPluginError.tooLarge }
      paths.insert(relative); bytes += size
    }
    guard paths.contains("augma-plugin.json") else { throw AugmaPluginError.invalidManifest }
    let data = try Data(contentsOf: root.appending(path: "augma-plugin.json"))
    guard data.count <= 32 * 1024 else { throw AugmaPluginError.invalidManifest }
    let manifest = try JSONDecoder().decode(AugmaPluginManifest.self, from: data).validated()
    guard paths.contains(manifest.entry) else { throw AugmaPluginError.invalidManifest }
    return AugmaPluginPackage(manifest: manifest, root: root, files: paths)
  }
}
