import Foundation

struct WeatherClient: Sendable {
  typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
  private let transport: Transport

  init(transport: @escaping Transport = { request in
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let response = response as? HTTPURLResponse else { throw WeatherFailure.invalidResponse }
    return (data, response)
  }) {
    self.transport = transport
  }

  func searchCities(_ query: String, language: String = "zh") async throws -> [WeatherCity] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard (2...100).contains(trimmed.count) else { return [] }
    let request = try Self.searchRequest(query: trimmed, language: language)
    let response: GeocodingResponse = try await load(request)
    return (response.results ?? []).filter(\.hasValidCoordinates)
  }

  func weather(for city: WeatherCity, fetchedAt: Date) async throws -> WeatherSnapshot {
    let response: ForecastResponse = try await load(Self.forecastRequest(city: city))
    let current = response.current
    guard TimeZone(identifier: response.timezone) != nil,
          current.temperature.isFinite, current.apparentTemperature.isFinite,
          current.relativeHumidity.isFinite, (0...100).contains(current.relativeHumidity),
          current.windSpeed.isFinite, current.windSpeed >= 0,
          current.time.isFinite else { throw WeatherFailure.invalidResponse }
    return WeatherSnapshot(
      cityID: city.id,
      temperature: current.temperature,
      apparentTemperature: current.apparentTemperature,
      relativeHumidity: current.relativeHumidity,
      windSpeed: current.windSpeed,
      weatherCode: current.weatherCode,
      isDay: current.isDay == 1,
      highTemperature: response.daily?.high.first ?? nil,
      lowTemperature: response.daily?.low.first ?? nil,
      observedAt: Date(timeIntervalSince1970: current.time),
      fetchedAt: fetchedAt,
      timezoneIdentifier: response.timezone
    )
  }

  static func searchRequest(query: String, language: String) throws -> URLRequest {
    try request(host: "geocoding-api.open-meteo.com", path: "/v1/search", query: [
      URLQueryItem(name: "name", value: query),
      URLQueryItem(name: "count", value: "8"),
      URLQueryItem(name: "language", value: language),
      URLQueryItem(name: "format", value: "json"),
    ])
  }

  static func forecastRequest(city: WeatherCity) throws -> URLRequest {
    guard city.hasValidCoordinates else { throw WeatherFailure.invalidResponse }
    return try request(host: "api.open-meteo.com", path: "/v1/forecast", query: [
      URLQueryItem(name: "latitude", value: String(city.latitude)),
      URLQueryItem(name: "longitude", value: String(city.longitude)),
      URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day"),
      URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
      URLQueryItem(name: "forecast_days", value: "1"),
      URLQueryItem(name: "temperature_unit", value: "celsius"),
      URLQueryItem(name: "wind_speed_unit", value: "kmh"),
      URLQueryItem(name: "timeformat", value: "unixtime"),
      URLQueryItem(name: "timezone", value: "auto"),
    ])
  }

  private static func request(host: String, path: String, query: [URLQueryItem]) throws -> URLRequest {
    var components = URLComponents()
    components.scheme = "https"
    components.host = host
    components.path = path
    components.queryItems = query
    guard let url = components.url else { throw WeatherFailure.invalidResponse }
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return request
  }

  private func load<Response: Decodable>(_ request: URLRequest) async throws -> Response {
    let (data, response) = try await transport(request)
    try Task.checkCancellation()
    guard (200..<300).contains(response.statusCode) else { throw WeatherFailure.http(response.statusCode) }
    do { return try JSONDecoder().decode(Response.self, from: data) }
    catch { throw WeatherFailure.invalidResponse }
  }
}

enum WeatherFailure: Error, Equatable, LocalizedError {
  case http(Int)
  case invalidResponse

  var errorDescription: String? {
    switch self {
    case .http(429): String(localized: "天气服务请求过于频繁，请稍后重试。")
    case .http(let status): String(localized: "天气服务暂不可用（HTTP \(status)）。")
    case .invalidResponse: String(localized: "天气服务返回了无法读取的数据。")
    }
  }
}

private struct GeocodingResponse: Decodable { let results: [WeatherCity]? }

private struct ForecastResponse: Decodable {
  let timezone: String
  let current: Current
  let daily: Daily?

  struct Current: Decodable {
    let time: Double
    let temperature: Double
    let apparentTemperature: Double
    let relativeHumidity: Double
    let windSpeed: Double
    let weatherCode: Int
    let isDay: Int

    enum CodingKeys: String, CodingKey {
      case time
      case temperature = "temperature_2m"
      case apparentTemperature = "apparent_temperature"
      case relativeHumidity = "relative_humidity_2m"
      case windSpeed = "wind_speed_10m"
      case weatherCode = "weather_code"
      case isDay = "is_day"
    }
  }

  struct Daily: Decodable {
    let high: [Double?]
    let low: [Double?]

    enum CodingKeys: String, CodingKey {
      case high = "temperature_2m_max"
      case low = "temperature_2m_min"
    }
  }
}
