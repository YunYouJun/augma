import Foundation
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class WeatherTests: XCTestCase {
  private let time = Date(timeIntervalSince1970: 1_792_720_800)
  private let tokyo = WeatherCity(id: 1, name: "Tokyo", latitude: 35.68, longitude: 139.69, country: "Japan", admin1: "Tokyo", timezone: "Asia/Tokyo")
  private let shanghai = WeatherCity(id: 2, name: "Shanghai", latitude: 31.23, longitude: 121.47, country: "China", admin1: "Shanghai", timezone: "Asia/Shanghai")

  func testSearchRequestEncodesSearchTextWithoutInjectingOtherParameters() throws {
    let request = try WeatherClient.searchRequest(query: "杭州 & Tokyo+Japan", language: "zh")
    let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
    XCTAssertEqual(components.host, "geocoding-api.open-meteo.com")
    XCTAssertEqual(components.queryItems?.first(where: { $0.name == "name" })?.value, "杭州 & Tokyo+Japan")
    XCTAssertEqual(components.queryItems?.count, 4)
    XCTAssertEqual(request.timeoutInterval, 15)
  }

  func testForecastExplicitlyRequestsCelsiusAndAbsoluteTimes() throws {
    let request = try WeatherClient.forecastRequest(city: tokyo)
    let items = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems)
    let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value) })
    XCTAssertEqual(values["temperature_unit"], "celsius")
    XCTAssertEqual(values["wind_speed_unit"], "kmh")
    XCTAssertEqual(values["timeformat"], "unixtime")
    XCTAssertEqual(values["timezone"], "auto")
    XCTAssertNil(values["apikey"] ?? nil)
  }

  func testDecodesCurrentAndDailyWeatherWithoutApplyingTimezoneTwice() async throws {
    let data = forecastData(temperature: 23, observedAt: time)
    let client = WeatherClient { request in (data, Self.response(request)) }
    let snapshot = try await client.weather(for: tokyo, fetchedAt: time)
    XCTAssertEqual(snapshot.temperature, 23)
    XCTAssertEqual(snapshot.apparentTemperature, 22)
    XCTAssertEqual(snapshot.relativeHumidity, 65)
    XCTAssertEqual(snapshot.highTemperature, 26)
    XCTAssertEqual(snapshot.lowTemperature, 18)
    XCTAssertEqual(snapshot.observedAt, time)
    XCTAssertEqual(snapshot.timeZone.secondsFromGMT(for: time), 9 * 60 * 60)
  }

  func testEmptySearchResponseIsANormalResultAndInvalidCoordinatesAreFiltered() async throws {
    let transport = WeatherQueuedTransport([
      .init(data: Data("{}".utf8)),
      .init(data: Data("{\"results\":[{\"id\":3,\"name\":\"Invalid\",\"latitude\":91,\"longitude\":0}]}".utf8)),
    ])
    let client = WeatherClient { try await transport.load($0) }
    let empty = try await client.searchCities("NoCity")
    let invalid = try await client.searchCities("Invalid")
    XCTAssertTrue(empty.isEmpty)
    XCTAssertTrue(invalid.isEmpty)
  }

  func testHTTPFailureIsReportedBeforeAttemptingToDecodeBody() async {
    let client = WeatherClient { request in (Data("not json".utf8), Self.response(request, status: 429)) }
    do {
      _ = try await client.weather(for: tokyo, fetchedAt: time)
      XCTFail("Expected HTTP failure")
    } catch {
      XCTAssertEqual(error as? WeatherFailure, .http(429))
    }
  }

  func testMalformedWeatherDoesNotBecomeAZeroDegreeReading() async {
    let client = WeatherClient { request in (Data("{\"timezone\":\"Asia/Tokyo\",\"current\":{}}".utf8), Self.response(request)) }
    do {
      _ = try await client.weather(for: tokyo, fetchedAt: time)
      XCTFail("Expected invalid response")
    } catch {
      XCTAssertEqual(error as? WeatherFailure, .invalidResponse)
    }
  }

  func testCacheExpiresAtFifteenMinutesAndRejectsFutureClockSkew() async throws {
    let data = forecastData(temperature: 23, observedAt: time)
    let client = WeatherClient { request in (data, Self.response(request)) }
    let snapshot = try await client.weather(for: tokyo, fetchedAt: time)
    XCTAssertFalse(snapshot.isStale(at: time.addingTimeInterval(899)))
    XCTAssertTrue(snapshot.isStale(at: time.addingTimeInterval(900)))
    XCTAssertTrue(snapshot.isStale(at: time.addingTimeInterval(-61)))
  }

  func testStoreInitializationDoesNotRequestWeatherOrPickAnArbitraryCity() async {
    let transport = WeatherQueuedTransport([])
    let defaults = makeDefaults()
    defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
    let store = WeatherStore(client: WeatherClient { try await transport.load($0) }, defaults: defaults)
    await store.loadIfNeeded()
    XCTAssertNil(store.selectedCity)
    XCTAssertNil(store.snapshot)
    let count = await transport.requestCount
    XCTAssertEqual(count, 0)
  }

  func testPersistedSelectionAndFreshWeatherAreRestoredWithoutNetwork() async {
    let transport = WeatherQueuedTransport([.init(data: forecastData(temperature: 23, observedAt: time))])
    let client = WeatherClient { try await transport.load($0) }
    let defaults = makeDefaults()
    defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
    let store = WeatherStore(client: client, defaults: defaults, now: { self.time })
    await store.selectCity(tokyo)
    let restored = WeatherStore(client: client, defaults: defaults, now: { self.time.addingTimeInterval(60) })
    await restored.loadIfNeeded()
    XCTAssertEqual(restored.selectedCity, tokyo)
    XCTAssertEqual(restored.snapshot?.temperature, 23)
    let count = await transport.requestCount
    XCTAssertEqual(count, 1)
  }

  func testFailedRefreshKeepsLastReadingAndShowsError() async {
    let transport = WeatherQueuedTransport([
      .init(data: forecastData(temperature: 23, observedAt: time)),
      .init(data: Data(), status: 503),
    ])
    let defaults = makeDefaults()
    defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
    var now = time
    let store = WeatherStore(client: WeatherClient { try await transport.load($0) }, defaults: defaults, now: { now })
    await store.selectCity(tokyo)
    now = time.addingTimeInterval(901)
    await store.loadIfNeeded()
    XCTAssertEqual(store.snapshot?.temperature, 23)
    XCTAssertEqual(store.snapshot?.fetchedAt, time)
    XCTAssertNotNil(store.errorMessage)
    XCTAssertTrue(store.isStale)
  }

  func testManualRefreshIsThrottledEvenWhenPreviousResponseFailed() async {
    let transport = WeatherQueuedTransport([.init(data: Data(), status: 503)])
    let defaults = makeDefaults()
    defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
    let store = WeatherStore(client: WeatherClient { try await transport.load($0) }, defaults: defaults, now: { self.time })
    await store.selectCity(tokyo)
    await store.refresh()
    let count = await transport.requestCount
    XCTAssertEqual(count, 1)
    XCTAssertNotNil(store.notice)
  }

  func testCachedCitySearchAvoidsRepeatedRequests() async {
    let transport = WeatherQueuedTransport([.init(data: Data("{}".utf8))])
    let defaults = makeDefaults()
    defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
    let store = WeatherStore(client: WeatherClient { try await transport.load($0) }, defaults: defaults, now: { self.time })
    await store.search(query: "Tokyo", language: "en")
    await store.search(query: "Tokyo", language: "en")
    let count = await transport.requestCount
    XCTAssertEqual(count, 1)
    XCTAssertTrue(store.hasSearched)
  }

  func testSwitchingCitiesPreventsAnOlderResponseFromReplacingCurrentWeather() async {
    let transport = WeatherControlledTransport()
    let defaults = makeDefaults()
    defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
    let store = WeatherStore(client: WeatherClient { try await transport.load($0) }, defaults: defaults, now: { self.time })
    let first = Task { await store.selectCity(tokyo) }
    await transport.waitForRequestCount(1)
    let second = Task { await store.selectCity(shanghai) }
    await transport.waitForRequestCount(2)
    await transport.complete(1, with: forecastData(temperature: 19, observedAt: time))
    await second.value
    await transport.complete(0, with: forecastData(temperature: 31, observedAt: time))
    await first.value
    XCTAssertEqual(store.selectedCity, shanghai)
    XCTAssertEqual(store.snapshot?.cityID, shanghai.id)
    XCTAssertEqual(store.snapshot?.temperature, 19)
    XCTAssertFalse(store.isLoading)
  }

  func testSelectingTheLoadingCityDoesNotInvalidateItsPendingResponse() async {
    let transport = WeatherControlledTransport()
    let defaults = makeDefaults()
    defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
    let store = WeatherStore(client: WeatherClient { try await transport.load($0) }, defaults: defaults, now: { self.time })
    let first = Task { await store.selectCity(tokyo) }
    await transport.waitForRequestCount(1)
    let repeatSelection = Task { await store.selectCity(tokyo) }
    await transport.complete(0, with: forecastData(temperature: 23, observedAt: time))
    await first.value
    await repeatSelection.value
    XCTAssertEqual(store.snapshot?.temperature, 23)
    let count = await transport.requestCount
    XCTAssertEqual(count, 1)
  }

  func testReturningToCityAfterCancellingItsRequestCanLoadImmediately() async {
    let transport = WeatherControlledTransport()
    let defaults = makeDefaults()
    defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
    let store = WeatherStore(client: WeatherClient { try await transport.load($0) }, defaults: defaults, now: { self.time })
    let first = Task { await store.selectCity(tokyo) }
    await transport.waitForRequestCount(1)
    let second = Task { await store.selectCity(shanghai) }
    await transport.waitForRequestCount(2)
    let third = Task { await store.selectCity(tokyo) }
    await transport.waitForRequestCount(3)
    await transport.complete(2, with: forecastData(temperature: 23, observedAt: time))
    await third.value
    await transport.complete(0, with: forecastData(temperature: 31, observedAt: time))
    await transport.complete(1, with: forecastData(temperature: 19, observedAt: time))
    await first.value
    await second.value
    XCTAssertEqual(store.selectedCity, tokyo)
    XCTAssertEqual(store.snapshot?.temperature, 23)
    XCTAssertNil(store.notice)
    XCTAssertFalse(store.isLoading)
  }

  func testOlderCitySearchCannotReplaceMoreRecentResults() async {
    let transport = WeatherControlledTransport()
    let defaults = makeDefaults()
    defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
    var now = time
    let store = WeatherStore(client: WeatherClient { try await transport.load($0) }, defaults: defaults, now: { now })
    let first = Task { await store.search(query: "Tokyo") }
    await transport.waitForRequestCount(1)
    now = time.addingTimeInterval(2)
    let second = Task { await store.search(query: "Shanghai") }
    await transport.waitForRequestCount(2)
    await transport.complete(1, with: Data("{\"results\":[{\"id\":2,\"name\":\"Shanghai\",\"latitude\":31.23,\"longitude\":121.47}]}".utf8))
    await second.value
    await transport.complete(0, with: Data("{\"results\":[{\"id\":1,\"name\":\"Tokyo\",\"latitude\":35.68,\"longitude\":139.69}]}".utf8))
    await first.value
    XCTAssertEqual(store.searchResults.map(\.name), ["Shanghai"])
    XCTAssertFalse(store.isSearching)
  }

  func testClosingTheRequestingWindowDoesNotCancelWeatherForAnotherWindow() async {
    let transport = WeatherControlledTransport()
    let defaults = makeDefaults()
    defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
    let store = WeatherStore(client: WeatherClient { try await transport.load($0) }, defaults: defaults, now: { self.time })
    let firstWindow = Task { await store.selectCity(tokyo) }
    await transport.waitForRequestCount(1)
    let secondWindow = Task { await store.loadIfNeeded() }
    firstWindow.cancel()
    await transport.complete(0, with: forecastData(temperature: 23, observedAt: time))
    await secondWindow.value
    await firstWindow.value
    XCTAssertEqual(store.snapshot?.temperature, 23)
    XCTAssertNil(store.errorMessage)
    XCTAssertFalse(store.isLoading)
    let count = await transport.requestCount
    XCTAssertEqual(count, 1)
  }

  func testSavedCitiesSurviveRestartWithoutEvictionOrDuplicates() async {
    let transport = WeatherQueuedTransport((0..<7).map { _ in .init(data: forecastData(temperature: 23, observedAt: time)) })
    let client = WeatherClient { try await transport.load($0) }
    let defaults = makeDefaults()
    defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
    let store = WeatherStore(client: client, defaults: defaults, now: { self.time })
    let cities = (1...7).map {
      WeatherCity(id: $0, name: "City \($0)", latitude: 30, longitude: Double($0), country: nil, admin1: nil, timezone: nil)
    }
    for city in cities { await store.selectCity(city) }
    await store.selectCity(cities[0])
    XCTAssertEqual(store.savedCities, cities)
    let restored = WeatherStore(client: client, defaults: defaults, now: { self.time })
    await restored.loadIfNeeded()
    XCTAssertEqual(restored.savedCities, cities)
    XCTAssertEqual(restored.selectedCity, cities[0])
    XCTAssertEqual(restored.snapshot?.cityID, cities[0].id)
    let count = await transport.requestCount
    XCTAssertEqual(count, 7)
  }

  func testLegacyRecentCitiesMigrateToSavedCitiesWithSelectedCityPreserved() throws {
    let defaults = makeDefaults()
    defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
    struct Legacy: Encodable {
      let selectedCity: WeatherCity
      let recentCities: [WeatherCity]
      let snapshots: [WeatherSnapshot] = []
    }
    defaults.set(try JSONEncoder().encode(Legacy(selectedCity: tokyo, recentCities: [shanghai, shanghai])), forKey: WeatherStore.preferencesKey)
    let store = WeatherStore(defaults: defaults)
    XCTAssertEqual(store.savedCities, [tokyo, shanghai])
    XCTAssertEqual(store.selectedCity, tokyo)
  }

  func testDeletingCitiesSelectsCachedFallbackAndPersistsEmptyState() async {
    let transport = WeatherQueuedTransport([
      .init(data: forecastData(temperature: 23, observedAt: time)),
      .init(data: forecastData(temperature: 19, observedAt: time)),
    ])
    let defaults = makeDefaults()
    defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
    let store = WeatherStore(client: WeatherClient { try await transport.load($0) }, defaults: defaults, now: { self.time })
    await store.selectCity(tokyo)
    await store.selectCity(shanghai)
    await store.removeCity(shanghai)
    XCTAssertEqual(store.selectedCity, tokyo)
    XCTAssertEqual(store.snapshot?.temperature, 23)
    XCTAssertNil(store.cachedWeather(for: shanghai))
    await store.removeCity(tokyo)
    XCTAssertTrue(store.savedCities.isEmpty)
    XCTAssertNil(store.selectedCity)
    XCTAssertNil(store.snapshot)
    let restored = WeatherStore(defaults: defaults)
    XCTAssertTrue(restored.savedCities.isEmpty)
    XCTAssertNil(restored.selectedCity)
    let count = await transport.requestCount
    XCTAssertEqual(count, 2)
  }

  func testRemovingCityWhileItsWeatherLoadsCannotResurrectIt() async {
    let transport = WeatherControlledTransport()
    let defaults = makeDefaults()
    defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
    let store = WeatherStore(client: WeatherClient { try await transport.load($0) }, defaults: defaults, now: { self.time })
    let request = Task { await store.selectCity(tokyo) }
    await transport.waitForRequestCount(1)
    await store.removeCity(tokyo)
    await transport.complete(0, with: forecastData(temperature: 23, observedAt: time))
    await request.value
    XCTAssertTrue(store.savedCities.isEmpty)
    XCTAssertNil(store.selectedCity)
    XCTAssertNil(store.snapshot)
    XCTAssertFalse(store.isLoading)
  }

  func testLocationIsOnlyRequestedByExplicitActionAndFailureKeepsWeather() async {
    let transport = WeatherQueuedTransport([.init(data: forecastData(temperature: 23, observedAt: time))])
    let defaults = makeDefaults()
    defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
    var locationRequests = 0
    let store = WeatherStore(client: WeatherClient { try await transport.load($0) }, defaults: defaults, now: { self.time }, locate: {
      locationRequests += 1
      throw WeatherLocationFailure.denied
    })
    await store.loadIfNeeded()
    await store.selectCity(tokyo)
    XCTAssertEqual(locationRequests, 0)
    await store.useCurrentLocation()
    XCTAssertEqual(locationRequests, 1)
    XCTAssertEqual(store.selectedCity, tokyo)
    XCTAssertEqual(store.snapshot?.temperature, 23)
    XCTAssertEqual(store.savedCities, [tokyo])
    XCTAssertEqual(store.locationErrorMessage, WeatherLocationFailure.denied.localizedDescription)
    XCTAssertFalse(store.isLocating)
  }

  func testMovingCurrentLocationInvalidatesWeatherForPreviousCoordinates() async {
    let transport = WeatherQueuedTransport([
      .init(data: forecastData(temperature: 23, observedAt: time)),
      .init(data: forecastData(temperature: 19, observedAt: time)),
    ])
    let defaults = makeDefaults()
    defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
    var location = WeatherCity(id: WeatherCity.currentLocationID, name: "Tokyo", latitude: 35.68, longitude: 139.69, country: nil, admin1: nil, timezone: nil)
    let store = WeatherStore(client: WeatherClient { try await transport.load($0) }, defaults: defaults, now: { self.time }, locate: { location })
    await store.useCurrentLocation()
    XCTAssertEqual(store.snapshot?.temperature, 23)
    location = WeatherCity(id: WeatherCity.currentLocationID, name: "Shanghai", latitude: 31.23, longitude: 121.47, country: nil, admin1: nil, timezone: nil)
    await store.useCurrentLocation()
    XCTAssertEqual(store.selectedCity, location)
    XCTAssertEqual(store.savedCities, [location])
    XCTAssertEqual(store.snapshot?.temperature, 19)
    let count = await transport.requestCount
    XCTAssertEqual(count, 2)
    var restoredRequests = 0
    let restored = WeatherStore(defaults: defaults, now: { self.time }, locate: { restoredRequests += 1; return location })
    await restored.loadIfNeeded()
    XCTAssertEqual(restored.selectedCity, location)
    XCTAssertEqual(restored.snapshot?.temperature, 19)
    XCTAssertEqual(restoredRequests, 0)
  }

  func testLateLocationDoesNotReplaceManuallySelectedCity() async {
    let transport = WeatherQueuedTransport([.init(data: forecastData(temperature: 23, observedAt: time))])
    let location = WeatherControlledLocation()
    let defaults = makeDefaults()
    defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
    let store = WeatherStore(client: WeatherClient { try await transport.load($0) }, defaults: defaults, now: { self.time }, locate: { try await location.locate() })
    let request = Task { await store.useCurrentLocation() }
    await location.waitForRequest()
    await store.selectCity(tokyo)
    location.complete(WeatherCity(id: WeatherCity.currentLocationID, name: "Shanghai", latitude: 31.23, longitude: 121.47, country: nil, admin1: nil, timezone: nil))
    await request.value
    XCTAssertEqual(store.selectedCity, tokyo)
    XCTAssertEqual(store.savedCities, [tokyo])
    XCTAssertNil(store.locationErrorMessage)
    XCTAssertFalse(store.isLocating)
  }

  func testOverlappingLocationActionsShareOneRequest() async {
    let transport = WeatherQueuedTransport([.init(data: forecastData(temperature: 23, observedAt: time))])
    let location = WeatherControlledLocation()
    let defaults = makeDefaults()
    defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
    let store = WeatherStore(client: WeatherClient { try await transport.load($0) }, defaults: defaults, now: { self.time }, locate: { try await location.locate() })
    let first = Task { await store.useCurrentLocation() }
    await location.waitForRequest()
    let second = Task { await store.useCurrentLocation() }
    await Task.yield()
    location.complete(WeatherCity(id: WeatherCity.currentLocationID, name: "Tokyo", latitude: 35.68, longitude: 139.69, country: nil, admin1: nil, timezone: nil))
    await first.value
    await second.value
    XCTAssertEqual(location.requestCount, 1)
    XCTAssertEqual(store.savedCities.count, 1)
    XCTAssertTrue(store.selectedCity?.isCurrentLocation == true)
    XCTAssertFalse(store.isLocating)
  }

  private func forecastData(temperature: Double, observedAt: Date) -> Data {
    Data("""
      {"timezone":"Asia/Tokyo","current":{"time":\(observedAt.timeIntervalSince1970),"temperature_2m":\(temperature),"apparent_temperature":22,"relative_humidity_2m":65,"wind_speed_10m":8.5,"weather_code":2,"is_day":1},"daily":{"temperature_2m_max":[26],"temperature_2m_min":[18]}}
      """.utf8)
  }

  private nonisolated static func response(_ request: URLRequest, status: Int = 200) -> HTTPURLResponse {
    HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
  }

  private var createdSuites: [ObjectIdentifier: String] = [:]

  private func makeDefaults() -> UserDefaults {
    let suite = "AugmaWeatherTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    createdSuites[ObjectIdentifier(defaults)] = suite
    return defaults
  }

  private func defaultsSuite(_ defaults: UserDefaults) -> String { createdSuites[ObjectIdentifier(defaults)]! }
}

