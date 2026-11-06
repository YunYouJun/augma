import Foundation
import XCTest
@testable import AugmaDesktopDemo

final class AugmaPluginRepositoryTests: XCTestCase {
  func testInstallEnableRestartDisableAndUninstallPreserveTheSourcePackage() async throws {
    let fixture = try AugmaPluginFixture(); defer { fixture.remove() }
    let repository = AugmaPluginRepository(root: fixture.installed)
    let installation = try await repository.install(from: fixture.source)
    XCTAssertFalse(installation.enabled)
    let package = try await repository.package(installation.id)
    XCTAssertNotEqual(package.root, fixture.source)
    try Data("source changed".utf8).write(to: fixture.source.appending(path: "main.js"))
    XCTAssertFalse(try String(contentsOf: package.root.appending(path: "main.js"), encoding: .utf8).contains("source changed"))
    try await repository.setEnabled(installation.id, enabled: true)
    let restarted = AugmaPluginRepository(root: fixture.installed)
    let enabled = try await restarted.load()
    XCTAssertEqual(enabled.map(\.enabled), [true])
    try await restarted.setEnabled(installation.id, enabled: false)
    let disabled = try await AugmaPluginRepository(root: fixture.installed).load()
    XCTAssertEqual(disabled.map(\.enabled), [false])
    try await restarted.uninstall(installation.id)
    let remaining = try await AugmaPluginRepository(root: fixture.installed).load()
    XCTAssertTrue(remaining.isEmpty)
    XCTAssertFalse(FileManager.default.fileExists(atPath: package.root.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.source.appending(path: "augma-plugin.json").path))
  }

  func testManifestRejectsUnsupportedPermissionsSchemaPathsAndIdentifiers() throws {
    let fixture = try AugmaPluginFixture(); defer { fixture.remove() }
    for change: [String: Any] in [["schemaVersion": 2], ["permissions": ["shell"]], ["entry": "../outside.html"],
      ["entry": "/outside.html"], ["entry": "https://example.com/index.html"], ["entry": "%2e%2e/index.html"],
      ["entry": "main.js"], ["id": "../../outside"], ["version": "latest"], ["name": "bad\nname"]] {
      try fixture.writeManifest(change)
      XCTAssertThrowsError(try AugmaPluginPackageReader.inspect(fixture.source), "\(change)")
    }
  }

