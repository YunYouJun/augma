import Combine
import Foundation

@MainActor
final class WeatherStore: ObservableObject {
  static let preferencesKey = "augma.nativeWeather.v1"
  static let minimumRefreshInterval: TimeInterval = 60

  @Published private(set) var selectedCity: WeatherCity?
  @Published private(set) var recentCities: [WeatherCity] = []
  @Published private(set) var snapshot: WeatherSnapshot?
  @Published private(set) var searchResults: [WeatherCity] = []
  @Published private(set) var isLoading = false
  @Published private(set) var isSearching = false
  @Published private(set) var hasSearched = false
  @Published private(set) var errorMessage: String?
  @Published private(set) var searchErrorMessage: String?
  @Published private(set) var notice: String?

  private let client: WeatherClient
  private let defaults: UserDefaults
  private let now: () -> Date
  private var snapshots: [Int: WeatherSnapshot] = [:]
  private var searchCache: [String: (date: Date, cities: [WeatherCity])] = [:]
  private var lastWeatherAttempt: [Int: Date] = [:]
  private var lastSearchAttempt: Date?
  private var weatherGeneration = UUID()
  private var searchGeneration = UUID()
  private var weatherTask: Task<Void, Never>?

  init(client: WeatherClient = WeatherClient(), defaults: UserDefaults = .standard, now: @escaping () -> Date = { Date() }) {
    self.client = client
    self.defaults = defaults
    self.now = now
    if let data = defaults.data(forKey: Self.preferencesKey),
       let saved = try? JSONDecoder().decode(SavedWeather.self, from: data) {
      recentCities = Array(saved.recentCities.filter(\.hasValidCoordinates).prefix(5))
      selectedCity = saved.selectedCity.flatMap { $0.hasValidCoordinates ? $0 : nil }
      for snapshot in saved.snapshots where recentCities.contains(where: { $0.id == snapshot.cityID }) {
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
    if selectedCity?.id == city.id {
      await loadIfNeeded()
      return
    }
    weatherTask?.cancel()
    weatherTask = nil
    weatherGeneration = UUID()
    searchGeneration = UUID()
    isLoading = false
    isSearching = false
    selectedCity = city
    snapshot = snapshots[city.id]
    errorMessage = nil
    notice = nil
    searchResults = []
    searchErrorMessage = nil
    hasSearched = false
    recentCities.removeAll { $0.id == city.id }
    recentCities.insert(city, at: 0)
    recentCities = Array(recentCities.prefix(5))
    persist()
    await loadIfNeeded()
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
    if isLoading, let cityID = selectedCity?.id { lastWeatherAttempt.removeValue(forKey: cityID) }
    weatherTask?.cancel()
    weatherTask = nil
    weatherGeneration = UUID()
    searchGeneration = UUID()
    isLoading = false
    isSearching = false
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
    let recentIDs = Set(recentCities.map(\.id))
    snapshots = snapshots.filter { recentIDs.contains($0.key) }
    let saved = SavedWeather(selectedCity: selectedCity, recentCities: recentCities, snapshots: Array(snapshots.values))
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
  let recentCities: [WeatherCity]
  let snapshots: [WeatherSnapshot]
}
