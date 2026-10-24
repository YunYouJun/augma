import Foundation
import MapKit

@MainActor
protocol NativeMapClient: AnyObject {
  func search(query: String, requestID: UUID) async throws -> [NativeMapPlace]
  func route(from origin: NativeMapPlace, to destination: NativeMapPlace, transport: NativeMapTransport, requestID: UUID) async throws -> NativeMapRoute
  func cancelSearch(requestID: UUID)
  func cancelRoute(requestID: UUID)
  func openMaps(from origin: NativeMapPlace, to destination: NativeMapPlace, transport: NativeMapTransport) async -> Bool
}

@MainActor
final class NativeMapKitClient: NativeMapClient {
  private var searches: [UUID: NativeMapPendingRequest<[NativeMapPlace]>] = [:]
  private var directions: [UUID: NativeMapPendingRequest<NativeMapRoute>] = [:]

  func search(query: String, requestID: UUID) async throws -> [NativeMapPlace] {
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = query
    request.resultTypes = [.address, .pointOfInterest]
    let search = MKLocalSearch(request: request)
    defer { searches.removeValue(forKey: requestID) }
    return try await withCheckedThrowingContinuation { continuation in
      let pending = NativeMapPendingRequest(continuation: continuation) { search.cancel() }
      searches[requestID] = pending
      search.start { response, error in
        if let error {
          // A valid search with no matches is an empty state rather than an outage.
          if (error as? MKError)?.code == .placemarkNotFound {
            pending.complete(.success([]))
          } else {
            pending.complete(.failure(error))
          }
          return
        }
        guard let response else {
          pending.complete(.failure(NativeMapFailure.serviceUnavailable))
          return
        }
        var seen = Set<String>()
        let places = response.mapItems.compactMap { item -> NativeMapPlace? in
          let coordinate: CLLocationCoordinate2D
          let address: String
          if #available(macOS 26, *) {
            coordinate = item.location.coordinate
            address = item.address?.fullAddress ?? ""
          } else {
            coordinate = item.placemark.coordinate
            address = item.placemark.title ?? ""
          }
          let place = NativeMapPlace(
            name: item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            address: address,
            coordinate: NativeMapCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
          )
          return place.isValid && seen.insert(place.id).inserted ? place : nil
        }
        pending.complete(.success(Array(places.prefix(8))))
      }
    }
  }

  func route(from origin: NativeMapPlace, to destination: NativeMapPlace, transport: NativeMapTransport, requestID: UUID) async throws -> NativeMapRoute {
    let request = MKDirections.Request()
    request.source = origin.mapItem
    request.destination = destination.mapItem
    request.transportType = transport.mapKitType
    request.requestsAlternateRoutes = false
    let operation = MKDirections(request: request)
    defer { directions.removeValue(forKey: requestID) }
    return try await withCheckedThrowingContinuation { continuation in
      let pending = NativeMapPendingRequest(continuation: continuation) { operation.cancel() }
      directions[requestID] = pending
      operation.calculate(completionHandler: Self.directionsHandler { pending.complete($0) })
    }
  }

  func cancelSearch(requestID: UUID) { searches[requestID]?.cancel() }
  func cancelRoute(requestID: UUID) { directions[requestID]?.cancel() }

  func openMaps(from origin: NativeMapPlace, to destination: NativeMapPlace, transport: NativeMapTransport) async -> Bool {
    await withCheckedContinuation { continuation in
      MKMapItem.openMaps(with: [origin.mapItem, destination.mapItem], launchOptions: [MKLaunchOptionsDirectionsModeKey: transport.mapsLaunchMode], completionHandler: Self.mapsLaunchHandler(continuation))
    }
  }

  /// Construct the callback outside MainActor isolation so MapKit can invoke it on
  /// any queue. Only a Sendable value snapshot crosses back to the store's actor.
  nonisolated static func directionsHandler(_ complete: @escaping @MainActor @Sendable (Result<NativeMapRoute, Error>) -> Void) -> @Sendable (MKDirections.Response?, (any Error)?) -> Void {
    { response, error in
      let result: Result<NativeMapRoute, Error>
      if let error {
        result = .failure(error)
      } else if let route = response?.routes.first {
        var coordinates = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: route.polyline.pointCount)
        route.polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: coordinates.count))
        let snapshot = NativeMapRoute(
          name: route.name,
          distance: route.distance,
          expectedTravelTime: route.expectedTravelTime,
          coordinates: coordinates.map { NativeMapCoordinate(latitude: $0.latitude, longitude: $0.longitude) },
          steps: route.steps.enumerated().compactMap { index, step in
            let instruction = step.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !instruction.isEmpty, step.distance.isFinite, step.distance >= 0 else { return nil }
            return NativeMapStep(id: index, instruction: instruction, distance: step.distance)
          }
        )
        result = snapshot.isValid ? .success(snapshot) : .failure(NativeMapFailure.noRoute)
      } else {
        result = .failure(NativeMapFailure.noRoute)
      }
      Task { @MainActor in complete(result) }
    }
  }

  nonisolated private static func mapsLaunchHandler(_ continuation: CheckedContinuation<Bool, Never>) -> @Sendable (Bool) -> Void {
    { success in continuation.resume(returning: success) }
  }
}

/// Resolves cancellation and deadlines even if MapKit never sends its completion.
/// Late callbacks are harmless, and releasing the native operation breaks its callback cycle.
@MainActor
private final class NativeMapPendingRequest<Value: Sendable> {
  private var continuation: CheckedContinuation<Value, Error>?
  private var cancelNative: (() -> Void)?
  private var deadline: Task<Void, Never>?

  init(continuation: CheckedContinuation<Value, Error>, cancelNative: @escaping () -> Void) {
    self.continuation = continuation
    self.cancelNative = cancelNative
    deadline = Task { [weak self] in
      do { try await Task.sleep(for: .seconds(20)) } catch { return }
      self?.finishAndCancel(.failure(URLError(.timedOut)))
    }
  }

  func complete(_ result: Result<Value, Error>) {
    guard let continuation else { return }
    self.continuation = nil
    deadline?.cancel()
    deadline = nil
    cancelNative = nil
    continuation.resume(with: result)
  }

  func cancel() { finishAndCancel(.failure(CancellationError())) }

  private func finishAndCancel(_ result: Result<Value, Error>) {
    let cancel = cancelNative
    complete(result)
    cancel?()
  }
}
