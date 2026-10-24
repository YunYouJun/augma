import MapKit
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class NativeMapTests: XCTestCase {
  private let origin = NativeMapPlace(name: "起点 A", address: "Shanghai", coordinate: NativeMapCoordinate(latitude: 31.23, longitude: 121.47))
  private let destination = NativeMapPlace(name: "终点 B", address: "Shanghai", coordinate: NativeMapCoordinate(latitude: 31.24, longitude: 121.49))

  func testInitializationDoesNotSearchRouteOrOpenMaps() {
    let client = RecordingMapClient()
    let store = NativeMapStore(client: client)
    XCTAssertTrue(store.originQuery.isEmpty)
    XCTAssertNil(store.origin)
    XCTAssertNil(store.destination)
    XCTAssertFalse(store.canRoute)
    XCTAssertTrue(client.searches.isEmpty)
    XCTAssertTrue(client.routes.isEmpty)
    XCTAssertTrue(client.handoffs.isEmpty)
  }

  func testCoordinatesRejectNonfiniteAndOutOfRangeValues() {
    for coordinate in [
      NativeMapCoordinate(latitude: .nan, longitude: 0),
      NativeMapCoordinate(latitude: 0, longitude: .infinity),
      NativeMapCoordinate(latitude: 90.1, longitude: 0),
      NativeMapCoordinate(latitude: 0, longitude: -180.1),
    ] { XCTAssertFalse(coordinate.isValid) }
    XCTAssertTrue(NativeMapCoordinate(latitude: 90, longitude: -180).isValid)
    let store = NativeMapStore(client: RecordingMapClient())
    store.select(NativeMapPlace(name: "Invalid", address: "", coordinate: NativeMapCoordinate(latitude: .nan, longitude: 1)), for: .origin)
    XCTAssertNil(store.origin)
  }

  func testQueryValidationAndEmptyResultsAvoidUnnecessaryServiceCalls() async {
    let client = RecordingMapClient()
    let store = NativeMapStore(client: client)
    for query in [" ", "A", String(repeating: "x", count: 121), "Shang\nHai", "Some\u{0000}where"] {
      store.originQuery = query
      await store.search(.origin)
      XCTAssertNotNil(store.searchErrors[.origin])
    }
    XCTAssertTrue(client.searches.isEmpty)
    store.originQuery = "  上海火车站  "
    await store.search(.origin)
    XCTAssertEqual(client.searches.map(\.query), ["上海火车站"])
    XCTAssertTrue(store.searched.contains(.origin))
    XCTAssertTrue(store.originResults.isEmpty)
    XCTAssertNil(store.searchErrors[.origin])
  }

  func testSearchBoundsDeduplicatesAndRejectsInvalidPlaces() async {
    let client = RecordingMapClient()
    let invalid = NativeMapPlace(name: "Bad", address: "", coordinate: NativeMapCoordinate(latitude: 100, longitude: 20))
    let places = (0..<12).map { NativeMapPlace(name: "Place \($0)", address: "", coordinate: NativeMapCoordinate(latitude: Double($0), longitude: 0)) }
    client.searchResult = .success([invalid, places[0]] + places)
    let store = NativeMapStore(client: client)
    store.destinationQuery = "Museum"
    await store.search(.destination)
    XCTAssertEqual(store.destinationResults, Array(places.prefix(8)))
    XCTAssertTrue(store.originResults.isEmpty)
  }

  func testRepeatedSearchIsThrottledButEndpointsCanSearchIndependently() async {
    let client = RecordingMapClient()
    let clock = MapTestClock()
    let store = NativeMapStore(client: client, now: { clock.date })
    store.originQuery = "Origin"
    store.destinationQuery = "Destination"
    await store.search(.origin)
    await store.search(.origin)
    XCTAssertEqual(client.searches.count, 1)
    XCTAssertNotNil(store.searchErrors[.origin])
    await store.search(.destination)
    XCTAssertEqual(client.searches.count, 2)
    clock.date.addTimeInterval(1)
    await store.search(.origin)
    XCTAssertEqual(client.searches.count, 3)
    XCTAssertNil(store.searchErrors[.origin])
  }

  func testCancelledOlderSearchCannotReplaceNewerResults() async throws {
    let client = RecordingMapClient()
    client.searchResult = nil
    let clock = MapTestClock()
    let store = NativeMapStore(client: client, now: { clock.date })
    store.originQuery = "First"
    let first = Task { await store.search(.origin) }
    await settle()
    let firstID = try XCTUnwrap(client.searches.first?.id)
    store.originQuery = "Second"
    XCTAssertTrue(client.cancelledSearches.contains(firstID))
    clock.date.addTimeInterval(1)
    let second = Task { await store.search(.origin) }
    await settle()
    let secondID = try XCTUnwrap(client.searches.last?.id)
    client.finishSearch(secondID, with: .success([destination]))
    await second.value
    client.finishSearch(firstID, with: .success([origin]))
    await first.value
    XCTAssertEqual(store.originResults, [destination])
    XCTAssertFalse(store.searching.contains(.origin))
    XCTAssertNil(store.searchErrors[.origin])
  }

  func testExplicitCancellationDiscardsLateSearchReply() async throws {
    let client = RecordingMapClient()
    client.searchResult = nil
    let store = NativeMapStore(client: client)
    store.originQuery = "Origin"
    let request = Task { await store.search(.origin) }
    await settle()
    let id = try XCTUnwrap(client.searches.first?.id)
    store.cancelRequests()
    XCTAssertTrue(client.cancelledSearches.contains(id))
    client.finishSearch(id, with: .success([origin]))
    await request.value
    XCTAssertTrue(store.originResults.isEmpty)
    XCTAssertTrue(store.searching.isEmpty)
    XCTAssertTrue(store.searchErrors.isEmpty)
  }

  func testSelectionAndRoutingUseChosenPlacesAndTransport() async {
    let client = RecordingMapClient()
    let store = makeStore(client)
    XCTAssertTrue(store.canRoute)
    XCTAssertEqual(store.originQuery, origin.name)
    XCTAssertEqual(store.destinationQuery, destination.name)
    store.transport = .walking
    await store.calculateRoute()
    XCTAssertEqual(client.routes.count, 1)
    XCTAssertEqual(client.routes.first?.origin, origin)
    XCTAssertEqual(client.routes.first?.destination, destination)
    XCTAssertEqual(client.routes.first?.transport, .walking)
    XCTAssertNotNil(store.route)
    XCTAssertFalse(store.isRouting)
    XCTAssertNil(store.routeError)
  }

  func testEditingEndpointOrTransportInvalidatesExistingRoute() async {
    let client = RecordingMapClient()
    let store = makeStore(client)
    await store.calculateRoute()
    XCTAssertNotNil(store.route)
    store.transport = .walking
    XCTAssertNil(store.route)
    XCTAssertTrue(store.canRoute)
    await store.calculateRoute()
    XCTAssertNotNil(store.route)
    store.originQuery += " edited"
    XCTAssertNil(store.origin)
    XCTAssertNil(store.route)
    XCTAssertFalse(store.canRoute)
    XCTAssertEqual(store.destination, destination)
  }

  func testEndpointChangeCancelsRouteAndRejectsLateResponse() async throws {
    let client = RecordingMapClient()
    client.routeResult = nil
    let store = makeStore(client)
    let pending = Task { await store.calculateRoute() }
    await settle()
    let id = try XCTUnwrap(client.routes.first?.id)
    store.select(NativeMapPlace(name: "New endpoint", address: "", coordinate: NativeMapCoordinate(latitude: 32, longitude: 121)), for: .destination)
    XCTAssertTrue(client.cancelledRoutes.contains(id))
    client.finishRoute(id, with: .success(RecordingMapClient.exampleRoute))
    await pending.value
    XCTAssertNil(store.route)
    XCTAssertNil(store.routeError)
    XCTAssertFalse(store.isRouting)
  }

  func testMissingAndIdenticalEndpointsDoNotRequestRoute() async {
    let client = RecordingMapClient()
    let store = NativeMapStore(client: client)
    await store.calculateRoute()
    XCTAssertNotNil(store.routeError)
    store.select(origin, for: .origin)
    store.select(origin, for: .destination)
    await store.calculateRoute()
    XCTAssertNotNil(store.routeError)
    XCTAssertTrue(client.routes.isEmpty)
  }

  func testNoRouteAndInvalidGeometryProduceRecoverableErrors() async {
    let client = RecordingMapClient()
    let store = makeStore(client)
    client.routeResult = .failure(NativeMapFailure.noRoute)
    await store.calculateRoute()
    XCTAssertNotNil(store.routeError)
    XCTAssertNil(store.route)
    client.routeResult = .success(NativeMapRoute(name: "Bad", distance: .nan, expectedTravelTime: 2, coordinates: [], steps: []))
    await store.calculateRoute()
    XCTAssertNotNil(store.routeError)
    XCTAssertNil(store.route)
    client.routeResult = .success(RecordingMapClient.exampleRoute)
    await store.calculateRoute()
    XCTAssertNotNil(store.route)
    XCTAssertNil(store.routeError)
  }

  func testSearchFailureStopsProgressAndCanBeRetried() async {
    let client = RecordingMapClient()
    client.searchResult = .failure(URLError(.notConnectedToInternet))
    let clock = MapTestClock()
    let store = NativeMapStore(client: client, now: { clock.date })
    store.destinationQuery = "Destination"
    await store.search(.destination)
    XCTAssertNotNil(store.searchErrors[.destination])
    XCTAssertTrue(store.searching.isEmpty)
    client.searchResult = .success([destination])
    clock.date.addTimeInterval(1)
    await store.search(.destination)
    XCTAssertNil(store.searchErrors[.destination])
    XCTAssertEqual(store.destinationResults, [destination])
  }

  func testMapsHandoffUsesExplicitEndpointsAndCorrectDirectionsMode() async {
    XCTAssertEqual(NativeMapTransport.driving.mapKitType, .automobile)
    XCTAssertEqual(NativeMapTransport.walking.mapKitType, .walking)
    XCTAssertEqual(NativeMapTransport.driving.mapsLaunchMode, MKLaunchOptionsDirectionsModeDriving)
    XCTAssertEqual(NativeMapTransport.walking.mapsLaunchMode, MKLaunchOptionsDirectionsModeWalking)
    let client = RecordingMapClient()
    let store = makeStore(client)
    store.transport = .walking
    client.openResult = false
    await store.openInAppleMaps()
    XCTAssertEqual(client.handoffs.first?.origin, origin)
    XCTAssertEqual(client.handoffs.first?.destination, destination)
    XCTAssertEqual(client.handoffs.first?.transport, .walking)
    XCTAssertNotNil(store.mapsNotice)
    XCTAssertFalse(store.isOpeningMaps)
    client.openResult = true
    await store.openInAppleMaps()
    XCTAssertEqual(client.handoffs.count, 2)
    XCTAssertNotNil(store.mapsNotice)
  }

  func testChangingEndpointRejectsStaleHandoffCompletion() async {
    let client = RecordingMapClient()
    client.openResult = nil
    let store = makeStore(client)
    let opening = Task { await store.openInAppleMaps() }
    await settle()
    XCTAssertTrue(store.isOpeningMaps)
    store.destinationQuery = "Another place"
    client.finishHandoff(false)
    await opening.value
    XCTAssertNil(store.mapsNotice)
    XCTAssertFalse(store.isOpeningMaps)
  }

  func testNativeDirectionsCallbackCanArriveOffMainActor() async {
    let result: Result<NativeMapRoute, Error> = await withCheckedContinuation { continuation in
      let callback = NativeMapKitClient.directionsHandler { result in continuation.resume(returning: result) }
      Task.detached { callback(nil, URLError(.notConnectedToInternet)) }
    }
    switch result {
    case .success: XCTFail("A failed native callback must not return a route")
    case .failure(let error): XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
    }
  }

  func testEmptyNativeDirectionsCallbackReportsNoRouteOffMainActor() async {
    let result: Result<NativeMapRoute, Error> = await withCheckedContinuation { continuation in
      let callback = NativeMapKitClient.directionsHandler { result in continuation.resume(returning: result) }
      Task.detached { callback(nil, nil) }
    }
    switch result {
    case .success: XCTFail("A native reply without routes must fail")
    case .failure(let error): XCTAssertEqual(error as? NativeMapFailure, .noRoute)
    }
  }

  private func makeStore(_ client: RecordingMapClient) -> NativeMapStore {
    let store = NativeMapStore(client: client)
    store.select(origin, for: .origin)
    store.select(destination, for: .destination)
    return store
  }

  private func settle() async { for _ in 0..<20 { await Task.yield() } }
}

