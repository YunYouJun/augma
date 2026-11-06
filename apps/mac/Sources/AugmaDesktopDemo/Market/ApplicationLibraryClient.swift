import Foundation

struct StoreApplication: Identifiable, Equatable, Sendable {
  let id: Int
  let bundleID: String
  let name: String
  let developer: String
  let price: String
  let iconURL: URL?
  let storeURL: URL
}

protocol ApplicationLibraryProviding: Sendable {
  func installedApplications() async throws -> [InstalledApplication]
  func search(_ query: String) async throws -> [StoreApplication]
}

actor SystemApplicationLibraryClient: ApplicationLibraryProviding {
  private let roots: [URL]
  private let country: String
  private let session: URLSession

  // macOS hides Safari's /Applications symlink; include the Cryptex applications directly.
  init(roots: [URL] = [FileManager.default.homeDirectoryForCurrentUser.appending(path: "Applications"),
                       URL(fileURLWithPath: "/Applications"), URL(fileURLWithPath: "/System/Applications"),
                       URL(fileURLWithPath: "/System/Cryptexes/App/System/Applications"),
                       URL(fileURLWithPath: "/System/Library/CoreServices/Applications"),
                       URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")],
       country: String = Locale.current.region?.identifier ?? "US", session: URLSession = .shared) {
    self.roots = roots
    self.country = country.count == 2 && country.allSatisfy(\.isLetter) ? country.lowercased() : "us"
    self.session = session
  }

  func installedApplications() async throws -> [InstalledApplication] {
    try scanInstalledApplications()
  }

  private func scanInstalledApplications() throws -> [InstalledApplication] {
    var applications: [String: InstalledApplication] = [:]
    for root in roots {
      try Task.checkCancellation()
      if root.pathExtension.lowercased() == "app" {
        if let app = try? SystemInstalledApplicationClient.inspectApplication(root), applications[app.id] == nil {
          applications[app.id] = app
        }
        continue
      }
      guard let entries = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
      for case let url as URL in entries {
        try Task.checkCancellation()
        if url.pathExtension.lowercased() == "app" {
          entries.skipDescendants()
          if let app = try? SystemInstalledApplicationClient.inspectApplication(url), applications[app.id] == nil {
            applications[app.id] = app
          }
        } else if entries.level > 6 { entries.skipDescendants() }
      }
    }
    return applications.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  func search(_ query: String) async throws -> [StoreApplication] {
    var components = URLComponents(string: "https://itunes.apple.com/search")!
    components.queryItems = [URLQueryItem(name: "term", value: query), .init(name: "media", value: "software"),
      .init(name: "entity", value: "macSoftware"), .init(name: "country", value: country), .init(name: "limit", value: "50")]
    var request = URLRequest(url: components.url!)
    request.timeoutInterval = 20
    let (data, response) = try await session.data(for: request)
    try Task.checkCancellation()
    guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode),
          data.count <= 8 * 1024 * 1024 else { throw URLError(.badServerResponse) }
    return try Self.decode(data, country: country)
  }

  static func decode(_ data: Data, country: String) throws -> [StoreApplication] {
    struct Response: Decodable { let results: [Record] }
    struct Record: Decodable {
      var trackId: Int?
      var bundleId: String?
      var trackName: String?
      var artistName: String?
      var formattedPrice: String?
      var artworkUrl100: URL?
    }
    var seen = Set<Int>()
    return try JSONDecoder().decode(Response.self, from: data).results.compactMap { record in
      guard let id = record.trackId, id > 0, let bundleID = record.bundleId, !bundleID.isEmpty,
            let name = record.trackName, !name.isEmpty, seen.insert(id).inserted,
            let url = URL(string: "macappstore://apps.apple.com/\(country)/app/id\(id)") else { return nil }
      return StoreApplication(id: id, bundleID: bundleID, name: name, developer: record.artistName ?? "",
        price: record.formattedPrice ?? "", iconURL: record.artworkUrl100.flatMap { $0.scheme == "https" ? $0 : nil },
        storeURL: url)
    }
  }
}