  func testPackageRejectsSymlinksHardLinksAndOversizedAssets() throws {
    let fixture = try AugmaPluginFixture(); defer { fixture.remove() }
    let outside = fixture.root.appending(path: "outside.js")
    try Data("outside".utf8).write(to: outside)
    let linked = fixture.source.appending(path: "linked.js")
    try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: outside)
    XCTAssertThrowsError(try AugmaPluginPackageReader.inspect(fixture.source))
    try FileManager.default.removeItem(at: linked)
    try FileManager.default.linkItem(at: outside, to: linked)
    XCTAssertThrowsError(try AugmaPluginPackageReader.inspect(fixture.source))
    try FileManager.default.removeItem(at: linked)
    try Data(repeating: 0, count: AugmaPluginPackageReader.maximumFileBytes + 1).write(to: linked)
    XCTAssertThrowsError(try AugmaPluginPackageReader.inspect(fixture.source))
  }

  func testDuplicateInstallAndChangedInstalledManifestAreRejected() async throws {
    let fixture = try AugmaPluginFixture(); defer { fixture.remove() }
    let repository = AugmaPluginRepository(root: fixture.installed)
    let installation = try await repository.install(from: fixture.source)
    do { _ = try await repository.install(from: fixture.source); XCTFail("Duplicate ID must fail") } catch {}
    let package = try await repository.package(installation.id)
    let data = try JSONSerialization.data(withJSONObject: fixture.manifest.merging(["name": "Replaced"]) { _, new in new })
    try data.write(to: package.root.appending(path: "augma-plugin.json"))
    do { try await repository.setEnabled(installation.id, enabled: true); XCTFail("Changed installation must not run") } catch {}
    let restarted = AugmaPluginRepository(root: fixture.installed)
    _ = try await restarted.load()
    do { _ = try await restarted.package(installation.id); XCTFail("Changed installation must not run after restart") } catch {}
  }

  func testFailedRegistryWritesRollBackInstallEnableAndUninstall() async throws {
    let fixture = try AugmaPluginFixture(); defer { fixture.remove() }
    let writes = PluginControlledWrites()
    let repository = AugmaPluginRepository(root: fixture.installed, write: writes.write)
    writes.failing = true
    do { _ = try await repository.install(from: fixture.source); XCTFail("Failed install must roll back") } catch {}
    let afterFailure = try await repository.load()
    XCTAssertTrue(afterFailure.isEmpty)
    writes.failing = false
    let installed = try await repository.install(from: fixture.source)
    let package = try await repository.package(installed.id)
    writes.failing = true
    do { try await repository.setEnabled(installed.id, enabled: true); XCTFail("Enable must persist first") } catch {}
    do { try await repository.uninstall(installed.id); XCTFail("Failed uninstall must restore package") } catch {}
    XCTAssertTrue(FileManager.default.fileExists(atPath: package.root.path))
    let persisted = try await AugmaPluginRepository(root: fixture.installed).load()
    XCTAssertEqual(persisted.map(\.enabled), [false])
  }

  func testCorruptRegistryIsPreservedAndCannotBeOverwrittenByInstall() async throws {
    let fixture = try AugmaPluginFixture(); defer { fixture.remove() }
    try FileManager.default.createDirectory(at: fixture.installed, withIntermediateDirectories: true)
    let registry = fixture.installed.appending(path: "plugins.json"), original = Data("broken".utf8)
    try original.write(to: registry)
    let repository = AugmaPluginRepository(root: fixture.installed)
    do { _ = try await repository.load(); XCTFail("Corrupt registry must fail") } catch {}
    do { _ = try await repository.install(from: fixture.source); XCTFail("Do not overwrite unreadable state") } catch {}
    XCTAssertEqual(try Data(contentsOf: registry), original)
  }

  func testResourceInventoryRejectsForeignOriginsTraversalAndReplacementSymlinks() throws {
    let fixture = try AugmaPluginFixture(); defer { fixture.remove() }
    let package = try AugmaPluginPackageReader.inspect(fixture.source)
    let resource = AugmaPluginResource(package: package)
    let page = try resource.read(resource.entryURL)
    XCTAssertTrue(String(decoding: page.data, as: UTF8.self).hasPrefix("<!doctype html><meta http-equiv=\"Content-Security-Policy\""))
    for address in ["https://example.com/index.html", "file:///etc/hosts", "augma-plugin://other.example/index.html",
      "augma-plugin://\(package.manifest.id)/%2e%2e/outside.js", "augma-plugin://\(package.manifest.id)/%252e%252e/outside.js",
      "augma-plugin://\(package.manifest.id)/missing.js", "augma-plugin://\(package.manifest.id)/index.html?path=outside"] {
      XCTAssertFalse(resource.allows(try XCTUnwrap(URL(string: address))), address)
    }
    let asset = fixture.source.appending(path: "main.js")
    try FileManager.default.removeItem(at: asset)
    let outside = fixture.root.appending(path: "outside.js")
    try Data("outside".utf8).write(to: outside)
    try FileManager.default.createSymbolicLink(at: asset, withDestinationURL: outside)
    XCTAssertThrowsError(try resource.read(URL(string: "augma-plugin://\(package.manifest.id)/main.js")!))
  }

  func testRepositoryExampleIsARealStandalonePackage() throws {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<5 { root.deleteLastPathComponent() }
    let package = try AugmaPluginPackageReader.inspect(root.appending(path: "plugins/breathing-orbit/BreathingOrbit.augmaplugin"))
    XCTAssertEqual(package.manifest.id, "org.augma.examples.breathing-orbit")
    XCTAssertEqual(package.files, ["augma-plugin.json", "index.html", "style.css", "main.js"])
  }
}

@MainActor
final class AugmaPluginLifecycleTests: XCTestCase {
  func testLifecycleClosesAllScenesAndRemovesDockEntries() async throws {
    let fixture = try AugmaPluginFixture(); defer { fixture.remove() }
    let suite = "augma.plugin.lifecycle.\(UUID())", defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let dock = NativeDockStore(defaults: defaults)
    let plugins = AugmaPluginStore(repository: AugmaPluginRepository(root: fixture.installed), dock: dock)
    let first = NativeDemoModel(preferences: NativePreferencesStore(defaults: defaults), dock: dock, plugins: plugins)
    let second = NativeDemoModel(preferences: NativePreferencesStore(defaults: defaults), dock: dock, plugins: plugins)
    defer { first.closeScene(); second.closeScene() }
    await plugins.load()
    await plugins.install(from: fixture.source)
    XCTAssertEqual(plugins.installations.map(\.enabled), [false])
    first.openPlugin(fixture.id)
    XCTAssertEqual(first.selection, .market)
    plugins.pin(fixture.id)
    XCTAssertFalse(dock.items.contains { $0.plugin != nil })
    await plugins.setEnabled(fixture.id, enabled: true)
    first.openPlugin(fixture.id); second.openPlugin(fixture.id)
    for index in 0..<28 {
      dock.restore(.application(.init(id: "test.\(index)", name: "App", path: "/Applications/App.app")))
    }
    XCTAssertEqual(dock.items.count, 40)
    plugins.pin(fixture.id)
    XCTAssertEqual(first.selection, .plugin)
    XCTAssertEqual(second.selection, .plugin)
    XCTAssertEqual(NativeDockStore(defaults: defaults).items.compactMap(\.plugin).map(\.id), [fixture.id])
    await plugins.setEnabled(fixture.id, enabled: false)
    XCTAssertEqual(first.selection, .market)
    XCTAssertEqual(second.selection, .market)
    XCTAssertNil(first.activePluginID)
    XCTAssertFalse(dock.items.contains { $0.plugin != nil })
    await plugins.setEnabled(fixture.id, enabled: true)
    first.openPlugin(fixture.id); plugins.pin(fixture.id)
    await plugins.uninstall(fixture.id)
    XCTAssertTrue(plugins.installations.isEmpty)
    XCTAssertEqual(first.selection, .market)
    XCTAssertFalse(dock.items.contains { $0.plugin != nil })
    XCTAssertTrue(plugins.error.isEmpty)
  }

