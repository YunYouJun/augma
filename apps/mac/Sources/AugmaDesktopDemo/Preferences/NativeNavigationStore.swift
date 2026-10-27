import Combine
import Foundation

struct NativePageLocation: Equatable {
  var module: DemoModule
  var spaceScene: NativeSpaceSceneID

  static let workspace = NativePageLocation(module: .space, spaceScene: .workspace)
}

enum NativeStartupMode: String, CaseIterable {
  case resume, home
}

/// App-wide startup preferences. Only the active window updates the next launch location.
@MainActor
final class NativeNavigationStore: ObservableObject {
  @Published var startupMode: NativeStartupMode {
    didSet { defaults.set(startupMode.rawValue, forKey: "augma.navigation.startupMode") }
  }
  @Published var homeModule: DemoModule {
    didSet { defaults.set(homeModule.rawValue, forKey: "augma.navigation.homeModule") }
  }
  @Published var homeSpaceScene: NativeSpaceSceneID {
    didSet { defaults.set(homeSpaceScene.rawValue, forKey: "augma.navigation.homeSpaceScene") }
  }
  private(set) var lastLocation: NativePageLocation?
  private var activeSessionID: UUID?
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    startupMode = defaults.string(forKey: "augma.navigation.startupMode").flatMap(NativeStartupMode.init(rawValue:)) ?? .resume
    homeModule = defaults.string(forKey: "augma.navigation.homeModule").flatMap(DemoModule.init(rawValue:)) ?? .space
    homeSpaceScene = defaults.string(forKey: "augma.navigation.homeSpaceScene").flatMap(NativeSpaceSceneID.init(rawValue:)) ?? .workspace
    if let module = defaults.string(forKey: "augma.navigation.lastModule").flatMap(DemoModule.init(rawValue:)) {
      lastLocation = NativePageLocation(module: module,
        spaceScene: defaults.string(forKey: "augma.navigation.lastSpaceScene").flatMap(NativeSpaceSceneID.init(rawValue:)) ?? .workspace)
    }
  }

  var homeLocation: NativePageLocation { NativePageLocation(module: homeModule, spaceScene: homeSpaceScene) }
  var startupLocation: NativePageLocation { startupMode == .resume ? lastLocation ?? homeLocation : homeLocation }

  func setHome(_ location: NativePageLocation) {
    homeModule = location.module
    homeSpaceScene = location.spaceScene
    startupMode = .home
  }

  func activate(_ sessionID: UUID, location: NativePageLocation) {
    activeSessionID = sessionID
    remember(location, sessionID: sessionID)
  }

  func remember(_ location: NativePageLocation, sessionID: UUID) {
    guard activeSessionID == sessionID, lastLocation != location else { return }
    lastLocation = location
    defaults.set(location.module.rawValue, forKey: "augma.navigation.lastModule")
    defaults.set(location.spaceScene.rawValue, forKey: "augma.navigation.lastSpaceScene")
  }
}
