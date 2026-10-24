import AppKit
import RealityKit
import SwiftUI

/// macOS ARView is a non-AR renderer. This narrow bridge adds an explicit camera,
/// pointer hit testing, and desktop orbit controls while SwiftUI owns all state.
struct NativeSpaceRealityView: NSViewRepresentable {
  @ObservedObject var store: NativeSpaceStore
  @ObservedObject var preferences: NativePreferencesStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeNSView(context: Context) -> NativeSpaceRenderView {
    let view = NativeSpaceRenderView(frame: .zero)
    view.setAccessibilityElement(true)
    view.setAccessibilityRole(.image)
    context.coordinator.update(view: view, store: store, preferences: preferences.value, reduceMotion: reduceMotion, active: scenePhase == .active)
    return view
  }

  func updateNSView(_ view: NativeSpaceRenderView, context: Context) {
    context.coordinator.update(view: view, store: store, preferences: preferences.value, reduceMotion: reduceMotion, active: scenePhase == .active)
  }

  static func dismantleNSView(_ view: NativeSpaceRenderView, coordinator: Coordinator) {
    view.onSelect = nil
    view.onOrbit = nil
    view.onZoom = nil
    view.onPointer = nil
    view.onVisibilityChanged = nil
    coordinator.builder?.stopAmbientMotion()
    view.scene.anchors.removeAll()
    coordinator.builder = nil
    coordinator.sceneID = nil
  }

  @MainActor
  final class Coordinator {
    var builder: NativeSpaceSceneBuilder?
    var sceneID: NativeSpaceSceneID?
    private weak var store: NativeSpaceStore?
    private var pointer: SIMD2<Float> = .zero
    private var allowsParallax = false
    private var allowsAmbientMotion = false

    func update(view: NativeSpaceRenderView, store: NativeSpaceStore, preferences: NativeScenePreferences, reduceMotion: Bool, active: Bool) {
      self.store = store
      if sceneID != store.sceneID {
        builder?.stopAmbientMotion()
        view.scene.anchors.removeAll()
        let newBuilder = NativeSpaceSceneBuilder(scene: store.scene)
        view.scene.addAnchor(newBuilder.anchor)
        builder = newBuilder
        sceneID = store.sceneID
      }
      allowsParallax = preferences.depthMotion && !reduceMotion
      if !allowsParallax { pointer = .zero }
      view.tracksPointer = allowsParallax
      view.environment.background = .color(
        preferences.sceneBackdrop
          ? (store.sceneID == .garden
            ? NSColor(srgbRed: preferences.dark ? 0.12 : 0.68,
                      green: preferences.dark ? 0.20 : 0.84,
                      blue: preferences.dark ? 0.28 : 0.91, alpha: 1)
            : NSColor(srgbRed: preferences.dark ? 0.035 : 0.91,
                      green: preferences.dark ? 0.075 : 0.95,
                      blue: preferences.dark ? 0.085 : 0.93, alpha: 1))
          : .clear
      )
      builder?.update(selectedID: store.selectedID, pinnedID: store.pinnedLandmarkID,
                      scanning: store.scanning, progress: store.scanProgress,
                      routeStep: store.routeStep, preferences: preferences)
      allowsAmbientMotion = active && !reduceMotion && preferences.sceneBackdrop && !preferences.focus
      builder?.setAmbientMotionEnabled(allowsAmbientMotion && view.isSceneVisible)
      view.onVisibilityChanged = { [weak self] visible in
        guard let self else { return }
        self.builder?.setAmbientMotionEnabled(visible && self.allowsAmbientMotion)
      }
      updateCamera()
      view.setAccessibilityLabel(store.scene.title(locale: preferences.locale))
      view.onSelect = { [weak store] id in store?.selectLandmark(id) }
      view.onOrbit = { [weak self, weak store] dx, dy in
        guard let store else { return }
        store.setView(yaw: store.viewYaw - dx * 0.008,
                      pitch: store.viewPitch + dy * 0.006,
                      scale: store.viewScale)
        self?.updateCamera()
      }
      view.onZoom = { [weak self, weak store] amount in
        guard let store else { return }
        store.setView(yaw: store.viewYaw, pitch: store.viewPitch, scale: store.viewScale * exp(amount))
        self?.updateCamera()
      }
      view.onPointer = { [weak self] point in
        guard let self, self.allowsParallax else { return }
        self.pointer = point * 0.035
        self.updateCamera()
      }
    }

