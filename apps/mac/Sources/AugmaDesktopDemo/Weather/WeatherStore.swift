import Combine
import Foundation

@MainActor
final class WeatherStore: ObservableObject {
  static let preferencesKey = "augma.nativeWeather.v1"
  static let minimumRefreshInterval: TimeInterval = 60

  @Published private(set) var selectedCity: WeatherCity?
  @Published private(set) var savedCities: [WeatherCity] = []
  @Published private(set) var snapshot: WeatherSnapshot?
  @Published private(set) var searchResults: [WeatherCity] = []
  @Published private(set) var isLoading = false
  @Published private(set) var isSearching = false
  @Published private(set) var hasSearched = false
  @Published private(set) var errorMessage: String?
  @Published private(set) var searchErrorMessage: String?
  @Published private(set) var notice: String?
  @Published private(set) var isLocating = false
  @Published private(set) var locationErrorMessage: String?

  private let client: WeatherClient
  private let defaults: UserDefaults
  private let now: () -> Date
  private let locate: @MainActor () async throws -> WeatherCity
  private var snapshots: [Int: WeatherSnapshot] = [:]
  private var searchCache: [String: (date: Date, cities: [WeatherCity])] = [:]
  private var lastWeatherAttempt: [Int: Date] = [:]
  private var lastSearchAttempt: Date?
  private var weatherGeneration = UUID()
  private var searchGeneration = UUID()
  private var weatherTask: Task<Void, Never>?
  private var locationTask: Task<Void, Never>?
  private var locationGeneration = UUID()

  init(client: WeatherClient = WeatherClient(), defaults: UserDefaults = .standard,
       now: @escaping () -> Date = { Date() },
       locate: @escaping @MainActor () async throws -> WeatherCity = { try await WeatherLocationClient().locate() }) {
    self.client = client
    self.defaults = defaults
    self.now = now
    self.locate = locate
    if let data = defaults.data(forKey: Self.preferencesKey),
       let saved = try? JSONDecoder().decode(SavedWeather.self, from: data) {
      var seen = Set<Int>()
      savedCities = saved.savedCities.filter { $0.hasValidCoordinates && seen.insert($0.id).inserted }
      selectedCity = saved.selectedCity.flatMap { $0.hasValidCoordinates ? $0 : nil }
      if let selectedCity, !savedCities.contains(where: { $0.id == selectedCity.id }) { savedCities.insert(selectedCity, at: 0) }
      for snapshot in saved.snapshots where savedCities.contains(where: { $0.id == snapshot.cityID }) {
        snapshots[snapshot.cityID] = snapshot
      }
      snapshot = selectedCity.flatMap { snapshots[$0.id] }
    }
  }

  var isStale: Bool { snapshot?.isStale(at: now()) ?? false }

  func loadIfNeeded() async {
    guard let city = selectedCity else { return }
    if let weatherTask, isLoading {
      await weatherTask.value
      return
    }
    if let cached = snapshots[city.id], !cached.isStale(at: now()) {
      snapshot = cached
      return
    }
    await fetchWeather(for: city)
  }

  func selectCity(_ city: WeatherCity) async {
    guard city.hasValidCoordinates else { return }
    cancelLocationRequest()
    locationErrorMessage = nil
    await activateCity(city)
  }

  private func activateCity(_ city: WeatherCity) async {
    if selectedCity == city {
      await loadIfNeeded()
      return
    }
    // A new device fix can reuse the location identity with different coordinates.
    if let previous = savedCities.first(where: { $0.id == city.id }),
       previous.latitude != city.latitude || previous.longitude != city.longitude {
      snapshots.removeValue(forKey: city.id)
      lastWeatherAttempt.removeValue(forKey: city.id)
    }
    cancelWeatherRequest()
    searchGeneration = UUID()
    isSearching = false
    selectedCity = city
    snapshot = snapshots[city.id]
    errorMessage = nil
    notice = nil
    searchResults = []
    searchErrorMessage = nil
    hasSearched = false
    if let index = savedCities.firstIndex(where: { $0.id == city.id }) {
      savedCities[index] = city
    } else {
      savedCities.append(city)
    }
    persist()
    await loadIfNeeded()
  }

  func removeCity(_ city: WeatherCity) async {
    guard savedCities.contains(where: { $0.id == city.id }) else { return }
    cancelLocationRequest()
    savedCities.removeAll { $0.id == city.id }
    snapshots.removeValue(forKey: city.id)
    lastWeatherAttempt.removeValue(forKey: city.id)
    if selectedCity?.id == city.id {
      cancelWeatherRequest()
      selectedCity = nil
      snapshot = nil
      errorMessage = nil
      notice = nil
      if let next = savedCities.first { await activateCity(next) }
    }
    persist()
  }

  func cachedWeather(for city: WeatherCity) -> WeatherSnapshot? { snapshots[city.id] }

  /// Location access only starts in response to the user's location action.
  func useCurrentLocation() async {
    if let locationTask, isLocating { await locationTask.value; return }
    let generation = UUID()
    locationGeneration = generation
    locationErrorMessage = nil
    isLocating = true
    let task = Task { [self] in
      defer {
        if locationGeneration == generation { isLocating = false; locationTask = nil }
      }
      do {
        let city = try await locate()
        guard !Task.isCancelled, locationGeneration == generation else { return }
        guard city.isCurrentLocation, city.hasValidCoordinates else { throw WeatherLocationFailure.unavailable }
        await activateCity(city)
      } catch {
        guard !Task.isCancelled, locationGeneration == generation, !Self.isCancellation(error) else { return }
        locationErrorMessage = (error as? WeatherLocationFailure)?.localizedDescription
          ?? WeatherLocationFailure.unavailable.localizedDescription
      }
    }
    locationTask = task
    await task.value
  }

