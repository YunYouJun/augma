import AppKit
import OSLog
import SwiftUI

private final class HudPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}

@MainActor
final class HudAppDelegate: NSObject, NSApplicationDelegate {
  let model = HudModel()
  private var panel: HudPanel?
  private lazy var immersiveOverlay = ImmersiveOverlayController(model: model)
  private let logger = Logger(subsystem: "cn.yunyoujun.augma.desktop-demo", category: "lifecycle")

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)

    let panel = HudPanel(
      contentRect: NSRect(x: 0, y: 0, width: 430, height: 320),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    panel.isOpaque = false
    panel.title = "Augma HUD"
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.level = .floating
    panel.isFloatingPanel = true
    panel.hidesOnDeactivate = false
    panel.isMovableByWindowBackground = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.contentView = NSHostingView(rootView: HudView(
      model: model,
      hideWindow: { [weak self] in self?.hideWindow() }
    ))
    panel.center()
    self.panel = panel
    logger.notice("Demo launched; HUD available from menu bar")
  }

  func showWindow() {
    guard let panel else { return }
    model.windowVisible = true
    NSApp.activate(ignoringOtherApps: true)
    panel.makeKeyAndOrderFront(nil)
    logger.notice("HUD shown")
  }

  func hideWindow() {
    model.windowVisible = false
    panel?.orderOut(nil)
    logger.notice("HUD hidden; 3D scene disabled")
  }

  func toggleWindow() {
    model.windowVisible ? hideWindow() : showWindow()
  }

  func toggleClickThrough() {
    model.clickThrough.toggle()
    panel?.ignoresMouseEvents = model.clickThrough
  }

  func enterImmersive(selection: Binding<DemoModule?>) {
    hideWindow()
    NotificationCenter.default.post(name: .augmaCancelSpeech, object: nil)
    immersiveOverlay.start(selection: selection)
  }

  func exitImmersive() {
    immersiveOverlay.stop()
  }

  func toggleImmersiveInteraction() {
    immersiveOverlay.toggleInteraction()
  }

  func selectImmersiveModule(_ module: DemoModule) {
    immersiveOverlay.select(module)
  }

  func applicationDidHide(_ notification: Notification) {
    model.windowVisible = false
  }

  func applicationDidUnhide(_ notification: Notification) {
    model.windowVisible = panel?.isVisible ?? false
  }

}