@MainActor
private final class MapTestClock {
  var date = Date(timeIntervalSince1970: 10_000)
}

@MainActor
private final class RecordingMapClient: NativeMapClient {
  struct Search {
    let id: UUID
    let query: String
  }
  struct Route {
    let id: UUID
    let origin: NativeMapPlace
    let destination: NativeMapPlace
    let transport: NativeMapTransport
  }
  static let exampleRoute = NativeMapRoute(
    name: "Example road", distance: 2_000, expectedTravelTime: 450,
    coordinates: [NativeMapCoordinate(latitude: 31.23, longitude: 121.47), NativeMapCoordinate(latitude: 31.24, longitude: 121.49)],
    steps: [NativeMapStep(id: 0, instruction: "Head north", distance: 300)]
  )
  var searchResult: Result<[NativeMapPlace], Error>? = .success([])
  var routeResult: Result<NativeMapRoute, Error>? = .success(exampleRoute)
  var openResult: Bool? = true
  var searches: [Search] = []
  var routes: [Route] = []
  var handoffs: [Route] = []
  var cancelledSearches: [UUID] = []
  var cancelledRoutes: [UUID] = []
  private var pendingSearches: [UUID: CheckedContinuation<[NativeMapPlace], Error>] = [:]
  private var pendingRoutes: [UUID: CheckedContinuation<NativeMapRoute, Error>] = [:]
  private var pendingHandoff: CheckedContinuation<Bool, Never>?

