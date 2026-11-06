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
  let preferences = NativePreferencesStore(synchronizesAppLanguage: true)
  private let menuLocalization = NativeMenuLocalization()
  let model = HudModel()
  let sessions = DemoSessionRegistry()
  let workspace = WorkspaceStore()
  let craftHubCompanion = CraftHubCompanionStore()
  lazy var captures = QuickCaptureStore(workspace: workspace)
  let monitor = SystemMonitorStore()
  let menuBarShelf = MenuBarShelfStore()
  let market = ApplicationMarketStore()
  let weather = WeatherStore()
  let navigation = NativeNavigationStore()
  let dock = NativeDockStore()
  lazy var plugins = AugmaPluginStore(dock: dock)
  let audio = NativeAudioStore()
  let maps = NativeMapStore()
  let camera = NativeCameraStore()
  let applicationDistrict = ApplicationDistrictStore(persistence: ApplicationDistrictFile(url: ApplicationDistrictFile.defaultURL),
                                                   observeLifecycle: true)
  let immersiveShortcut = ImmersiveShortcutStore()
  let projectWorkspaces = ProjectWorkspaceStore(persistence: ProjectWorkspaceFile(url: ProjectWorkspaceFile.defaultURL),
    craftHub: CraftHubConnectionStore(persistence: CraftHubConnectionFile(url: CraftHubConnectionFile.defaultURL)))
  lazy var commands = WorkspaceCommands(store: workspace, captures: captures)
  private lazy var commandPalette = CommandPaletteController(commands: commands, store: workspace)
  private let weChatVoiceInput = WeChatVoiceInput()
  private let weChatVoiceShortcutMonitor = WeChatVoiceShortcutMonitor()
  private var weChatVoiceHoldTask: Task<Void, Never>?
  private var heldVoiceProvider: VoiceInputProvider?
  var openScene: ((String) -> Void)?
  private var panel: HudPanel?
  private var capturePanel: HudPanel?
  private var terminationSignal: DispatchSourceSignal?
  private var pendingImmersiveReveal = false
  private lazy var immersiveOverlay = ImmersiveOverlayController(model: model, workspace: workspace, commands: commands,
                                                               monitor: monitor, weather: weather, preferences: preferences, audio: audio,
                                                               maps: maps, camera: camera, dock: dock, menuBarShelf: menuBarShelf)
  private let logger = Logger(subsystem: "cn.yunyoujun.augma.desktop-demo", category: "lifecycle")

  func applicationDidFinishLaunching(_ notification: Notification) {
    menuLocalization.start()
    menuBarShelf.start()
    Task { await plugins.load() }
    AssistantMagpieConfiguration.shared.start()
    NSApp.setActivationPolicy(.regular)
    weChatVoiceShortcutMonitor.start(onPress: { [weak self] in self?.beginVoiceHold() },
                                    onRelease: { [weak self] in self?.endVoiceHold() })
    applicationDistrict.onOpen = { [weak self] id in
      guard let self, self.model.immersiveVisible, id != Bundle.main.bundleIdentifier else { return }
      self.immersiveOverlay.hide(restoreFocus: false)
    }
    dock.onOpen = { [weak self] id in
      guard let self, self.model.immersiveVisible, id != Bundle.main.bundleIdentifier else { return }
      self.immersiveOverlay.hide(restoreFocus: false)
    }
    projectWorkspaces.onOpenCompleted = { [weak self] id in
      self?.immersiveOverlay.hideAfterOpeningProject(id)
    }
    immersiveShortcut.start { [weak self] in self?.toggleImmersiveAssistant() }
    commands.navigate = { [weak self] module in
      guard let self else { return }
      if self.model.immersiveActive { self.immersiveOverlay.select(module) }
      else { self.openModule(module) }
    }
    commands.requestCleanup = { [weak self] text in self?.market.requestCleanup(text) ?? false }
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
    ).appLocalized())
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

  func showQuickCapture() {
    if capturePanel == nil {
      let panel = HudPanel(contentRect: NSRect(x: 0, y: 0, width: 500, height: 560),
                           styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
      panel.title = String(appLocalized: "快速记录")
      panel.titlebarAppearsTransparent = true
      panel.isReleasedWhenClosed = false
      panel.hidesOnDeactivate = false
      panel.level = .floating
      panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
      panel.contentView = NSHostingView(rootView: QuickCaptureUtilityView(store: workspace, commands: commands, companion: craftHubCompanion) { [weak panel] in panel?.close() }.appLocalized(windowTitle: "快速记录"))
      panel.center()
      capturePanel = panel
    }
    NSApp.activate(ignoringOtherApps: true)
    capturePanel?.makeKeyAndOrderFront(nil)
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
    commandPalette.show(voice: voice, windowLevel: model.immersiveVisible ? .statusBar : .floating)
  }

  func startVoiceInput() {
    endVoiceHold()
    commands.cancelVoice()
    if VoiceInputProvider.current == .apple {
      commandPalette.show(voice: true, speechMode: .dictation,
                          windowLevel: model.immersiveVisible ? .statusBar : .floating)
    } else {
      startWeChatVoiceInput()
    }
  }

  private func beginVoiceHold() {
    guard heldVoiceProvider == nil else { return }
    let provider = VoiceInputProvider.current
    heldVoiceProvider = provider
    if provider == .apple {
      commands.cancelVoice()
      commandPalette.show(voice: true, speechMode: .dictation,
                          windowLevel: model.immersiveVisible ? .statusBar : .floating)
    } else {
      beginWeChatVoiceHold()
    }
  }

  private func endVoiceHold() {
    let provider = heldVoiceProvider
    heldVoiceProvider = nil
    if provider == .apple { commands.finishDictation() }
    endWeChatVoiceHold()
  }

  func startWeChatVoiceInput() {
    commands.cancelVoice()
    Task { @MainActor in
      do {
        try await weChatVoiceInput.start { self.showCommands() }
      } catch let failure as WeChatVoiceInput.Failure {
        let alert = NSAlert()
        alert.messageText = WeChatVoiceInput.title
        alert.informativeText = failure.message
        if failure == .accessibilityRequired {
          alert.addButton(withTitle: String(appLocalized: "打开辅助功能设置"))
          alert.addButton(withTitle: String(appLocalized: "取消"))
          if alert.runModal() == .alertFirstButtonReturn,
             let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
          }
        } else {
          alert.addButton(withTitle: String(appLocalized: "好"))
          alert.runModal()
        }
      } catch is CancellationError {
      } catch {
        logger.error("WeChat voice shortcut failed: \(error.localizedDescription, privacy: .public)")
      }
    }
  }

  private func beginWeChatVoiceHold() {
    commands.cancelVoice()
    weChatVoiceHoldTask?.cancel()
    weChatVoiceHoldTask = Task { @MainActor in
      do {
        try await weChatVoiceInput.beginHold { self.showCommands() }
      } catch is CancellationError {
      } catch let failure as WeChatVoiceInput.Failure {
        let alert = NSAlert()
        alert.messageText = WeChatVoiceInput.title
        alert.informativeText = failure.message
        alert.addButton(withTitle: String(appLocalized: "好"))
        alert.runModal()
      } catch {
        logger.error("WeChat hold shortcut failed: \(error.localizedDescription, privacy: .public)")
      }
    }
  }

  private func endWeChatVoiceHold() {
    weChatVoiceHoldTask?.cancel()
    weChatVoiceHoldTask = nil
    weChatVoiceInput.endHold()
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    guard model.immersiveActive else { return true }
    immersiveOverlay.show()
    return false
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    if monitor.cleanup.isCleaning || market.isMutating {
      let alert = NSAlert()
      alert.messageText = String(appLocalized: "安装或清理正在进行")
      alert.informativeText = String(appLocalized: "请等待本次操作结束后退出，以便核对操作结果。")
      alert.addButton(withTitle: String(appLocalized: "继续等待"))
      alert.runModal()
      return .terminateCancel
    }
    endVoiceHold()
    monitor.cleanup.cancel()
    market.cancel()
    commands.cancelVoice()
    Task {
      let notesSaved = await workspace.flush()
      let projectsSaved = projectWorkspaces.flush()
      if applicationDistrict.saveError != nil { applicationDistrict.retrySave() }
      let saved = notesSaved && projectsSaved && applicationDistrict.saveError == nil
      if saved {
        await menuBarShelf.shutdown()
        audio.shutdown()
        camera.shutdown()
        maps.cancelRequests()
        await NativeAssistantRuntime.shared.shutdownAndWait()
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
        alert.messageText = String(appLocalized: "更改尚未保存")
        alert.informativeText = !projectsSaved
          ? String(appLocalized: "项目配置尚未保存。请返回修正或重试；仍然退出会放弃尚未保存的编辑。")
          : applicationDistrict.saveError != nil
          ? String(appLocalized: "应用街区布局尚未保存。请返回重试；仍然退出会放弃本次布局修改。")
          : String(appLocalized: "请返回重试保存或导出记录。仍然退出会丢失尚未保存的更改。")
        alert.addButton(withTitle: String(appLocalized: "返回保存"))
        alert.addButton(withTitle: String(appLocalized: "仍然退出"))
        let shouldQuit = alert.runModal() == .alertSecondButtonReturn
        if shouldQuit { await menuBarShelf.shutdown() }
        sender.reply(toApplicationShouldTerminate: shouldQuit)
      }
    }
    return .terminateLater
  }

  func applicationDidHide(_ notification: Notification) {
    model.windowVisible = false
    immersiveOverlay.hide(restoreFocus: false)
  }

  func applicationWillTerminate(_ notification: Notification) {
    weChatVoiceShortcutMonitor.stop()
    endVoiceHold()
    market.cancel()
    immersiveShortcut.stop()
    applicationDistrict.shutdown()
    projectWorkspaces.shutdown()
  }

  func applicationDidUnhide(_ notification: Notification) {
    model.windowVisible = panel?.isVisible ?? false
  }

}
