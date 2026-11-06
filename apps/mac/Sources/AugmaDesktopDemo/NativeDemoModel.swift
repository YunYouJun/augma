import AppKit
import Combine
import SwiftUI

/// Window-owned state survives the transition between the main and immersive UI.
/// Native modules keep their own state; browser sessions and plugin pages use separate WebKit lifecycles.
@MainActor
final class NativeDemoModel: ObservableObject {
  @Published var selection: DemoModule? = .notes {
    didSet {
      if oldValue == .commands, selection != .commands, !performingAssistantAction { assistant.cancel() }
      rememberPage()
    }
  }
  @Published private(set) var isImmersive = false
  @Published private(set) var activePluginID: String?
  weak var window: NSWindow?
  let preferences: NativePreferencesStore
  let audio: NativeAudioStore?
  let space: NativeSpaceStore
  let notifications: NativeNotificationStore
  let device: NativeDeviceStore
  let assistant: NativeAssistantStore
  let market: ApplicationMarketStore
  let dock: NativeDockStore
  let plugins: AugmaPluginStore
  let browser: NativeBrowserStore
  weak var commands: WorkspaceCommands?
  var performingAssistantAction = false
  private var observers: [AnyCancellable] = []
  private var closed = false
  private let navigation: NativeNavigationStore?
  private let navigationSessionID = UUID()

  init(preferences: NativePreferencesStore? = nil, audio: NativeAudioStore? = nil,
       space: NativeSpaceStore? = nil, commands: WorkspaceCommands? = nil, applications: ApplicationDistrictStore? = nil,
       projects: ProjectWorkspaceStore? = nil, navigation: NativeNavigationStore? = nil,
       market: ApplicationMarketStore? = nil, dock: NativeDockStore? = nil, plugins: AugmaPluginStore? = nil) {
    let preferences = preferences ?? NativePreferencesStore()
    self.preferences = preferences
    self.audio = audio
    self.space = space ?? NativeSpaceStore(applications: applications, projects: projects)
    self.commands = commands
    self.navigation = navigation
    self.market = market ?? ApplicationMarketStore()
    let dock = dock ?? NativeDockStore()
    self.dock = dock
    self.plugins = plugins ?? AugmaPluginStore(dock: dock)
    let notifications = NativeNotificationStore()
    self.notifications = notifications
    device = NativeDeviceStore(notifications: notifications)
    assistant = NativeAssistantStore(preferences: preferences)
    browser = NativeBrowserStore()
    assistant.performAction = { [weak self] action in
      self?.performAssistantAction(action) ?? NativeAssistantResult(message: String(appLocalized: "窗口已关闭。"), isError: true)
    }
    assistant.performWorkspaceCommand = { [weak self] command in
      self?.performAssistantWorkspaceCommand(command) ?? NativeAssistantResult(message: String(appLocalized: "窗口已关闭。"), isError: true)
    }
    assistant.performCleanupRequest = { [weak self] text in
      guard let self, self.market.requestCleanup(text) else {
        return .init(message: String(appLocalized: "清理工具正忙，请等待当前操作完成。"), isError: true)
      }
      self.performingAssistantAction = true
      self.selection = .market
      self.preferences.value.showHud = true
      self.performingAssistantAction = false
      return .init(message: String(appLocalized: "已打开 Augma Link 本地工具，按保留规则生成计划；执行前请核对并确认。"))
    }
    device.onSuspend = { [weak self] in
      self?.space.cancelScan()
      self?.space.cancelRoute()
      self?.assistant.cancel()
    }
    if let location = navigation?.startupLocation {
      self.space.selectScene(location.spaceScene)
      selection = location.module == .plugin ? .market : location.module
    }
    observeSpaceActivity()
    self.space.$sceneID.dropFirst().sink { [weak self] scene in
      self?.rememberPage(scene: scene)
    }.store(in: &observers)
    self.plugins.$installations.dropFirst().sink { [weak self] installations in
      guard let self, let id = self.activePluginID,
            !installations.contains(where: { $0.id == id && $0.enabled && $0.problem == nil }) else { return }
      self.activePluginID = nil
      if self.selection == .plugin { self.selection = .market; self.market.section = .plugins }
    }.store(in: &observers)
  }

  var pageTitle: String {
    if selection == .plugin, let id = activePluginID { return plugins.installation(id)?.manifest.displayName ?? String(appLocalized: "插件") }
    return selection?.title ?? ""
  }

  func openPlugin(_ id: String) {
    guard !closed, plugins.enabledPackage(id) != nil else { showPlugins(); return }
    activePluginID = id; selection = .plugin; preferences.value.showHud = true
  }

  func showPlugins() {
    activePluginID = nil; market.section = .plugins; selection = .market; preferences.value.showHud = true
  }