    private func updateCamera() {
      guard let store else { return }
      builder?.setCamera(yaw: store.viewYaw, pitch: store.viewPitch, scale: store.viewScale, parallax: pointer)
    }
  }
}

/// No recognizer competes with SwiftUI's surrounding controls. The view consumes
/// only gestures inside the 3D canvas; accessible controls provide equivalents.
@MainActor
final class NativeSpaceRenderView: ARView {
  var onSelect: ((String) -> Void)?
  var onOpenApplication: ((String) -> Void)?
  var onSelectProject: ((UUID) -> Void)?
  var onOrbit: ((Double, Double) -> Void)?
  var onZoom: ((Double) -> Void)?
  var onPointer: ((SIMD2<Float>) -> Void)?
  var onVisibilityChanged: ((Bool) -> Void)?
  var isSceneVisible: Bool {
    window?.occlusionState.contains(.visible) == true && !isHiddenOrHasHiddenAncestor
  }
  var tracksPointer = false {
    didSet { if tracksPointer != oldValue { updateTrackingAreas() } }
  }
  private var pressPoint: NSPoint?
  private var dragDistance: CGFloat = 0
  private var tracking: NSTrackingArea?

  override var acceptsFirstResponder: Bool { true }
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override func viewWillMove(toWindow newWindow: NSWindow?) {
    if let window {
      NotificationCenter.default.removeObserver(self, name: NSWindow.didChangeOcclusionStateNotification, object: window)
    }
    super.viewWillMove(toWindow: newWindow)
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if let window {
      NotificationCenter.default.addObserver(self, selector: #selector(refreshVisibility),
                                            name: NSWindow.didChangeOcclusionStateNotification, object: window)
    }
    refreshVisibility()
  }

  override func viewDidHide() { super.viewDidHide(); refreshVisibility() }
  override func viewDidUnhide() { super.viewDidUnhide(); refreshVisibility() }

  @objc private func refreshVisibility() { onVisibilityChanged?(isSceneVisible) }

  override func mouseDown(with event: NSEvent) {
    window?.makeFirstResponder(self)
    pressPoint = convert(event.locationInWindow, from: nil)
    dragDistance = 0
  }

  override func mouseDragged(with event: NSEvent) {
    let dx = event.deltaX
    let dy = event.deltaY
    dragDistance += abs(dx) + abs(dy)
    onOrbit?(Double(dx), Double(dy))
  }

  override func mouseUp(with event: NSEvent) {
    defer { pressPoint = nil; dragDistance = 0 }
    guard pressPoint != nil, dragDistance < 5 else { return }
    let point = convert(event.locationInWindow, from: nil)
    var hit = entity(at: point)
    while let candidate = hit {
      if candidate.name.hasPrefix("project:"), let id = UUID(uuidString: String(candidate.name.dropFirst("project:".count))) {
        onSelectProject?(id)
        return
      }
      if candidate.name.hasPrefix("application:") {
        onOpenApplication?(String(candidate.name.dropFirst("application:".count)))
        return
      }
      if candidate.name.hasPrefix("landmark:") {
        onSelect?(String(candidate.name.dropFirst("landmark:".count)))
        return
      }
      hit = candidate.parent
    }
  }

  override func scrollWheel(with event: NSEvent) {
    let multiplier = event.hasPreciseScrollingDeltas ? 0.003 : 0.045
    onZoom?(Double(event.scrollingDeltaY) * multiplier)
  }

  override func magnify(with event: NSEvent) { onZoom?(Double(event.magnification)) }

  override func updateTrackingAreas() {
    if let tracking { removeTrackingArea(tracking) }
    tracking = nil
    if tracksPointer {
      let area = NSTrackingArea(rect: .zero, options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited], owner: self)
      addTrackingArea(area)
      tracking = area
    }
    super.updateTrackingAreas()
  }

  override func mouseMoved(with event: NSEvent) {
    guard tracksPointer, bounds.width > 0, bounds.height > 0 else { return }
    let point = convert(event.locationInWindow, from: nil)
    onPointer?([Float((point.x / bounds.width - 0.5) * 2), Float((point.y / bounds.height - 0.5) * 2)])
  }

  override func mouseExited(with event: NSEvent) { onPointer?(.zero) }
}
