import Combine
import Foundation
import MapKit
import SwiftUI

/// One app-owned instance preserves searches, camera and route when the view moves between windows.
@MainActor
final class NativeMapStore: ObservableObject {
  static let maximumQueryLength = 120
  static let minimumSearchInterval: TimeInterval = 0.8

  @Published var originQuery = "" { didSet { if originQuery != oldValue { queryChanged(.origin) } } }
  @Published var destinationQuery = "" { didSet { if destinationQuery != oldValue { queryChanged(.destination) } } }
  @Published var transport: NativeMapTransport = .driving {
    didSet { if transport != oldValue { invalidateRoute() } }
  }
  @Published var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
    span: MKCoordinateSpan(latitudeDelta: 100, longitudeDelta: 200)
  ))
  @Published private(set) var origin: NativeMapPlace?
  @Published private(set) var destination: NativeMapPlace?
  @Published private(set) var originResults: [NativeMapPlace] = []
  @Published private(set) var destinationResults: [NativeMapPlace] = []
  @Published private(set) var searching: Set<NativeMapEndpoint> = []
  @Published private(set) var searched: Set<NativeMapEndpoint> = []
  @Published private(set) var searchErrors: [NativeMapEndpoint: String] = [:]
  @Published private(set) var route: NativeMapRoute?
  @Published var showsSteps = false
  @Published private(set) var isRouting = false
  @Published private(set) var routeError: String?
  @Published private(set) var isOpeningMaps = false
  @Published private(set) var mapsNotice: String?

  private let client: any NativeMapClient
  private let now: () -> Date
  private var searchIDs: [NativeMapEndpoint: UUID] = [:]
  private var searchTasks: [NativeMapEndpoint: Task<Void, Never>] = [:]
  private var lastSearch: [NativeMapEndpoint: Date] = [:]
  private var routeID = UUID()
  private var routeTask: Task<Void, Never>?
  private var mapsID = UUID()

  init(client: any NativeMapClient = NativeMapKitClient(), now: @escaping () -> Date = { Date() }) {
    self.client = client
    self.now = now
  }

  var canRoute: Bool { origin != nil && destination != nil }
  func query(for endpoint: NativeMapEndpoint) -> String { endpoint == .origin ? originQuery : destinationQuery }
  func results(for endpoint: NativeMapEndpoint) -> [NativeMapPlace] { endpoint == .origin ? originResults : destinationResults }
  func selected(for endpoint: NativeMapEndpoint) -> NativeMapPlace? { endpoint == .origin ? origin : destination }

  func search(_ endpoint: NativeMapEndpoint) async {
    if let task = searchTasks[endpoint], searching.contains(endpoint) {
      await task.value
      return
    }
    cancelSearch(endpoint)
    searchErrors[endpoint] = nil
    searched.remove(endpoint)
    setResults([], for: endpoint)
    let query = query(for: endpoint).trimmingCharacters(in: .whitespacesAndNewlines)
    guard (2...Self.maximumQueryLength).contains(query.count), !query.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
      searchErrors[endpoint] = String(localized: "请输入 2 至 120 个字符的地点名称。")
      return
    }
    if let last = lastSearch[endpoint], now().timeIntervalSince(last) < Self.minimumSearchInterval {
      searchErrors[endpoint] = String(localized: "搜索过于频繁，请稍后重试。")
      return
    }
    lastSearch[endpoint] = now()
    let id = UUID()
    searchIDs[endpoint] = id
    searching.insert(endpoint)
    let task = Task { [self] in
      defer {
        if searchIDs[endpoint] == id {
          searching.remove(endpoint)
          searchTasks.removeValue(forKey: endpoint)
        }
      }
      do {
        guard !Task.isCancelled, searchIDs[endpoint] == id else { return }
        let places = try await client.search(query: query, requestID: id)
        guard !Task.isCancelled, searchIDs[endpoint] == id else { return }
        var seen = Set<String>()
        setResults(Array(places.filter { $0.isValid && seen.insert($0.id).inserted }.prefix(8)), for: endpoint)
        searched.insert(endpoint)
      } catch {
        guard !Task.isCancelled, searchIDs[endpoint] == id, !Self.isCancellation(error) else { return }
        searchErrors[endpoint] = String(localized: "无法搜索地点，请检查网络后重试。")
      }
    }
    searchTasks[endpoint] = task
    await task.value
  }

  func select(_ place: NativeMapPlace, for endpoint: NativeMapEndpoint) {
    guard place.isValid else { return }
    cancelSearch(endpoint)
    invalidateRoute()
    if endpoint == .origin {
      originQuery = place.name
      origin = place
    } else {
      destinationQuery = place.name
      destination = place
    }
    searchErrors[endpoint] = nil
    searched.remove(endpoint)
    setResults([], for: endpoint)
    cameraPosition = .automatic
  }

  func calculateRoute() async {
    if let routeTask, isRouting { await routeTask.value; return }
    invalidateRoute()
    guard let origin, let destination else {
      routeError = String(localized: "请分别搜索并选择起点和终点。")
      return
    }
    guard origin.coordinate != destination.coordinate else {
      routeError = String(localized: "起点和终点相同，请选择其他地点。")
      return
    }
    let id = routeID
    let transport = transport
    isRouting = true
    let task = Task { [self] in
      defer {
        if routeID == id { isRouting = false; routeTask = nil }
      }
      do {
        guard !Task.isCancelled, routeID == id else { return }
        let result = try await client.route(from: origin, to: destination, transport: transport, requestID: id)
        guard !Task.isCancelled, routeID == id else { return }
        guard result.isValid else { throw NativeMapFailure.noRoute }
        route = result
        cameraPosition = .automatic
      } catch {
        guard !Task.isCancelled, routeID == id, !Self.isCancellation(error) else { return }
        if error as? NativeMapFailure == .noRoute || (error as? MKError)?.code == .directionsNotFound {
          routeError = String(localized: "没有找到此出行方式的路线，请更换地点或出行方式。")
        } else {
          routeError = String(localized: "无法获取路线，请检查网络后重试。")
        }
      }
    }
    routeTask = task
    await task.value
  }

  func clearRoute() { invalidateRoute(); cameraPosition = .automatic }

  func openInAppleMaps() async {
    guard !isOpeningMaps, let origin, let destination else { return }
    let id = UUID()
    mapsID = id
    isOpeningMaps = true
    mapsNotice = nil
    let success = await client.openMaps(from: origin, to: destination, transport: transport)
    guard mapsID == id else { return }
    isOpeningMaps = false
    mapsNotice = success
      ? String(localized: "已在苹果地图中打开路线。")
      : String(localized: "无法打开苹果地图，请稍后重试。")
  }

  /// App lifecycle only; ordinary view disappearance must keep the shared work alive.
  func cancelRequests() {
    for endpoint in NativeMapEndpoint.allCases { cancelSearch(endpoint) }
    invalidateRoute()
  }

  private func queryChanged(_ endpoint: NativeMapEndpoint) {
    cancelSearch(endpoint)
    if endpoint == .origin { origin = nil } else { destination = nil }
    searched.remove(endpoint)
    searchErrors[endpoint] = nil
    setResults([], for: endpoint)
    invalidateRoute()
  }

  private func cancelSearch(_ endpoint: NativeMapEndpoint) {
    if let id = searchIDs.removeValue(forKey: endpoint) { client.cancelSearch(requestID: id) }
    searchTasks.removeValue(forKey: endpoint)?.cancel()
    searching.remove(endpoint)
  }

  private func invalidateRoute() {
    client.cancelRoute(requestID: routeID)
    routeID = UUID()
    routeTask?.cancel()
    routeTask = nil
    route = nil
    showsSteps = false
    isRouting = false
    routeError = nil
    mapsID = UUID()
    isOpeningMaps = false
    mapsNotice = nil
  }

  private func setResults(_ results: [NativeMapPlace], for endpoint: NativeMapEndpoint) {
    if endpoint == .origin { originResults = results } else { destinationResults = results }
  }

  private static func isCancellation(_ error: Error) -> Bool {
    error is CancellationError || (error as? URLError)?.code == .cancelled
  }
}