@MainActor
private final class WeatherControlledLocation {
  private var continuation: CheckedContinuation<WeatherCity, Error>?
  private var waiter: CheckedContinuation<Void, Never>?
  private(set) var requestCount = 0

  func locate() async throws -> WeatherCity {
    try await withCheckedThrowingContinuation {
      continuation = $0
      requestCount += 1
      waiter?.resume()
      waiter = nil
    }
  }

  func waitForRequest() async {
    if requestCount > 0 { return }
    await withCheckedContinuation { waiter = $0 }
  }

  func complete(_ city: WeatherCity) {
    continuation?.resume(returning: city)
    continuation = nil
  }
}

private actor WeatherQueuedTransport {
  struct Reply: Sendable {
    let data: Data
    var status = 200
  }
  private var replies: [Reply]
  private(set) var requestCount = 0

  init(_ replies: [Reply]) { self.replies = replies }

  func load(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
    requestCount += 1
    guard !replies.isEmpty else { throw URLError(.badServerResponse) }
    let reply = replies.removeFirst()
    return (reply.data, HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: nil)!)
  }
}

private actor WeatherControlledTransport {
  private var pending: [Int: (URLRequest, CheckedContinuation<(Data, HTTPURLResponse), Error>)] = [:]
  private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []
  private(set) var requestCount = 0

  func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    try await withCheckedThrowingContinuation { continuation in
      pending[requestCount] = (request, continuation)
      requestCount += 1
      let ready = waiters.filter { requestCount >= $0.0 }
      waiters.removeAll { requestCount >= $0.0 }
      for (_, waiter) in ready { waiter.resume() }
    }
  }

  func waitForRequestCount(_ count: Int) async {
    if requestCount >= count { return }
    await withCheckedContinuation { waiters.append((count, $0)) }
  }

  func complete(_ index: Int, with data: Data) {
    let (request, continuation) = pending.removeValue(forKey: index)!
    continuation.resume(returning: (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!))
  }
}
