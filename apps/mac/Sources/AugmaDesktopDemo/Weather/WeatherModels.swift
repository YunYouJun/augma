import Foundation

struct WeatherCity: Codable, Equatable, Hashable, Identifiable, Sendable {
  /// GeoNames identifiers are positive; the device location has a stable, separate identity.
  static let currentLocationID = -1

  let id: Int
  let name: String
  let latitude: Double
  let longitude: Double
  let country: String?
  let admin1: String?
  let timezone: String?

  var isCurrentLocation: Bool { id == Self.currentLocationID }

  var regionDescription: String {
    [admin1, country].compactMap { $0 }.filter { !$0.isEmpty && $0 != name }.joined(separator: " · ")
  }

  var hasValidCoordinates: Bool {
    latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
  }
}

struct WeatherSnapshot: Codable, Equatable, Sendable {
  static let cacheLifetime: TimeInterval = 15 * 60

  let cityID: Int
  let temperature: Double
  let apparentTemperature: Double
  let relativeHumidity: Double
  let windSpeed: Double
  let weatherCode: Int
  let isDay: Bool
  let highTemperature: Double?
  let lowTemperature: Double?
  let observedAt: Date
  let fetchedAt: Date
  let timezoneIdentifier: String

  var timeZone: TimeZone { TimeZone(identifier: timezoneIdentifier) ?? TimeZone(secondsFromGMT: 0)! }

  func isStale(at date: Date) -> Bool {
    let cacheAge = date.timeIntervalSince(fetchedAt)
    let observationAge = date.timeIntervalSince(observedAt)
    return cacheAge >= Self.cacheLifetime || cacheAge < -60 || observationAge >= 60 * 60 || observationAge < -15 * 60
  }

  var condition: WeatherCondition { WeatherCondition(code: weatherCode, isDay: isDay) }
}

struct WeatherCondition {
  let description: String
  let symbol: String

  init(code: Int, isDay: Bool) {
    switch code {
    case 0:
      description = String(localized: "晴")
      symbol = isDay ? "sun.max.fill" : "moon.stars.fill"
    case 1, 2:
      description = String(localized: "局部多云")
      symbol = isDay ? "cloud.sun.fill" : "cloud.moon.fill"
    case 3:
      description = String(localized: "阴")
      symbol = "cloud.fill"
    case 45, 48:
      description = String(localized: "雾")
      symbol = "cloud.fog.fill"
    case 51, 53, 55, 56, 57:
      description = String(localized: "毛毛雨")
      symbol = "cloud.drizzle.fill"
    case 61, 63, 65, 66, 67, 80, 81, 82:
      description = String(localized: "雨")
      symbol = "cloud.rain.fill"
    case 71, 73, 75, 77, 85, 86:
      description = String(localized: "雪")
      symbol = "cloud.snow.fill"
    case 95, 96, 99:
      description = String(localized: "雷雨")
      symbol = "cloud.bolt.rain.fill"
    default:
      description = String(localized: "天气状况未知")
      symbol = "cloud"
    }
  }
}
