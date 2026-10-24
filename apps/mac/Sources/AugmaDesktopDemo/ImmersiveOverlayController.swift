import AppKit
import SwiftUI

private class ImmersivePanel: NSPanel {
  var onExit: (() -> Void)?
  var onNextControl: (() -> Void)?

  override func sendEvent(_ event: NSEvent) {
    if event.type == .keyDown, event.keyCode == 48,
       event.modifierFlags.intersection([.command, .option, .control, .shift]) == .control,
       let onNextControl {
      onNextControl()
      return
    }
    // A borderless scene may have WebKit focus or no SwiftUI focus target.
    if event.type == .keyDown, event.keyCode == 53,
       event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty,
       let onExit {
      onExit()
      return
    }
    super.sendEvent(event)
  }
}

private final class ImmersiveCanvasPanel: ImmersivePanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}

private final class ImmersiveControlsPanel: ImmersivePanel {
  override var canBecomeKey: Bool { true }
}

@MainActor
final class ImmersiveOverlayController: NSObject {
  private let model: HudModel
  private var sourceWindow: NSWindow?
  private var canvasPanel: ImmersiveCanvasPanel?
  private var chromePanels: [ImmersiveLayout.Chrome: ImmersiveControlsPanel] = [:]
  private var session: NativeDemoModel?
  private var previousApplication: NSRunningApplication?
  private var presentationScreen: NSScreen?
  private let workspace: WorkspaceStore
  private let commands: WorkspaceCommands
  private let monitor: SystemMonitorStore
  private let weather: WeatherStore
  private let preferences: NativePreferencesStore
  private let audio: NativeAudioStore
  private let maps: NativeMapStore
  private let camera: NativeCameraStore
  private var interactiveRegions: [CGRect] = []
  private var globalMouseMonitor: Any?
  private var localMouseMonitor: Any?
  private var mouseTrackingTimer: Timer?

  init(model: HudModel, workspace: WorkspaceStore, commands: WorkspaceCommands,
       monitor: SystemMonitorStore, weather: WeatherStore, preferences: NativePreferencesStore, audio: NativeAudioStore,
       maps: NativeMapStore, camera: NativeCameraStore) {
    self.model = model
    self.workspace = workspace
    self.commands = commands
    self.monitor = monitor
    self.weather = weather
    self.preferences = preferences
    self.audio = audio
    self.maps = maps
    self.camera = camera
  }

  func start(session: NativeDemoModel) {
    guard !model.immersiveActive,
          let sourceWindow = session.window ?? NSApp.keyWindow,
          let screen = sourceWindow.screen ?? NSScreen.main else { return }

    self.sourceWindow = sourceWindow
    self.session = session
    session.setImmersive(true)
    model.immersiveActive = true
    model.immersiveClickThrough = false
    interactiveRegions = []

    let canvas = ImmersiveCanvasPanel(contentRect: screen.visibleFrame, styleMask: [.borderless], backing: .buffered, defer: false)
    canvas.title = "Augma Immersive"
    configure(canvas, level: .floating)
    canvas.ignoresMouseEvents = true
    canvas.acceptsMouseMovedEvents = true
    canvasPanel = canvas
    presentationScreen = screen

    makeChrome(.voice, screen: screen, content: ImmersiveVoiceCorner(select: { [weak self] in self?.select($0) }))
    makeChrome(.clock, screen: screen, content: ImmersiveClockView())
    makeChrome(.system, screen: screen, content: ImmersiveSystemCorner(
      session: session, preferences: preferences, model: model, notices: session.notifications,
      select: { [weak self] in self?.select($0) },
      toggleInteraction: { [weak self] in self?.toggleInteraction() }, exit: { [weak self] in self?.stop() }
    ))
    makeChrome(.dock, screen: screen, content: ImmersiveDockView(
      session: session, preferences: preferences, camera: camera, select: { [weak self] in self?.select($0) }
    ))

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
    show()
  }

  func show() {
    guard model.immersiveActive, let session, let canvas = canvasPanel else { return }
    if model.immersiveVisible {
      NSApp.activate(ignoringOtherApps: true)
      canvas.makeKeyAndOrderFront(nil)
      showChrome()
      return
    }
    let frontmost = NSWorkspace.shared.frontmostApplication
    if frontmost?.processIdentifier != ProcessInfo.processInfo.processIdentifier { previousApplication = frontmost }
    presentationScreen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? presentationScreen
    updateScreenFrames()
    canvas.contentView = NSHostingView(rootView: ImmersiveCanvasView(
      session: session, preferences: preferences, workspace: workspace, commands: commands,
      monitor: monitor, weather: weather, audio: audio, maps: maps, camera: camera,
      onInteractiveRegionsChanged: { [weak self] regions in
        guard let self, self.interactiveRegions != regions else { return }
        self.interactiveRegions = regions
        self.updateMouseInterception()
      }
    ))
    model.immersiveVisible = true
    mouseTrackingTimer?.fireDate = .now
    NSApp.unhide(nil)
    NSApp.activate(ignoringOtherApps: true)
    canvas.makeKeyAndOrderFront(nil)
    showChrome()
    updateMouseInterception()
  }

