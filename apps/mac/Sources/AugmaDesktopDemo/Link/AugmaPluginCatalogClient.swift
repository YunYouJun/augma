import CryptoKit
import Foundation

protocol AugmaPluginCatalogProviding: Sendable {
  var source: URL { get }
  func fetch() async throws -> [AugmaPluginCatalogEntry]
  func download(_ entry: AugmaPluginCatalogEntry,
                progress: @escaping @Sendable (Int, Int) async -> Void) async throws -> AugmaPluginPackage
}

actor AugmaPluginCatalogClient: AugmaPluginCatalogProviding {
  nonisolated let source: URL
  private let session: URLSession
  private let redirects = PluginCatalogRedirects()
  private let allowLocalHTTP: Bool

  init(source: URL = AugmaPluginCatalogSource.configured,
       allowLocalHTTP: Bool = AugmaPluginCatalogSource.allowsLocalDevelopmentHTTP) {
    self.source = source; self.allowLocalHTTP = allowLocalHTTP
    let configuration = URLSessionConfiguration.ephemeral
    configuration.urlCache = nil; configuration.httpCookieStorage = nil; configuration.urlCredentialStorage = nil
    configuration.httpShouldSetCookies = false
    configuration.timeoutIntervalForRequest = 20; configuration.timeoutIntervalForResource = 60
    session = URLSession(configuration: configuration)
  }

  deinit { session.invalidateAndCancel() }

  func fetch() async throws -> [AugmaPluginCatalogEntry] {
    let data = try await read(source, limit: 512 * 1024)
    let catalog: AugmaPluginCatalog
    do { catalog = try JSONDecoder().decode(AugmaPluginCatalog.self, from: data) }
    catch { throw AugmaPluginDistributionError.invalidCatalog }
    guard catalog.schemaVersion == 1, catalog.plugins.count <= 128,
          Set(catalog.plugins.map(\.id)).count == catalog.plugins.count else { throw AugmaPluginDistributionError.invalidCatalog }
    for entry in catalog.plugins { _ = try entry.validated(source: source, allowLocalHTTP: allowLocalHTTP) }
    return catalog.plugins
  }

  func download(_ entry: AugmaPluginCatalogEntry,
                progress: @escaping @Sendable (Int, Int) async -> Void) async throws -> AugmaPluginPackage {
    let url = try entry.validated(source: source, allowLocalHTTP: allowLocalHTTP)
    let data = try await read(url, limit: entry.size, progress: { count in await progress(count, entry.size) })
    let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    guard data.count == entry.size, digest == entry.sha256 else { throw AugmaPluginDistributionError.integrity }
    try Task.checkCancellation()
    return try AugmaPluginArchive.unpack(data, expected: entry.manifest)
  }

  private func read(_ url: URL, limit: Int, progress: @escaping @Sendable (Int) async -> Void = { _ in }) async throws -> Data {
    guard AugmaPluginCatalogSource.isAllowed(url, allowLocalHTTP: allowLocalHTTP) else { throw AugmaPluginDistributionError.invalidSource }
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let (bytes, response) = try await session.bytes(for: request, delegate: redirects)
    defer { bytes.task.cancel() }
    guard let response = response as? HTTPURLResponse, response.statusCode == 200,
          response.url == url else { throw AugmaPluginDistributionError.response }
    guard response.expectedContentLength <= limit else { throw AugmaPluginDistributionError.limit }
    var data = Data()
    data.reserveCapacity(min(limit, max(0, Int(response.expectedContentLength))))
    await progress(0)
    for try await byte in bytes {
      try Task.checkCancellation()
      guard data.count < limit else { throw AugmaPluginDistributionError.limit }
      data.append(byte)
      if data.count % 4096 == 0 { await progress(data.count) }
    }
    await progress(data.count)
    return data
  }
}

private final class PluginCatalogRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
    completionHandler(nil)
  }
}