  func refresh() async {
    guard let city = selectedCity else { return }
    if let weatherTask, isLoading {
      await weatherTask.value
      return
    }
    await fetchWeather(for: city)
  }

  func search(query: String, language: String? = nil) async {
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    searchGeneration = UUID()
    let generation = searchGeneration
    isSearching = false
    searchResults = []
    searchErrorMessage = nil
    hasSearched = false
    guard (2...100).contains(query.count) else {
      searchErrorMessage = String(localized: "请输入 2 至 100 个字符的城市名称。")
      return
    }
    let language = language ?? Locale.current.language.languageCode?.identifier ?? "en"
    let cacheKey = "\(language):\(query.lowercased())"
    if let cached = searchCache[cacheKey], (0..<WeatherSnapshot.cacheLifetime).contains(now().timeIntervalSince(cached.date)) {
      searchResults = cached.cities
      hasSearched = true
      return
    }
    if let lastSearchAttempt, now().timeIntervalSince(lastSearchAttempt) < 1 {
      searchErrorMessage = String(localized: "搜索过于频繁，请稍后重试。")
      return
    }
    lastSearchAttempt = now()
    isSearching = true
    defer { if searchGeneration == generation { isSearching = false } }
    do {
      let cities = try await client.searchCities(query, language: language)
      guard !Task.isCancelled, searchGeneration == generation else { return }
      searchCache[cacheKey] = (now(), cities)
      if searchCache.count > 20 { searchCache.removeValue(forKey: searchCache.min(by: { $0.value.date < $1.value.date })!.key) }
      searchResults = cities
      hasSearched = true
    } catch {
      guard !Task.isCancelled, searchGeneration == generation, !Self.isCancellation(error) else { return }
      searchErrorMessage = Self.message(for: error)
    }
  }

  /// Explicitly cancels shared work. Individual windows must not call this on disappearance.
  func cancelRequests() {
    cancelLocationRequest()
    cancelWeatherRequest()
    searchGeneration = UUID()
    isSearching = false
  }

  private func cancelWeatherRequest() {
    if isLoading, let cityID = selectedCity?.id { lastWeatherAttempt.removeValue(forKey: cityID) }
    weatherTask?.cancel()
    weatherTask = nil
    weatherGeneration = UUID()
    isLoading = false
  }

  private func cancelLocationRequest() {
    locationGeneration = UUID()
    locationTask?.cancel()
    locationTask = nil
    isLocating = false
  }

  private func fetchWeather(for city: WeatherCity) async {
    if let lastAttempt = lastWeatherAttempt[city.id], now().timeIntervalSince(lastAttempt) < Self.minimumRefreshInterval {
      notice = String(localized: "每分钟最多刷新一次，请稍后重试。")
      return
    }
    lastWeatherAttempt[city.id] = now()
    let generation = UUID()
    weatherGeneration = generation
    isLoading = true
    errorMessage = nil
    notice = nil
    // This unstructured task belongs to the store, so cancelling a window's `.task`
    // cannot abort a request that another window is awaiting. Requests time out after 15s.
    let task = Task { [self] in
      defer {
        if weatherGeneration == generation {
          isLoading = false
          weatherTask = nil
        }
      }
      do {
        let updated = try await client.weather(for: city, fetchedAt: now())
        guard !Task.isCancelled, weatherGeneration == generation, selectedCity?.id == city.id else { return }
        snapshots[city.id] = updated
        snapshot = updated
        persist()
      } catch {
        guard weatherGeneration == generation, selectedCity?.id == city.id else { return }
        if Task.isCancelled || Self.isCancellation(error) {
          lastWeatherAttempt.removeValue(forKey: city.id)
          return
        }
        errorMessage = Self.message(for: error)
      }
    }
    weatherTask = task
    await task.value
  }

  private func persist() {
    let savedIDs = Set(savedCities.map(\.id))
    snapshots = snapshots.filter { savedIDs.contains($0.key) }
    let saved = SavedWeather(selectedCity: selectedCity, savedCities: savedCities, snapshots: Array(snapshots.values))
    if let data = try? JSONEncoder().encode(saved) { defaults.set(data, forKey: Self.preferencesKey) }
  }

  private static func isCancellation(_ error: Error) -> Bool {
    error is CancellationError || (error as? URLError)?.code == .cancelled
  }

  private static func message(for error: Error) -> String {
    if let failure = error as? WeatherFailure { return failure.localizedDescription }
    if (error as? URLError)?.code == .timedOut { return String(localized: "天气请求超时，请检查网络后重试。") }
    return String(localized: "无法连接天气服务，请检查网络后重试。")
  }
}

private struct SavedWeather: Codable {
  let selectedCity: WeatherCity?
  let savedCities: [WeatherCity]
  let snapshots: [WeatherSnapshot]

  init(selectedCity: WeatherCity?, savedCities: [WeatherCity], snapshots: [WeatherSnapshot]) {
    self.selectedCity = selectedCity
    self.savedCities = savedCities
    self.snapshots = snapshots
  }

  private enum CodingKeys: String, CodingKey { case selectedCity, savedCities, recentCities, snapshots }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    selectedCity = try values.decodeIfPresent(WeatherCity.self, forKey: .selectedCity)
    savedCities = try values.decodeIfPresent([WeatherCity].self, forKey: .savedCities)
      ?? values.decodeIfPresent([WeatherCity].self, forKey: .recentCities) ?? []
    snapshots = try values.decodeIfPresent([WeatherSnapshot].self, forKey: .snapshots) ?? []
  }

  func encode(to encoder: Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encodeIfPresent(selectedCity, forKey: .selectedCity)
    try values.encode(savedCities, forKey: .savedCities)
    try values.encode(snapshots, forKey: .snapshots)
  }
}
