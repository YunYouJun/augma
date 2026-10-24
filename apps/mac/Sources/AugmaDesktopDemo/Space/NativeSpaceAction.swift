import Foundation

/// The remaining demo bridge can request only these native spatial operations.
enum NativeSpaceAction: Equatable {
  case scan, cancelScan, pin, routeStart, routeNext, routeStop, resetView
  case scene(NativeSpaceSceneID), landmark(String)

  static func decode(_ action: String, value: Any? = nil) -> Self? {
    switch action {
    case "scan": .scan
    case "cancelScan": .cancelScan
    case "pin": .pin
    case "routeStart": .routeStart
    case "routeNext": .routeNext
    case "routeStop": .routeStop
    case "resetView": .resetView
    case "scene": (value as? String).flatMap(NativeSpaceSceneID.init(rawValue:)).map(Self.scene)
    case "landmark": (value as? String).flatMap { id in
      ["terrace", "pavilion", "tree", "gallery", "station", "square"].contains(id) ? .landmark(id) : nil
    }
    default: nil
    }
  }
}

extension NativeSpaceStore {
  func perform(_ action: NativeSpaceAction) {
    switch action {
    case .scan: scan()
    case .cancelScan: cancelScan()
    case .pin: togglePin()
    case .routeStart: startRoute()
    case .routeNext: advanceRoute()
    case .routeStop: cancelRoute()
    case .resetView: resetView()
    case .scene(let id): selectScene(id)
    case .landmark(let id): selectLandmark(id)
    }
  }
}