  func search(query: String, requestID: UUID) async throws -> [NativeMapPlace] {
    searches.append(Search(id: requestID, query: query))
    if let searchResult { return try searchResult.get() }
    return try await withCheckedThrowingContinuation { pendingSearches[requestID] = $0 }
  }
  func route(from origin: NativeMapPlace, to destination: NativeMapPlace, transport: NativeMapTransport, requestID: UUID) async throws -> NativeMapRoute {
    routes.append(Route(id: requestID, origin: origin, destination: destination, transport: transport))
    if let routeResult { return try routeResult.get() }
    return try await withCheckedThrowingContinuation { pendingRoutes[requestID] = $0 }
  }
  func cancelSearch(requestID: UUID) { cancelledSearches.append(requestID) }
  func cancelRoute(requestID: UUID) { cancelledRoutes.append(requestID) }
  func openMaps(from origin: NativeMapPlace, to destination: NativeMapPlace, transport: NativeMapTransport) async -> Bool {
    handoffs.append(Route(id: UUID(), origin: origin, destination: destination, transport: transport))
    if let openResult { return openResult }
    return await withCheckedContinuation { pendingHandoff = $0 }
  }
  func finishSearch(_ id: UUID, with result: Result<[NativeMapPlace], Error>) { pendingSearches.removeValue(forKey: id)?.resume(with: result) }
  func finishRoute(_ id: UUID, with result: Result<NativeMapRoute, Error>) { pendingRoutes.removeValue(forKey: id)?.resume(with: result) }
  func finishHandoff(_ result: Bool) { pendingHandoff?.resume(returning: result); pendingHandoff = nil }
}
