import AppKit
import Darwin
import OSLog
import SwiftUI

private final class HudPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}

@MainActor
final class HudAppDelegate: NSObject, NSApplicationDelegate {
  let model = HudModel()
  let sessions = DemoSessionRegistry()
  let workspace = WorkspaceStore()
  lazy var captures = QuickCaptureStore(workspace: workspace)
  let monitor = SystemMonitorStore()
  let weather = WeatherStore()
  let preferences = NativePreferencesStore()
  let audio = NativeAudioStore()
  let maps = NativeMapStore()
  let camera = NativeCameraStore()
  let applicationDistrict = ApplicationDistrictStore(persistence: ApplicationDistrictFile(url: ApplicationDistrictFile.defaultURL),
                                                   observeLifecycle: true)
  let immersiveShortcut = ImmersiveShortcutStore()
  let projectWorkspaces = ProjectWorkspaceStore(persistence: ProjectWorkspaceFile(url: ProjectWorkspaceFile.defaultURL))
  lazy var commands = WorkspaceCommands(store: workspace, audio: audio, captures: captures)
  var openScene: ((String) -> Void)?
  private var panel: HudPanel?
  private var terminationSignal: DispatchSourceSignal?
  private var pendingImmersiveReveal = false
  private lazy var immersiveOverlay = ImmersiveOverlayController(model: model, workspace: workspace, commands: commands,
                                                               monitor: monitor, weather: weather, preferences: preferences, audio: audio,
                                                               maps: maps, camera: camera)
  private let logger = Logger(subsystem: "cn.yunyoujun.augma.desktop-demo", category: "lifecycle")

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    applicationDistrict.onOpen = { [weak self] id in
      guard let self, self.model.immersiveVisible, id != Bundle.main.bundleIdentifier else { return }
      self.immersiveOverlay.hide(restoreFocus: false)
    }
    projectWorkspaces.onOpenCompleted = { [weak self] id in
      self?.immersiveOverlay.hideAfterOpeningProject(id)
    }
    immersiveShortcut.start { [weak self] in self?.toggleImmersiveAssistant() }
    commands.navigate = { [weak self] module in self?.openModule(module) }
    commands.operateSpace = { [weak self] action in
      guard let self else { return }
      if self.immersiveOverlay.performSpace(action) { return }
      self.sessions.perform(.space(action)) { self.openScene?("demo") }
    }
    workspace.notifications.onOpen = { [weak self] in self?.openModule(.focus) }
    workspace.notifications.activate()
    // The development launcher sends SIGTERM before rebuilding. Flush drafts on that path too.
    signal(SIGTERM, SIG_IGN)
    let terminationSignal = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    terminationSignal.setEventHandler {
      // terminateLater enters a modal run loop. Start it outside the main dispatch
      // callback so the async save can resume on the main actor and reply.
      RunLoop.main.perform {
        MainActor.assumeIsolated { NSApp.terminate(nil) }
      }
    }
    terminationSignal.resume()
    self.terminationSignal = terminationSignal

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
    panel.level = .normal
    panel.isFloatingPanel = false
    panel.hidesOnDeactivate = false
    panel.isMovableByWindowBackground = true
    panel.collectionBehavior = [.managed]
    panel.contentView = NSHostingView(rootView: HudView(
      model: model,
      monitor: monitor,
      openMonitor: { [weak self] in self?.openModule(.monitor) },
      hideWindow: { [weak self] in self?.hideWindow() }
    ))
    panel.center()
    self.panel = panel
    monitor.onHUDPinnedChanged = { [weak self] pinned in
      if pinned { self?.showWindow() }
      else { self?.hideWindow() }
    }
    if monitor.hudPinned { showWindow() }
    logger.notice("Demo launched; HUD available from menu bar")
  }

  func showWindow() {
    guard let panel else { return }
    model.windowVisible = true
    NSApp.activate(ignoringOtherApps: true)
    panel.makeKeyAndOrderFront(nil)
    refreshShadowAfterEntrance(of: panel)
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

  func enterImmersive(_ scene: NativeDemoModel) {
    commands.cancelVoice()
    hideWindow()
    if model.immersiveActive { immersiveOverlay.show() }
    else { immersiveOverlay.start(session: scene) }
  }

  func toggleImmersiveAssistant() {
    if model.immersiveActive {
      immersiveOverlay.toggleVisibility()
    } else if let scene = sessions.current, scene.window != nil {
      enterImmersive(scene)
    } else if pendingImmersiveReveal {
      pendingImmersiveReveal = false
    } else {
      pendingImmersiveReveal = true
      openScene?("demo")
    }
  }

  func mainWindowReady(_ scene: NativeDemoModel) {
    guard pendingImmersiveReveal else { return }
    // Wait until SwiftUI has registered and attached the newly opened window.
    Task { @MainActor [weak self, weak scene] in
      await Task.yield()
      guard let self, let scene, scene.window?.isVisible == true, self.pendingImmersiveReveal else { return }
      self.pendingImmersiveReveal = false
      self.enterImmersive(scene)
    }
  }

  func exitImmersive() {
    pendingImmersiveReveal = false
    immersiveOverlay.stop()
  }

  func toggleImmersiveInteraction() {
    immersiveOverlay.toggleInteraction()
  }

  func selectImmersiveModule(_ module: DemoModule) {
    immersiveOverlay.select(module)
  }

  func openModule(_ module: DemoModule? = nil) {
    if model.immersiveActive { exitImmersive() }
    sessions.perform(.open(module)) { openScene?("demo") }
  }

  func showCommands(voice: Bool = false) {
    if model.immersiveActive { exitImmersive() }
    NSApp.activate(ignoringOtherApps: true)
    commands.pendingVoice = voice
    openScene?("quick-command")
    // Existing utility windows do not necessarily receive another onAppear.
    if voice { commands.startPendingVoice() }
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    guard model.immersiveActive else { return true }
    immersiveOverlay.show()
    return false
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    commands.cancelVoice()
    Task {
      let notesSaved = await workspace.flush()
      let projectsSaved = projectWorkspaces.flush()
      if applicationDistrict.saveError != nil { applicationDistrict.retrySave() }
      let saved = notesSaved && projectsSaved && applicationDistrict.saveError == nil
      if saved {
        audio.shutdown()
        camera.shutdown()
        maps.cancelRequests()
        sender.reply(toApplicationShouldTerminate: true)
      }
      else {
        if !projectsSaved {
          if model.immersiveActive { exitImmersive() }
          sessions.perform(.space(.scene(.projects))) { openScene?("demo") }
        } else if applicationDistrict.saveError != nil {
          if model.immersiveActive { exitImmersive() }
          sessions.perform(.space(.scene(.workspace))) { openScene?("demo") }
        } else { openModule(.notes) }
        let alert = NSAlert()
        alert.messageText = String(localized: "更改尚未保存")
        alert.informativeText = !projectsSaved
          ? String(localized: "项目配置尚未保存。请返回修正或重试；仍然退出会放弃尚未保存的编辑。")
          : applicationDistrict.saveError != nil
          ? String(localized: "应用街区布局尚未保存。请返回重试；仍然退出会放弃本次布局修改。")
          : String(localized: "请返回重试保存或导出记录。仍然退出会丢失尚未保存的更改。")
        alert.addButton(withTitle: String(localized: "返回保存"))
        alert.addButton(withTitle: String(localized: "仍然退出"))
        sender.reply(toApplicationShouldTerminate: alert.runModal() == .alertSecondButtonReturn)
      }
    }
    return .terminateLater
  }

  func applicationDidHide(_ notification: Notification) {
    model.windowVisible = false
    immersiveOverlay.hide(restoreFocus: false)
  }

  func applicationWillTerminate(_ notification: Notification) {
    immersiveShortcut.stop()
    applicationDistrict.shutdown()
    projectWorkspaces.shutdown()
  }

  func applicationDidUnhide(_ notification: Notification) {
    model.windowVisible = panel?.isVisible ?? false
  }

}
