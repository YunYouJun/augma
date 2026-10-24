import AppKit
import RealityKit
import SwiftUI

struct ProjectRegionRealityView: NSViewRepresentable {
  @ObservedObject var space: NativeSpaceStore
  @ObservedObject var preferences: NativePreferencesStore
  @ObservedObject var projects: ProjectWorkspaceStore
  func makeCoordinator() -> Coordinator { Coordinator() }
  func makeNSView(context: Context) -> NativeSpaceRenderView {
    let view = NativeSpaceRenderView(frame: .zero)
    let builder = ProjectRegionSceneBuilder(); context.coordinator.builder = builder
    view.scene.addAnchor(builder.anchor)
    view.setAccessibilityElement(true); view.setAccessibilityRole(.image)
    view.setAccessibilityLabel(String(localized: "项目区域；点击区域查看入口，使用旁边的打开工作区按钮启动。"))
    updateNSView(view, context: context)
    return view
  }
  func updateNSView(_ view: NativeSpaceRenderView, context: Context) {
    view.environment.background = .color(preferences.value.sceneBackdrop
      ? (preferences.value.dark ? NSColor(srgbRed: 0.07, green: 0.12, blue: 0.19, alpha: 1) : NSColor(srgbRed: 0.77, green: 0.86, blue: 0.91, alpha: 1)) : .clear)
    let selected = projects.regions.first { $0.id == space.selectedProjectID } ?? projects.regions.first
    context.coordinator.builder?.update(projects.regions, selectedID: selected?.id,
      preferences: preferences.value, yaw: space.viewYaw, pitch: space.viewPitch, scale: space.viewScale)
    view.onSelectProject = { [weak space] in space?.selectedProjectID = $0 }
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
    view.onSelectProject = nil; view.onOrbit = nil; view.onZoom = nil
    view.scene.anchors.removeAll(); coordinator.builder = nil
  }
  @MainActor final class Coordinator { var builder: ProjectRegionSceneBuilder? }
}
