import AppKit
import RealityKit
import SwiftUI

struct NativeSpaceCanvas: View {
  @ObservedObject var store: NativeSpaceStore
  @ObservedObject var preferences: NativePreferencesStore

  var body: some View {
    if store.sceneID == .workspace {
      ApplicationDistrictRealityView(space: store, preferences: preferences, district: store.applications)
    } else if store.sceneID == .projects {
      ProjectRegionRealityView(space: store, preferences: preferences, projects: store.projects)
    } else { NativeSpaceRealityView(store: store, preferences: preferences) }
  }
}

struct ApplicationDistrictRealityView: NSViewRepresentable {
  @ObservedObject var space: NativeSpaceStore
  @ObservedObject var preferences: NativePreferencesStore
  @ObservedObject var district: ApplicationDistrictStore

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeNSView(context: Context) -> NativeSpaceRenderView {
    let view = NativeSpaceRenderView(frame: .zero)
    let builder = ApplicationDistrictSceneBuilder()
    view.scene.addAnchor(builder.anchor)
    context.coordinator.builder = builder
    view.setAccessibilityElement(true)
    view.setAccessibilityRole(.image)
    view.setAccessibilityLabel(String(localized: "应用街区；可使用旁边的应用列表打开应用和调整位置。"))
    updateNSView(view, context: context)
    return view
  }

  func updateNSView(_ view: NativeSpaceRenderView, context: Context) {
    view.environment.background = .color(preferences.value.sceneBackdrop
      ? (preferences.value.dark ? NSColor(srgbRed: 0.07, green: 0.12, blue: 0.19, alpha: 1)
         : NSColor(srgbRed: 0.77, green: 0.86, blue: 0.91, alpha: 1)) : .clear)
    context.coordinator.builder?.update(buildings: district.buildings, states: district.states, icons: district.icons,
      selectedID: space.selectedApplicationID ?? district.buildings.first?.id,
      preferences: preferences.value, yaw: space.viewYaw, pitch: space.viewPitch, scale: space.viewScale)
    view.onOpenApplication = { [weak space, weak district] id in
      space?.selectedApplicationID = id
      district?.open(id)
    }
    view.onOrbit = { [weak space, weak coordinator = context.coordinator] dx, dy in
      guard let space else { return }
      space.setView(yaw: space.viewYaw - dx * 0.008, pitch: space.viewPitch + dy * 0.006, scale: space.viewScale)
      coordinator?.builder?.setCamera(yaw: space.viewYaw, pitch: space.viewPitch, scale: space.viewScale)
    }
    view.onZoom = { [weak space, weak coordinator = context.coordinator] amount in
      guard let space else { return }
      space.setView(yaw: space.viewYaw, pitch: space.viewPitch, scale: space.viewScale * exp(amount))
      coordinator?.builder?.setCamera(yaw: space.viewYaw, pitch: space.viewPitch, scale: space.viewScale)
    }
  }

  static func dismantleNSView(_ view: NativeSpaceRenderView, coordinator: Coordinator) {
    view.onOpenApplication = nil
    view.onOrbit = nil
    view.onZoom = nil
    view.scene.anchors.removeAll()
    coordinator.builder = nil
  }

  @MainActor final class Coordinator { var builder: ApplicationDistrictSceneBuilder? }
}
