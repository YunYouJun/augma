import AppKit
import Combine

enum ApplicationLibrarySection: String, CaseIterable, Identifiable {
  case installed, store
  var id: String { rawValue }
  var title: String {
    switch self {
    case .installed: String(appLocalized: "已安装应用")
    case .store: "App Store"
    }
  }
}

@MainActor
final class ApplicationLibraryStore: ObservableObject {
  @Published private(set) var applications: [InstalledApplication] = []
  @Published private(set) var results: [StoreApplication] = []
  @Published private(set) var isLoading = false
  @Published private(set) var isSearching = false
  @Published private(set) var hasSearched = false
  @Published private(set) var localError = ""
  @Published private(set) var searchError = ""
  @Published private(set) var actionError = ""
  private let client: any ApplicationLibraryProviding
  private let workspace: any InstalledApplicationClient
  private let openURL: (URL) -> Bool
  private var refreshID = UUID()
  private var searchID = UUID()

  init(client: any ApplicationLibraryProviding = SystemApplicationLibraryClient(),
       workspace: any InstalledApplicationClient = SystemInstalledApplicationClient(),
       openURL: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) }) {
    self.client = client; self.workspace = workspace; self.openURL = openURL
  }

  func filteredApplications(_ query: String) -> [InstalledApplication] {
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return query.isEmpty ? applications : applications.filter {
      $0.name.localizedStandardContains(query) || $0.id.localizedStandardContains(query)
        || URL(fileURLWithPath: $0.path).deletingPathExtension().lastPathComponent.localizedStandardContains(query)
    }
  }

  func installedApplication(bundleID: String) -> InstalledApplication? { applications.first { $0.id == bundleID } }

  func refresh() async {
    let id = UUID(); refreshID = id
    isLoading = true; localError = ""
    do {
      let applications = try await client.installedApplications()
      guard refreshID == id, !Task.isCancelled else { return finishRefresh(id) }
      self.applications = applications
    } catch {
      if refreshID == id, !Task.isCancelled {
        localError = String(appLocalized: "无法读取应用列表，请刷新后重试。")
      }
    }
    finishRefresh(id)
  }

  func search(_ query: String) async {
    clearSearch()
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return }
    let id = searchID
    isSearching = true
    do {
      let results = try await client.search(query)
      guard searchID == id, !Task.isCancelled else { return finishSearch(id) }
      self.results = results; hasSearched = true
    } catch {
      if searchID == id, !Task.isCancelled {
        searchError = String(appLocalized: "App Store 查询失败，请检查网络后重试。")
      }
    }
    finishSearch(id)
  }

  func clearSearch() {
    searchID = UUID(); results = []; searchError = ""; hasSearched = false; isSearching = false
  }

  func addToDock(_ application: InstalledApplication, dock: NativeDockStore) {
    do {
      let checked = try workspace.inspect(URL(fileURLWithPath: application.path))
      guard checked.id == application.id else { throw ApplicationDistrictError.missingApplication }
      dock.restore(.application(checked))
      actionError = ""
    } catch { actionError = error.localizedDescription }
  }

  func openStore(_ application: StoreApplication) {
    actionError = openURL(application.storeURL) ? "" : String(appLocalized: "无法打开 App Store，请稍后重试。")
  }

  private func finishRefresh(_ id: UUID) { if refreshID == id { isLoading = false } }
  private func finishSearch(_ id: UUID) { if searchID == id { isSearching = false } }
}
