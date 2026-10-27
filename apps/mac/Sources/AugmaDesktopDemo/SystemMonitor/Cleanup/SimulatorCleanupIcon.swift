import SwiftUI

/// Cleanup only adapts its inventory identity; shared icon policy lives in Icons/.
struct SimulatorCleanupIcon: View {
  let item: SimulatorCleanupItem

  var body: some View {
    let platform = ApplePlatform(runtimeIdentifier: item.runtimeIdentifier)
    let request: AppleIconRequest = item.kind == .runtime ? .platform(platform)
      : .device(modelIdentifier: item.modelIdentifier, simulatorDeviceTypeIdentifier: item.deviceTypeIdentifier, platform: platform)
    AppleIconView(request: request, tint: .augmaCyan).accessibilityHidden(true)
  }
}
