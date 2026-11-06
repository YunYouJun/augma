import AppKit
import SwiftUI

private final class MenuBarShelfWindowPanel: NSPanel {
  var onDismiss: (() -> Void)?
  var onNextControl: (() -> Void)?
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  override func cancelOperation(_ sender: Any?) { onDismiss?() }
  override func sendEvent(_ event: NSEvent) {
    if event.type == .keyDown, event.keyCode == 48,
       event.modifierFlags.intersection([.command, .option, .control, .shift]) == .control,
       let onNextControl {
      onNextControl()
      return
    }
    if event.type == .keyDown, event.keyCode == 53 { onDismiss?(); return }
    super.sendEvent(event)
  }
}

@MainActor
final class MenuBarShelfPanel: NSObject {
  private weak var store: MenuBarShelfStore?
  private var panel: MenuBarShelfWindowPanel?
  private var outsideMonitor: Any?
  private var localMonitor: Any?
  private var immersive = false

  var window: NSPanel? { panel }

  init(store: MenuBarShelfStore) { self.store = store }

  func show(in immersiveScreen: NSScreen? = nil) {
    guard let store, let display = MenuBarShelfDisplay.current(),
          let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display.id
          }), let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { return }
    let size = NSSize(width: min(620, screen.visibleFrame.width - 32), height: 198)
    let notchCenter = (left.maxX + right.minX) / 2
    let origin = NSPoint(x: min(max(screen.frame.minX + 16, notchCenter - size.width / 2), screen.frame.maxX - size.width - 16),
                         y: screen.frame.maxY - screen.safeAreaInsets.top - size.height - 10)
    let panel = self.panel ?? makePanel()
    immersive = immersiveScreen != nil
    let shelfFrame = immersiveScreen.map { MenuBarShelfLayout.immersiveFrame(in: $0.visibleFrame, clockVisible: store.immersiveClockVisible) }
      ?? NSRect(origin: origin, size: size)
    panel.setFrame(MenuBarShelfLayout.windowFrame(for: shelfFrame), display: false)
    let hosting = NSHostingView(rootView: MenuBarShelfView(store: store, compact: immersive)
      .padding(MenuBarShelfLayout.shadowOutset).appLocalized(windowTitle: "菜单栏收纳"))
    hosting.sizingOptions = []
    panel.contentView = hosting
    self.panel = panel
    panel.onNextControl = immersive ? store.onNextImmersiveControl : nil
    // Preserve the user's foreground application and its menu bar while the shelf is open.
    if immersive { panel.orderFrontRegardless() }
    else { panel.makeKeyAndOrderFront(nil) }
    if outsideMonitor == nil {
      outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
        MainActor.assumeIsolated {
          guard let self, !self.immersive,
                !self.containsShelf(NSEvent.mouseLocation) else { return }
          self.store?.hide()
        }
      }
      localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
        MainActor.assumeIsolated {
          if let self, !self.immersive, event.window !== self.panel,
             !self.containsShelf(NSEvent.mouseLocation) { self.store?.hide() }
        }
        return event
      }
    }
  }

  func updateImmersiveFrame(on screen: NSScreen, clockVisible: Bool) {
    guard immersive else { return }
    panel?.setFrame(MenuBarShelfLayout.windowFrame(for:
      MenuBarShelfLayout.immersiveFrame(in: screen.visibleFrame, clockVisible: clockVisible)), display: true)
  }

  private func containsShelf(_ point: NSPoint) -> Bool {
    guard let panel else { return false }
    return MenuBarShelfLayout.shelfFrame(in: panel.frame).contains(point)
  }

  func hide() {
    panel?.orderOut(nil)
    if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor) }
    if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    outsideMonitor = nil
    localMonitor = nil
  }

  private func makePanel() -> MenuBarShelfWindowPanel {
    let panel = MenuBarShelfWindowPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                       backing: .buffered, defer: false)
    panel.title = String(appLocalized: "菜单栏收纳")
    panel.isOpaque = false
    panel.backgroundColor = .clear
    // Liquid Glass supplies the adaptive shadow; don't stack a second window shadow.
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.becomesKeyOnlyIfNeeded = false
    panel.isReleasedWhenClosed = false
    panel.level = .statusBar
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.onDismiss = { [weak self] in
      guard let self else { return }
      if self.immersive, let exit = self.store?.onExitImmersive { exit() }
      else { self.store?.hide() }
    }
    return panel
  }
}