  var pageLocation: NativePageLocation? {
    selection.map { NativePageLocation(module: $0 == .plugin ? .market : $0, spaceScene: space.sceneID) }
  }

  func activateNavigation() {
    if let pageLocation { navigation?.activate(navigationSessionID, location: pageLocation) }
  }

  func goHome() {
    let location = navigation?.homeLocation ?? .workspace
    if location.module == .space { space.selectScene(location.spaceScene) }
    selection = location.module == .plugin ? .market : location.module
    preferences.value.showHud = true
  }

  private func rememberPage(scene: NativeSpaceSceneID? = nil) {
    guard !closed, let selection, selection != .plugin else { return }
    navigation?.remember(NativePageLocation(module: selection, spaceScene: scene ?? space.sceneID), sessionID: navigationSessionID)
  }

  func setImmersive(_ value: Bool) {
    browser.setPresentation(value ? .immersive : .main)
    isImmersive = value
  }

  func closeScene() {
    guard !closed else { return }
    closed = true
    observers.removeAll()
    space.shutdown()
    device.shutdown()
    assistant.shutdown()
    browser.shutdown()
  }

  func toggleSpeech() {
    guard !closed else { return }
    selection = .commands
    assistant.toggleVoice()
  }

  func performSpaceAction(_ action: NativeSpaceAction) {
    guard !closed else { return }
    selection = .space
    preferences.value.showHud = true
    space.perform(action)
  }

  private func observeSpaceActivity() {
    space.$scanProgress.removeDuplicates().dropFirst().filter { $0 == 100 }
      .sink { [weak self] _ in
        self?.notifications.post(title: String(appLocalized: "模拟扫描完成"),
                                 detail: String(appLocalized: "可以选择地标并固定虚拟锚点。"), symbol: "viewfinder")
      }.store(in: &observers)
    space.$sceneID.removeDuplicates().dropFirst().sink { [weak self] scene in
      guard let self else { return }
      self.notifications.post(title: String(appLocalized: "已切换空间场景"),
                              detail: NativeSpaceScene.scene(for: scene).title(locale: self.preferences.locale), symbol: "square.3.layers.3d")
    }.store(in: &observers)
    space.$pinnedLandmarkID.removeDuplicates().dropFirst().compactMap { $0 }.sink { [weak self] id in
      guard let self, let landmark = self.space.scene.landmarks.first(where: { $0.id == id }) else { return }
      self.notifications.post(title: String(appLocalized: "已固定虚拟锚点"),
                              detail: landmark.title(locale: self.preferences.locale), symbol: "pin")
    }.store(in: &observers)
    space.$routeStep.removeDuplicates().dropFirst().filter { $0 == 4 }.sink { [weak self] _ in
      guard let self else { return }
      self.notifications.post(title: String(appLocalized: "已到达模拟目的地"),
                              detail: self.space.selected.title(locale: self.preferences.locale), symbol: "flag.checkered")
    }.store(in: &observers)
  }
}

private struct NativeDemoFocusKey: FocusedValueKey {
  typealias Value = NativeDemoModel
}

extension FocusedValues {
  var nativeDemo: NativeDemoModel? {
    get { self[NativeDemoFocusKey.self] }
    set { self[NativeDemoFocusKey.self] = newValue }
  }
}

struct NativeDemoCommands: Commands {
  @FocusedValue(\.nativeDemo) private var model

  var body: some Commands {
    CommandMenu(String(appLocalized: "应用")) {
      Button(String(appLocalized: "返回首页"), systemImage: "house") { model?.goHome() }
        .keyboardShortcut("h", modifiers: [.command, .shift])
        .disabled(model == nil)
      Divider()
      ForEach(Array(DemoModule.applications.enumerated()), id: \.element) { index, module in
        if index < 9 {
          Button(module.title, systemImage: module.symbol) { model?.selection = module }
            .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
            .disabled(model == nil)
        } else {
          Button(module.title, systemImage: module.symbol) { model?.selection = module }.disabled(model == nil)
        }
      }
    }
    CommandMenu(String(appLocalized: "网页")) {
      Button(String(appLocalized: "输入网址或搜索")) { model?.browser.focusAddress() }
        .keyboardShortcut("l", modifiers: .command)
        .disabled(model?.selection != .browser)
      Button(String(appLocalized: "重新载入")) { model?.browser.reloadOrStop() }
        .keyboardShortcut("r", modifiers: .command)
        .disabled(model?.selection != .browser)
      Button(String(appLocalized: "后退")) { model?.browser.goBack() }
        .keyboardShortcut("[", modifiers: .command)
        .disabled(model?.selection != .browser)
      Button(String(appLocalized: "前进")) { model?.browser.goForward() }
        .keyboardShortcut("]", modifiers: .command)
        .disabled(model?.selection != .browser)
    }
  }
}
