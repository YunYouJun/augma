import CryptoKit
import Foundation
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class AugmaPluginDistributionTests: XCTestCase {
  func testHTTPQueryDownloadVerificationAndInstallUseTheRealClient() async throws {
    let fixture = try PluginDistributionFixture(); defer { fixture.close() }
    let client = AugmaPluginCatalogClient(source: fixture.source, allowLocalHTTP: true)
    let catalog = AugmaPluginCatalogStore(client: client)
    await catalog.refresh()
    XCTAssertEqual(catalog.entries.map(\.id), [fixture.plugin.id])
    XCTAssertEqual(catalog.matches("FIXTURE").count, 1)
    XCTAssertTrue(catalog.matches("not-present").isEmpty)
    let package = try await client.download(try XCTUnwrap(catalog.entries.first)) { _, _ in }
    defer { try? FileManager.default.removeItem(at: package.root) }
    let repository = AugmaPluginRepository(root: fixture.plugin.installed)
    let installation = try await repository.install(from: package.root)
    XCTAssertEqual(installation.id, fixture.plugin.id)
    XCTAssertFalse(installation.enabled)
    try await repository.setEnabled(installation.id, enabled: true)
    let enabled = try await repository.load()
    XCTAssertEqual(enabled.map(\.enabled), [true])
    try await repository.uninstall(installation.id)
    let remaining = try await repository.load()
    XCTAssertTrue(remaining.isEmpty)
  }

  func testTamperedDownloadsAndRedirectsNeverReachInstallation() async throws {
    let fixture = try PluginDistributionFixture(); defer { fixture.close() }
    let client = AugmaPluginCatalogClient(source: fixture.source, allowLocalHTTP: true)
    let original = fixture.entry
    let wrongHash = AugmaPluginCatalogEntry(manifest: original.manifest, packageURL: original.packageURL,
      size: original.size, sha256: String(repeating: "0", count: 64))
    do { _ = try await client.download(wrongHash) { _, _ in }; XCTFail("Tampering must fail") } catch {}
    let redirect = AugmaPluginCatalogEntry(manifest: original.manifest, packageURL: "redirect.json", size: original.size, sha256: original.sha256)
    do { _ = try await client.download(redirect) { _, _ in }; XCTFail("Redirect must fail") } catch {}
    XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.plugin.installed.appending(path: "plugins.json").path))
  }

  func testUntrustedOriginsAndOversizedResponsesAreRejected() async throws {
    let fixture = try PluginDistributionFixture(); defer { fixture.close() }
    XCTAssertFalse(AugmaPluginCatalogSource.isAllowed(fixture.source))
    XCTAssertFalse(AugmaPluginCatalogSource.isAllowed(URL(string: "http://example.com/plugins/catalog.json")!, allowLocalHTTP: true))
    XCTAssertFalse(AugmaPluginCatalogSource.isAllowed(URL(string: "https://user:secret@example.com/plugins/catalog.json")!))
    for path in ["https://other.example/package.json", "../outside.json", "file:///etc/hosts"] {
      let entry = AugmaPluginCatalogEntry(manifest: fixture.entry.manifest, packageURL: path,
        size: fixture.entry.size, sha256: fixture.entry.sha256)
      XCTAssertThrowsError(try entry.validated(source: fixture.source, allowLocalHTTP: true))
    }
    let client = AugmaPluginCatalogClient(source: fixture.source.deletingLastPathComponent().appending(path: "oversized.json"), allowLocalHTTP: true)
    do { _ = try await client.fetch(); XCTFail("Oversized response must fail") } catch {}
  }

  func testArchiveRejectsTraversalDuplicateNamesAndIdentityMismatch() throws {
    let fixture = try PluginDistributionFixture(); defer { fixture.close() }
    let valid = try JSONDecoder().decode(AugmaPluginArchive.self, from: fixture.archive)
    for files in [valid.files + [.init(path: "../outside.js", data: Data())],
      valid.files + [.init(path: "MAIN.js", data: Data())],
      valid.files + [.init(path: "main.js", data: Data())]] {
      let data = try JSONEncoder().encode(AugmaPluginArchive(format: "augma-web-plugin", schemaVersion: 1, files: files))
      XCTAssertThrowsError(try AugmaPluginArchive.unpack(data, expected: fixture.entry.manifest))
    }
    var manifest = fixture.plugin.manifest; manifest["id"] = "org.other.plugin"
    let expected = try JSONDecoder().decode(AugmaPluginManifest.self, from: JSONSerialization.data(withJSONObject: manifest))
    XCTAssertThrowsError(try AugmaPluginArchive.unpack(fixture.archive, expected: expected))
  }

  func testCancellingARealDownloadLeavesNoInstalledPlugin() async throws {
    let fixture = try PluginDistributionFixture(); defer { fixture.close() }
    let suite = "augma.remote.cancel.\(UUID())", defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let client = AugmaPluginCatalogClient(source: fixture.source, allowLocalHTTP: true)
    let plugins = AugmaPluginStore(repository: AugmaPluginRepository(root: fixture.plugin.installed),
      dock: NativeDockStore(defaults: defaults), catalog: AugmaPluginCatalogStore(client: client))
    await plugins.load()
    let entry = AugmaPluginCatalogEntry(manifest: fixture.entry.manifest, packageURL: "slow.json",
      size: fixture.entry.size, sha256: fixture.entry.sha256)
    plugins.install(entry)
    try await Task.sleep(for: .milliseconds(80))
    XCTAssertTrue(plugins.busy)
    plugins.cancelDownload()
    let deadline = ContinuousClock.now.advanced(by: .seconds(4))
    while plugins.busy && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
    XCTAssertFalse(plugins.busy)
    XCTAssertTrue(plugins.installations.isEmpty)
    XCTAssertTrue(plugins.error.isEmpty)
  }

  func testPublishedCatalogAndPackageWhenRequested() async throws {
    guard ProcessInfo.processInfo.environment["AUGMA_TEST_REMOTE_PLUGIN_CATALOG"] == "1" else { throw XCTSkip("Opt-in public distribution check") }
    let source = AugmaPluginCatalogSource.configured
    XCTAssertEqual(source.scheme, "https", "Public distribution checks must use HTTPS")
    let client = AugmaPluginCatalogClient(source: source)
    let entries = try await client.fetch()
    let entry = try XCTUnwrap(entries.first { $0.id == "org.augma.examples.breathing-orbit" })
    let package = try await client.download(entry) { _, _ in }
    defer { try? FileManager.default.removeItem(at: package.root) }
    XCTAssertEqual(package.manifest, entry.manifest)
    XCTAssertTrue(package.files.contains("main.js"))
    let root = FileManager.default.temporaryDirectory.appending(path: "augma-public-plugin-test-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let repository = AugmaPluginRepository(root: root)
    let installation = try await repository.install(from: package.root)
    XCTAssertFalse(installation.enabled)
    try await repository.setEnabled(installation.id, enabled: true)
    let enabled = try await repository.load()
    XCTAssertEqual(enabled.map(\.enabled), [true])
    try await repository.setEnabled(installation.id, enabled: false)
    let disabled = try await repository.load()
    XCTAssertEqual(disabled.map(\.enabled), [false])
    try await repository.uninstall(installation.id)
    let remaining = try await repository.load()
    XCTAssertTrue(remaining.isEmpty)
  }
}

