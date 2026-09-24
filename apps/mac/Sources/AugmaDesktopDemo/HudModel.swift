import Combine
import Foundation

@MainActor
final class HudModel: ObservableObject {
  @Published var wantsDemoScene = false
  @Published var windowVisible = false
  @Published var clickThrough = false
  @Published var immersiveActive = false
  @Published var immersiveClickThrough = false

  var rendersDemoScene: Bool {
    wantsDemoScene && windowVisible
  }

  func leaveDemoScene() {
    wantsDemoScene = false
  }
}