  func testStartupReconcilesStalePluginShortcuts() async throws {
    let fixture = try AugmaPluginFixture(); defer { fixture.remove() }
    let suite = "augma.plugin.stale.\(UUID())", defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let dock = NativeDockStore(defaults: defaults)
    dock.restore(.plugin(.init(id: fixture.id, name: "Fixture", symbol: "circle")))
    let plugins = AugmaPluginStore(repository: AugmaPluginRepository(root: fixture.installed), dock: dock)
    await plugins.load()
    XCTAssertTrue(plugins.loaded)
    XCTAssertFalse(dock.items.contains { $0.plugin != nil })
  }

  func testMissingInstalledFilesStayManageableAndCannotKeepAPageOpen() async throws {
    let fixture = try AugmaPluginFixture(); defer { fixture.remove() }
    let suite = "augma.plugin.missing.\(UUID())", defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let dock = NativeDockStore(defaults: defaults)
    let repository = AugmaPluginRepository(root: fixture.installed)
    let plugins = AugmaPluginStore(repository: repository, dock: dock)
    let model = NativeDemoModel(preferences: NativePreferencesStore(defaults: defaults), dock: dock, plugins: plugins)
    defer { model.closeScene() }
    await plugins.load(); await plugins.install(from: fixture.source)
    await plugins.setEnabled(fixture.id, enabled: true)
    model.openPlugin(fixture.id); plugins.pin(fixture.id)
    let package = try await repository.package(fixture.id)
    try FileManager.default.removeItem(at: package.root)
    await plugins.retry()
    XCTAssertTrue(plugins.loaded)
    XCTAssertNotNil(plugins.installation(fixture.id)?.problem)
    XCTAssertNil(plugins.enabledPackage(fixture.id))
    XCTAssertEqual(model.selection, .market)
    XCTAssertFalse(dock.items.contains { $0.plugin != nil })
    await plugins.setEnabled(fixture.id, enabled: false)
    XCTAssertEqual(plugins.installation(fixture.id)?.enabled, false)
    await plugins.uninstall(fixture.id)
    XCTAssertTrue(plugins.installations.isEmpty)
    XCTAssertTrue(plugins.error.isEmpty)
  }
}

final class AugmaPluginFixture {
  let root: URL
  let id = "org.example.fixture"
  var source: URL { root.appending(path: "Fixture.augmaplugin") }
  var installed: URL { root.appending(path: "Installed") }
  var manifest: [String: Any] { ["schemaVersion": 1, "id": id, "name": "Fixture", "version": "1.0.0",
    "author": "Tests", "summary": "Fixture", "entry": "index.html", "symbol": "circle", "permissions": []] }

  init(script: String = "window.fixtureLoaded = true") throws {
    root = FileManager.default.temporaryDirectory.appending(path: "augma-plugin-\(UUID())").standardizedFileURL.resolvingSymlinksInPath()
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try writeManifest()
    try Data("<!doctype html><html><head><script src=\"main.js\" defer></script></head><body><h1>Fixture</h1></body></html>".utf8)
      .write(to: source.appending(path: "index.html"))
    try Data(script.utf8).write(to: source.appending(path: "main.js"))
  }

  func writeManifest(_ changes: [String: Any] = [:]) throws {
    try JSONSerialization.data(withJSONObject: manifest.merging(changes) { _, new in new })
      .write(to: source.appending(path: "augma-plugin.json"))
  }
  func remove() { try? FileManager.default.removeItem(at: root) }
}

private final class PluginControlledWrites: @unchecked Sendable {
  private let lock = NSLock()
  private var fail = false
  var failing: Bool { get { lock.withLock { fail } } set { lock.withLock { fail = newValue } } }
  func write(_ data: Data, _ url: URL) throws {
    if failing { throw CocoaError(.fileWriteNoPermission) }
    try data.write(to: url, options: .atomic)
  }
}
