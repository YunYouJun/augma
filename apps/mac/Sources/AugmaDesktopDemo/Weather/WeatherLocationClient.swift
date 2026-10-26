import CoreLocation
import Foundation

/// A single city-level fix; no background tracking and no manager before the user asks.
@MainActor
final class WeatherLocationClient: NSObject, @MainActor CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private let geocoder = CLGeocoder()
  private var continuation: CheckedContinuation<CLLocation, Error>?
  private var timeoutTask: Task<Void, Never>?
  private var requestedFix = false

  func locate() async throws -> WeatherCity {
    let location = try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        self.continuation = continuation
        guard !Task.isCancelled else { finish(.failure(CancellationError())); return }
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        timeoutTask = Task { [weak self] in
          do { try await Task.sleep(for: .seconds(30)) } catch { return }
          self?.finish(.failure(WeatherLocationFailure.timedOut))
        }
        requestIfAuthorized()
      }
    } onCancel: {
      Task { @MainActor in
        self.finish(.failure(CancellationError()))
        self.geocoder.cancelGeocode()
      }
    }
    try Task.checkCancellation()
    let latitude = (location.coordinate.latitude * 100).rounded() / 100
    let longitude = (location.coordinate.longitude * 100).rounded() / 100
    let approximateLocation = CLLocation(latitude: latitude, longitude: longitude)
    // A place name is optional: a geocoder outage must not prevent coordinate-based weather.
    let place = try? await geocoder.reverseGeocodeLocation(approximateLocation, preferredLocale: .current).first
    try Task.checkCancellation()
    return WeatherCity(
      id: WeatherCity.currentLocationID,
      name: place?.locality ?? place?.subAdministrativeArea ?? String(localized: "当前位置"),
      latitude: latitude,
      longitude: longitude,
      country: place?.country,
      admin1: place?.administrativeArea,
      timezone: place?.timeZone?.identifier
    )
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard continuation != nil else { return }
    requestIfAuthorized()
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last(where: {
      $0.horizontalAccuracy >= 0 && abs($0.timestamp.timeIntervalSinceNow) < 5 * 60
        && CLLocationCoordinate2DIsValid($0.coordinate)
    }) else { finish(.failure(WeatherLocationFailure.unavailable)); return }
    finish(.success(location))
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    finish(.failure((error as? CLError)?.code == .denied ? WeatherLocationFailure.denied : .unavailable))
  }

  private func requestIfAuthorized() {
    switch manager.authorizationStatus {
    case .notDetermined:
      guard CLLocationManager.locationServicesEnabled() else { finish(.failure(WeatherLocationFailure.disabled)); return }
      manager.requestWhenInUseAuthorization()
    case .authorizedAlways, .authorizedWhenInUse:
      guard !requestedFix else { return }
      requestedFix = true
      manager.requestLocation()
    case .denied, .restricted:
      finish(.failure(WeatherLocationFailure.denied))
    @unknown default:
      finish(.failure(WeatherLocationFailure.unavailable))
    }
  }

  private func finish(_ result: Result<CLLocation, Error>) {
    guard let continuation else { return }
    self.continuation = nil
    timeoutTask?.cancel()
    timeoutTask = nil
    manager.stopUpdatingLocation()
    manager.delegate = nil
    continuation.resume(with: result)
  }
}

enum WeatherLocationFailure: Error, LocalizedError {
  case denied, disabled, unavailable, timedOut

  var errorDescription: String? {
    switch self {
    case .denied: String(localized: "定位权限未开启。请在系统设置的“隐私与安全性 → 定位服务”中允许 Augma，或手动添加城市。")
    case .disabled: String(localized: "系统定位服务已关闭。请开启定位服务，或手动添加城市。")
    case .unavailable: String(localized: "暂时无法获取当前位置，请重试或手动添加城市。")
    case .timedOut: String(localized: "获取位置超时，请重试或手动添加城市。")
    }
  }
}
