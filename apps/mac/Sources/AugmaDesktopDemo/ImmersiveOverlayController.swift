import AppKit
import SwiftUI

private final class ImmersiveCanvasPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}

private final class ImmersiveControlsPanel: NSPanel {
  override var canBecomeKey: Bool { true }
}

@MainActor
final class ImmersiveOverlayController: NSObject {
  private let model: HudModel
  private var sourceWindow: NSWindow?
  private var canvasPanel: ImmersiveCanvasPanel?
  private var controlsPanel: ImmersiveControlsPanel?
  private var selection: Binding<DemoModule?>?
  private var interactiveRegions: [CGRect] = []
  private var globalMouseMonitor: Any?
  private var localMouseMonitor: Any?
  private var mouseTrackingTimer: Timer?

  init(model: HudModel) {
    self.model = model
  }

  func start(selection: Binding<DemoModule?>) {
    guard !model.immersiveActive,
          let sourceWindow = NSApp.keyWindow,
          let screen = sourceWindow.screen ?? NSScreen.main else { return }

    self.sourceWindow = sourceWindow
    self.selection = selection
    model.immersiveActive = true
    model.immersiveClickThrough = false
    interactiveRegions = []

    let canvas = ImmersiveCanvasPanel(contentRect: screen.visibleFrame, styleMask: [.borderless], backing: .buffered, defer: false)
    canvas.title = "Augma Immersive"
    configure(canvas, level: .floating)
    canvas.ignoresMouseEvents = true
    canvas.acceptsMouseMovedEvents = true
    canvas.contentView = NSHostingView(rootView: ImmersiveCanvasView(
      selection: selection,
      onInteractiveRegionsChanged: { [weak self] regions in
        guard let self, self.interactiveRegions != regions else { return }
        self.interactiveRegions = regions
        self.updateMouseInterception()
      }
    ))
    canvasPanel = canvas

    let controls = ImmersiveControlsPanel(contentRect: controlsFrame(on: screen), styleMask: [.borderless], backing: .buffered, defer: false)
    controls.title = "Augma Immersive Controls"
    configure(controls, level: .statusBar)
    controls.hasShadow = true
    controls.contentView = NSHostingView(rootView: ImmersiveControlsView(
      selection: selection,
      model: model,
      toggleInteraction: { [weak self] in self?.toggleInteraction() },
      exit: { [weak self] in self?.stop() }
    ))
    controlsPanel = controls

    NotificationCenter.default.addObserver(self, selector: #selector(screenDidChange), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    let mouseEvents: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
    globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseEvents) { [weak self] _ in
      Task { @MainActor [weak self] in self?.updateMouseInterception() }
    }
    localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseEvents) { [weak self] event in
      Task { @MainActor [weak self] in self?.updateMouseInterception() }
      return event
    }
    let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in self?.updateMouseInterception() }
    }
    RunLoop.main.add(timer, forMode: .common)
    mouseTrackingTimer = timer
    sourceWindow.orderOut(nil)
    canvas.orderFrontRegardless()
    controls.makeKeyAndOrderFront(nil)
    updateMouseInterception()
  }

  func stop() {
    guard model.immersiveActive else { return }
    NotificationCenter.default.removeObserver(self, name: NSApplication.didChangeScreenParametersNotification, object: nil)
    if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
    if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
    globalMouseMonitor = nil
    localMouseMonitor = nil
    mouseTrackingTimer?.invalidate()
    mouseTrackingTimer = nil
    canvasPanel?.close()
    controlsPanel?.close()
    canvasPanel = nil
    controlsPanel = nil
    selection = nil
    interactiveRegions = []
    model.immersiveActive = false
    model.immersiveClickThrough = false
    sourceWindow?.makeKeyAndOrderFront(nil)
    sourceWindow = nil
    NSApp.activate(ignoringOtherApps: true)
  }

  func toggleInteraction() {
    guard model.immersiveActive else { return }
    model.immersiveClickThrough.toggle()
    updateMouseInterception()
    if model.immersiveClickThrough {
      controlsPanel?.makeKeyAndOrderFront(nil)
    } else {
      canvasPanel?.makeKeyAndOrderFront(nil)
      controlsPanel?.orderFrontRegardless()
    }
  }

  func select(_ module: DemoModule) {
    selection?.wrappedValue = module
  }

  private func configure(_ panel: NSPanel, level: NSWindow.Level) {
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.isFloatingPanel = true
    panel.level = level
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
  }

  private func controlsFrame(on screen: NSScreen) -> NSRect {
    let visible = screen.visibleFrame
    let width: CGFloat = 400
    let height: CGFloat = 56
    return NSRect(x: visible.maxX - width - 20, y: visible.maxY - height - 12, width: width, height: height)
  }

  private func updateMouseInterception() {
    guard let canvasPanel else { return }
    guard !model.immersiveClickThrough, canvasPanel.frame.contains(NSEvent.mouseLocation) else {
      if !canvasPanel.ignoresMouseEvents { canvasPanel.ignoresMouseEvents = true }
      return
    }
    guard NSEvent.pressedMouseButtons == 0 else { return }
    guard let contentView = canvasPanel.contentView else { return }
    let windowPoint = canvasPanel.convertPoint(fromScreen: NSEvent.mouseLocation)
    let viewPoint = contentView.convert(windowPoint, from: nil)
    let pagePoint = CGPoint(x: viewPoint.x,
                            y: contentView.isFlipped ? viewPoint.y : contentView.bounds.height - viewPoint.y)
    let ignore = !interactiveRegions.contains { $0.contains(pagePoint) }
    if canvasPanel.ignoresMouseEvents != ignore { canvasPanel.ignoresMouseEvents = ignore }
  }

  @objc private func screenDidChange(_ notification: Notification) {
    guard let screen = sourceWindow?.screen ?? NSScreen.main else { return }
    canvasPanel?.setFrame(screen.visibleFrame, display: true)
    controlsPanel?.setFrame(controlsFrame(on: screen), display: true)
    updateMouseInterception()
  }
}
