import Foundation
import MapKit

enum NativeMapEndpoint: String, CaseIterable, Sendable {
  case origin, destination

  var title: String {
    switch self {
    case .origin: String(localized: "起点")
    case .destination: String(localized: "终点")
    }
  }
}

enum NativeMapTransport: String, CaseIterable, Identifiable, Sendable {
  case driving, walking

  var id: String { rawValue }
  var title: String {
    switch self {
    case .driving: String(localized: "驾车")
    case .walking: String(localized: "步行")
    }
  }
  var mapKitType: MKDirectionsTransportType { self == .driving ? .automobile : .walking }
  var mapsLaunchMode: String {
    self == .driving ? MKLaunchOptionsDirectionsModeDriving : MKLaunchOptionsDirectionsModeWalking
  }
}

struct NativeMapCoordinate: Equatable, Sendable {
  let latitude: Double
  let longitude: Double

  var isValid: Bool {
    latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
  }
  var location: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

struct NativeMapPlace: Identifiable, Equatable, Sendable {
  let name: String
  let address: String
  let coordinate: NativeMapCoordinate

  var id: String { "\(coordinate.latitude),\(coordinate.longitude):\(name)" }
  var isValid: Bool { coordinate.isValid && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

  var mapItem: MKMapItem {
    let item: MKMapItem
    if #available(macOS 26, *) {
      item = MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: nil)
    } else {
      item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate.location))
    }
    item.name = name
    return item
  }
}

struct NativeMapStep: Identifiable, Equatable, Sendable {
  let id: Int
  let instruction: String
  let distance: Double
}

struct NativeMapRoute: Equatable, Sendable {
  let name: String
  let distance: Double
  let expectedTravelTime: TimeInterval
  let coordinates: [NativeMapCoordinate]
  let steps: [NativeMapStep]

  var isValid: Bool {
    distance.isFinite && distance >= 0 && expectedTravelTime.isFinite && expectedTravelTime >= 0
      && coordinates.count >= 2 && coordinates.allSatisfy(\.isValid)
  }
  var distanceText: String { Self.distanceText(distance) }
  var durationText: String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = expectedTravelTime >= 3_600 ? [.hour, .minute] : [.minute]
    formatter.unitsStyle = .abbreviated
    return formatter.string(from: max(expectedTravelTime, 60)) ?? "—"
  }
  static func distanceText(_ metres: Double) -> String {
    Measurement(value: metres, unit: UnitLength.meters)
      .formatted(.measurement(width: .abbreviated, usage: .road))
  }
}

enum NativeMapFailure: Error, Equatable {
  case noRoute, serviceUnavailable
}
