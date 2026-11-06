import Combine
import Foundation

struct AugmaPluginDownloadProgress {
  let bytes: Int
  let total: Int
}

@MainActor
final class AugmaPluginStore: ObservableObject {
  @Published private(set) var installations: [AugmaPluginInstallation] = []
  @Published private(set) var busy = false
  @Published private(set) var loaded = false
  @Published private(set) var error = ""
  @Published private(set) var downloadProgress: AugmaPluginDownloadProgress?
  let catalog: AugmaPluginCatalogStore
  private let repository: any AugmaPluginPersisting
  private let dock: NativeDockStore
  private var packages: [String: AugmaPluginPackage] = [:]
  private var remoteTask: Task<Void, Never>?

  init(repository: any AugmaPluginPersisting = AugmaPluginRepository(), dock: NativeDockStore,
       catalog: AugmaPluginCatalogStore? = nil) {
    self.repository = repository; self.dock = dock
    self.catalog = catalog ?? AugmaPluginCatalogStore()
  }

  static var exampleURL: URL? {
    guard let url = Bundle.main.resourceURL?.appending(path: "LinkCatalog/BreathingOrbit.augmaplugin"),
          FileManager.default.fileExists(atPath: url.path) else { return nil }
    return url
  }

  func installation(_ id: String) -> AugmaPluginInstallation? { installations.first { $0.id == id } }
  func enabledPackage(_ id: String) -> AugmaPluginPackage? {
    installation(id)?.enabled == true && installation(id)?.problem == nil ? packages[id] : nil
  }

  func load() async {
    guard !loaded, !busy else { return }
    await perform { try await self.reload() }
  }

  func retry() async {
    guard !busy else { return }
    await perform { try await self.reload() }
  }

  func install(from source: URL) async {
    guard loaded, !busy else { return }
    await perform {
      _ = try await self.repository.install(from: source)
      try await self.reload()
    }
  }

  func install(_ entry: AugmaPluginCatalogEntry) {
    guard loaded, !busy else { return }
    guard installation(entry.id) == nil else { error = AugmaPluginError.alreadyInstalled.localizedDescription; return }
    busy = true; error = ""; downloadProgress = .init(bytes: 0, total: entry.size)
    remoteTask = Task { [weak self] in
      guard let self else { return }
      defer { self.busy = false; self.downloadProgress = nil; self.remoteTask = nil }
      do {
        let package = try await self.catalog.client.download(entry) { [weak self] bytes, total in
          await MainActor.run { self?.downloadProgress = .init(bytes: bytes, total: total) }
        }
        defer { try? FileManager.default.removeItem(at: package.root) }
        try Task.checkCancellation()
        self.downloadProgress = nil
        _ = try await self.repository.install(from: package.root)
        try await self.reload()
      } catch is CancellationError { self.error = "" }
      catch let error as URLError where error.code == .cancelled { self.error = "" }
      catch { self.error = error.localizedDescription }
    }
  }

  func cancelDownload() { if downloadProgress != nil { remoteTask?.cancel() } }

  func setEnabled(_ id: String, enabled: Bool) async {
    guard loaded, !busy, installation(id) != nil else { return }
    await perform {
      try await self.repository.setEnabled(id, enabled: enabled)
      if !enabled { self.deactivateLocally(id, uninstall: false) }
      try await self.reload()
    }
  }

  func uninstall(_ id: String) async {
    guard loaded, !busy, installation(id) != nil else { return }
    await perform {
      try await self.repository.uninstall(id)
      self.deactivateLocally(id, uninstall: true)
      try await self.reload()
    }
  }

  func pin(_ id: String) {
    guard let package = enabledPackage(id) else { error = AugmaPluginError.unavailable.localizedDescription; return }
    dock.restore(.plugin(.init(id: id, name: package.manifest.name, symbol: package.manifest.symbol, localizations: package.manifest.localizations)))
    error = ""
  }

  private func reload() async throws {
    var installations = try await repository.load()
    var packages: [String: AugmaPluginPackage] = [:]
    for index in installations.indices {
      do {
        packages[installations[index].id] = try await repository.package(installations[index].id)
        installations[index].problem = nil
      } catch { installations[index].problem = error.localizedDescription }
    }
    self.packages = packages
    // Remove shortcuts before publishing so scenes never keep a disabled plugin alive.
    for item in dock.items {
      if let plugin = item.plugin, !installations.contains(where: { $0.id == plugin.id && $0.enabled && $0.problem == nil }) { dock.remove(item) }
    }
    self.installations = installations
    loaded = true
  }

  private func deactivateLocally(_ id: String, uninstall: Bool) {
    packages.removeValue(forKey: id)
    for item in dock.items where item.plugin?.id == id { dock.remove(item) }
    var next = installations
    if uninstall { next.removeAll { $0.id == id } }
    else if let index = next.firstIndex(where: { $0.id == id }) { next[index].enabled = false }
    installations = next
  }

  private func perform(_ operation: () async throws -> Void) async {
    busy = true; error = ""
    defer { busy = false }
    do { try await operation() }
    catch { self.error = error.localizedDescription }
  }
}