private final class PluginDistributionFixture {
  let plugin: AugmaPluginFixture
  let archive: Data
  let entry: AugmaPluginCatalogEntry
  let process = Process()
  let source: URL

  init() throws {
    let plugin = try AugmaPluginFixture()
    self.plugin = plugin
    let files = try ["augma-plugin.json", "index.html", "main.js"].map {
      AugmaPluginArchive.File(path: $0, data: try Data(contentsOf: plugin.source.appending(path: $0)))
    }
    archive = try JSONEncoder().encode(AugmaPluginArchive(format: "augma-web-plugin", schemaVersion: 1, files: files))
    let manifest = try AugmaPluginPackageReader.inspect(plugin.source).manifest
    entry = .init(manifest: manifest, packageURL: "packages/fixture.augmaplugin.json", size: archive.count,
      sha256: SHA256.hash(data: archive).map { String(format: "%02x", $0) }.joined())
    let root = plugin.root.appending(path: "plugins/packages")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try archive.write(to: root.appending(path: "fixture.augmaplugin.json"))
    try JSONEncoder().encode(AugmaPluginCatalog(schemaVersion: 1, plugins: [entry]))
      .write(to: plugin.root.appending(path: "plugins/catalog.json"))
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    process.arguments = ["-u", "-c", Self.server, plugin.root.path]
    process.standardOutput = output; process.standardError = FileHandle.nullDevice
    try process.run()
    let ready = output.fileHandleForReading.availableData
    guard let value = String(data: ready, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
          let port = Int(value), port > 0 else { process.terminate(); throw URLError(.cannotConnectToHost) }
    source = URL(string: "http://127.0.0.1:\(port)/plugins/catalog.json")!
  }

  func close() { if process.isRunning { process.terminate(); process.waitUntilExit() }; plugin.remove() }

  private static let server = """
  import http.server, sys, time
  from pathlib import Path
  root = Path(sys.argv[1])
  class Handler(http.server.SimpleHTTPRequestHandler):
      def __init__(self, *args, **kwargs): super().__init__(*args, directory=str(root), **kwargs)
      def log_message(self, *args): pass
      def do_GET(self):
          if self.path.endswith('/redirect.json'):
              self.send_response(302); self.send_header('Location', '/plugins/packages/fixture.augmaplugin.json'); self.end_headers(); return
          if self.path.endswith('/oversized.json'):
              self.send_response(200); self.send_header('Content-Length', '524289'); self.end_headers(); return
          if self.path.endswith('/slow.json'):
              data = (root / 'plugins/packages/fixture.augmaplugin.json').read_bytes()
              self.send_response(200); self.send_header('Content-Length', str(len(data))); self.end_headers()
              try:
                  for offset in range(0, len(data), 16):
                      self.wfile.write(data[offset:offset+16]); self.wfile.flush(); time.sleep(0.02)
              except (BrokenPipeError, ConnectionResetError): pass
              return
          super().do_GET()
  server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
  server.daemon_threads = True
  print(server.server_address[1], flush=True)
  server.serve_forever()
  """
}
