import Combine
import Foundation

@MainActor
final class AugmaPluginCatalogStore: ObservableObject {
  @Published private(set) var entries: [AugmaPluginCatalogEntry] = []
  @Published private(set) var refreshing = false
  @Published private(set) var loaded = false
  @Published private(set) var error = ""
  let client: any AugmaPluginCatalogProviding
  private var generation = UUID()

  init(client: any AugmaPluginCatalogProviding = AugmaPluginCatalogClient()) { self.client = client }

  func matches(_ query: String) -> [AugmaPluginCatalogEntry] {
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return entries.filter { query.isEmpty || $0.manifest.displayName.localizedStandardContains(query) || $0.manifest.name.localizedStandardContains(query)
      || $0.manifest.displaySummary.localizedStandardContains(query) || $0.manifest.summary.localizedStandardContains(query) || $0.id.localizedStandardContains(query) }
  }

  func refresh() async {
    let token = UUID(); generation = token; refreshing = true; error = ""
    defer { if generation == token { refreshing = false } }
    do {
      let entries = try await client.fetch()
      guard generation == token, !Task.isCancelled else { return }
      self.entries = entries; loaded = true
    } catch {
      if generation == token, !Task.isCancelled { self.error = error.localizedDescription }
    }
  }
}
