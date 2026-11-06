import Foundation

protocol AugmaPluginPersisting: Sendable {
  func load() async throws -> [AugmaPluginInstallation]
  func install(from source: URL) async throws -> AugmaPluginInstallation
  func setEnabled(_ id: String, enabled: Bool) async throws
  func uninstall(_ id: String) async throws
  func package(_ id: String) async throws -> AugmaPluginPackage
}

/// Owns package copies and durable state. Installation never executes plugin code.
actor AugmaPluginRepository: AugmaPluginPersisting {
  static var defaultRoot: URL { URL.applicationSupportDirectory.appending(path: "Augma/Link") }
  private struct Registry: Codable { var version = 1; var plugins: [AugmaPluginInstallation] = [] }
  private let root: URL
  private let write: @Sendable (Data, URL) throws -> Void
  private var registry: Registry?
  private let files = FileManager.default

  init(root: URL = defaultRoot, write: @escaping @Sendable (Data, URL) throws -> Void = { data, url in
    try data.write(to: url, options: .atomic)
  }) {
    self.root = root.standardizedFileURL.resolvingSymlinksInPath(); self.write = write
  }

  func load() throws -> [AugmaPluginInstallation] {
    let url = root.appending(path: "plugins.json")
    let next: Registry
    if files.fileExists(atPath: url.path) {
      guard try isRegularFile(url), (try files.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? Int.max <= 512 * 1024 else {
        throw AugmaPluginError.invalidRegistry
      }
      do { next = try JSONDecoder().decode(Registry.self, from: Data(contentsOf: url)) }
      catch { throw AugmaPluginError.unreadableRegistry }
    } else { next = Registry() }
    guard next.version == 1, next.plugins.count <= 128, Set(next.plugins.map(\.id)).count == next.plugins.count else {
      throw AugmaPluginError.invalidRegistry
    }
    for plugin in next.plugins {
      _ = try plugin.manifest.validated()
    }
    registry = next
    return next.plugins
  }

  func install(from source: URL) throws -> AugmaPluginInstallation {
    var next = try current()
    let checked = try AugmaPluginPackageReader.inspect(source.standardizedFileURL.resolvingSymlinksInPath())
    guard !next.plugins.contains(where: { $0.id == checked.manifest.id }) else { throw AugmaPluginError.alreadyInstalled }
    guard next.plugins.count < 128 else { throw AugmaPluginError.tooLarge }
    try prepareDirectories()
    let stage = root.appending(path: "Staging/\(UUID().uuidString)")
    defer { try? files.removeItem(at: stage) }
    try files.copyItem(at: checked.root, to: stage)
    let staged = try AugmaPluginPackageReader.inspect(stage)
    guard staged.manifest == checked.manifest else { throw AugmaPluginError.invalidPackage }
    let destination = packageURL(staged.manifest.id)
    guard !files.fileExists(atPath: destination.path) else { throw AugmaPluginError.alreadyInstalled }
    try files.moveItem(at: stage, to: destination)
    let installation = AugmaPluginInstallation(manifest: staged.manifest, enabled: false, installedAt: .now)
    next.plugins.append(installation)
    do { try save(next) }
    catch { try? files.removeItem(at: destination); throw error }
    return installation
  }

  func setEnabled(_ id: String, enabled: Bool) throws {
    var next = try current()
    guard let index = next.plugins.firstIndex(where: { $0.id == id }) else { throw AugmaPluginError.notInstalled }
    if enabled { _ = try package(id) }
    next.plugins[index].enabled = enabled
    try save(next)
  }

  func uninstall(_ id: String) throws {
    var next = try current()
    guard next.plugins.contains(where: { $0.id == id }) else { throw AugmaPluginError.notInstalled }
    try prepareDirectories()
    let installed = packageURL(id), retired = root.appending(path: "Staging/\(UUID().uuidString)")
    let hasPackage = files.fileExists(atPath: installed.path)
    if hasPackage { try files.moveItem(at: installed, to: retired) }
    next.plugins.removeAll { $0.id == id }
    do { try save(next) }
    catch { if hasPackage { try? files.moveItem(at: retired, to: installed) }; throw error }
    // The package is no longer installed after the registry commits. Retired files never run.
    if hasPackage { try? files.removeItem(at: retired) }
  }

  func package(_ id: String) throws -> AugmaPluginPackage {
    guard let installed = try current().plugins.first(where: { $0.id == id }) else { throw AugmaPluginError.notInstalled }
    let package = try AugmaPluginPackageReader.inspect(packageURL(id))
    guard package.manifest == installed.manifest else { throw AugmaPluginError.invalidPackage }
    return package
  }

  private func current() throws -> Registry {
    if let registry { return registry }
    _ = try load()
    return registry!
  }

  private func packageURL(_ id: String) -> URL { root.appending(path: "Packages/\(id).augmaplugin") }

  private func prepareDirectories() throws {
    for folder in [root, root.appending(path: "Packages"), root.appending(path: "Staging")] {
      try files.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
      guard folder.path == folder.resolvingSymlinksInPath().path else { throw AugmaPluginError.invalidPackage }
    }
  }

  private func save(_ next: Registry) throws {
    try prepareDirectories()
    let url = root.appending(path: "plugins.json")
    if files.fileExists(atPath: url.path), try !isRegularFile(url) { throw AugmaPluginError.invalidRegistry }
    try write(JSONEncoder().encode(next), url)
    try files.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    registry = next
  }

  private func isRegularFile(_ url: URL) throws -> Bool {
    let attributes = try files.attributesOfItem(atPath: url.path)
    return url.path == url.resolvingSymlinksInPath().path && attributes[.type] as? FileAttributeType == .typeRegular
      && (attributes[.referenceCount] as? NSNumber)?.intValue == 1
  }
}