  func hide(restoreFocus: Bool = true) {
    guard model.immersiveActive, model.immersiveVisible else { return }
    model.immersiveVisible = false
    commands.cancelVoice()
    session?.assistant.cancel()
    session?.browser.suspendPlayback()
    mouseTrackingTimer?.fireDate = .distantFuture
    canvasPanel?.orderOut(nil)
    chromePanels.values.forEach { $0.orderOut(nil) }
    // Unmount renderers and camera consumers while retaining their scene stores.
    canvasPanel?.contentView = nil
    interactiveRegions = []
    if restoreFocus { previousApplication?.activate() }
  }

  func hideAfterOpeningProject(_ id: UUID) {
    guard model.immersiveVisible, let session, session.selection == .space,
          session.space.sceneID == .projects else { return }
    let selected = session.space.projects.regions.first { $0.id == session.space.selectedProjectID }
      ?? session.space.projects.regions.first
    if selected?.id == id { hide(restoreFocus: false) }
  }

  func toggleVisibility() {
    model.immersiveVisible ? hide() : show()
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
    commands.cancelVoice()
    session?.setImmersive(false)
    canvasPanel?.close()
    chromePanels.values.forEach { $0.close() }
    canvasPanel = nil
    chromePanels.removeAll()
    session = nil
    interactiveRegions = []
    model.immersiveVisible = false
    model.immersiveActive = false
    previousApplication = nil
    presentationScreen = nil
    model.immersiveClickThrough = false
    sourceWindow?.deminiaturize(nil)
    sourceWindow?.makeKeyAndOrderFront(nil)
    sourceWindow = nil
    NSApp.activate(ignoringOtherApps: true)
  }

  func toggleInteraction() {
    guard model.immersiveActive else { return }
    if !model.immersiveVisible { show() }
    model.immersiveClickThrough.toggle()
    updateMouseInterception()
    if model.immersiveClickThrough {
      chromePanels[.system]?.makeKeyAndOrderFront(nil)
    } else {
      canvasPanel?.makeKeyAndOrderFront(nil)
      showChrome()
    }
  }

  func select(_ module: DemoModule) {
    preferences.value.showHud = true
    session?.selection = module
    if !model.immersiveVisible { show() }
    canvasPanel?.makeKeyAndOrderFront(nil)
    showChrome()
  }

  @discardableResult
  func performSpace(_ action: NativeSpaceAction) -> Bool {
    guard model.immersiveActive, let session else { return false }
    session.performSpaceAction(action)
    if !model.immersiveVisible { show() }
    canvasPanel?.makeKeyAndOrderFront(nil)
    showChrome()
    return true
  }

  private func configure(_ panel: ImmersivePanel, level: NSWindow.Level) {
    panel.onExit = { [weak self] in self?.stop() }
    panel.onNextControl = { [weak self] in self?.focusNextControl() }
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.isFloatingPanel = true
    panel.level = level
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
  }

  private func makeChrome<Content: View>(_ kind: ImmersiveLayout.Chrome, screen: NSScreen, content: Content) {
    let panel = ImmersiveControlsPanel(contentRect: ImmersiveLayout.frame(for: kind, in: screen.visibleFrame),
                                       styleMask: [.borderless], backing: .buffered, defer: false)
    panel.title = "Augma Immersive " + String(describing: kind).capitalized
    configure(panel, level: .statusBar)
    panel.ignoresMouseEvents = kind == .clock
    panel.contentView = NSHostingView(rootView: content)
    chromePanels[kind] = panel
  }

  private func showChrome() {
    for panel in chromePanels.values { panel.orderFrontRegardless() }
  }

  /// Keep the separate floating controls reachable without a mouse.
  private func focusNextControl() {
    let panels: [NSPanel] = [canvasPanel, chromePanels[.dock], chromePanels[.voice], chromePanels[.system]].compactMap { $0 }
    guard !panels.isEmpty else { return }
    let index = panels.firstIndex { $0 === NSApp.keyWindow } ?? 0
    let next = panels[(index + 1) % panels.count]
    next.makeKeyAndOrderFront(nil)
    next.selectNextKeyView(nil)
  }

  private func updateMouseInterception() {
    guard model.immersiveVisible, let canvasPanel else { return }
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
    updateScreenFrames()
  }

  private func updateScreenFrames() {
    let screen = presentationScreen.flatMap { selected in NSScreen.screens.first { $0 == selected } }
      ?? NSScreen.main
    guard let screen else { return }
    canvasPanel?.setFrame(screen.visibleFrame, display: true)
    for (kind, panel) in chromePanels {
      panel.setFrame(ImmersiveLayout.frame(for: kind, in: screen.visibleFrame), display: true)
    }
    updateMouseInterception()
  }
}
