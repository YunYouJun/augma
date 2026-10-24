import AppKit
import Combine
import SwiftUI

/// Window-owned state survives the transition between the main and immersive UI.
/// Internal modules never create a web view; the browser owns its isolated session.
@MainActor
final class NativeDemoModel: ObservableObject {
  @Published var selection: DemoModule? = .notes {
    didSet {
      if oldValue == .commands, selection != .commands, !performingAssistantAction { assistant.cancel() }
    }
  }
  @Published private(set) var isImmersive = false
  weak var window: NSWindow?
  let preferences: NativePreferencesStore
  let audio: NativeAudioStore?
  let space: NativeSpaceStore
  let notifications: NativeNotificationStore
  let device: NativeDeviceStore
  let assistant: NativeAssistantStore
  let browser: NativeBrowserStore
  weak var commands: WorkspaceCommands?
  var performingAssistantAction = false
  private var observers: [AnyCancellable] = []
  private var closed = false

  init(preferences: NativePreferencesStore? = nil, audio: NativeAudioStore? = nil,
       space: NativeSpaceStore? = nil, commands: WorkspaceCommands? = nil, applications: ApplicationDistrictStore? = nil,
       projects: ProjectWorkspaceStore? = nil) {
    let preferences = preferences ?? NativePreferencesStore()
    self.preferences = preferences
    self.audio = audio
    self.space = space ?? NativeSpaceStore(applications: applications, projects: projects)
    self.commands = commands
    let notifications = NativeNotificationStore()
    self.notifications = notifications
    device = NativeDeviceStore(notifications: notifications)
    assistant = NativeAssistantStore(preferences: preferences)
    browser = NativeBrowserStore()
    assistant.performAction = { [weak self] action in
      self?.performAssistantAction(action) ?? NativeAssistantResult(message: String(localized: "窗口已关闭。"), isError: true)
    }
    assistant.performWorkspaceCommand = { [weak self] command in
      self?.performAssistantWorkspaceCommand(command) ?? NativeAssistantResult(message: String(localized: "窗口已关闭。"), isError: true)
    }
    device.onSuspend = { [weak self] in
      self?.space.cancelScan()
      self?.space.cancelRoute()
      self?.assistant.cancel()
    }
    observeSpaceActivity()
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
        self?.notifications.post(title: String(localized: "模拟扫描完成"),
                                 detail: String(localized: "可以选择地标并固定虚拟锚点。"), symbol: "viewfinder")
      }.store(in: &observers)
    space.$sceneID.removeDuplicates().dropFirst().sink { [weak self] scene in
      guard let self else { return }
      self.notifications.post(title: String(localized: "已切换空间场景"),
                              detail: NativeSpaceScene.scene(for: scene).title(locale: self.preferences.locale), symbol: "square.3.layers.3d")
    }.store(in: &observers)
    space.$pinnedLandmarkID.removeDuplicates().dropFirst().compactMap { $0 }.sink { [weak self] id in
      guard let self, let landmark = self.space.scene.landmarks.first(where: { $0.id == id }) else { return }
      self.notifications.post(title: String(localized: "已固定虚拟锚点"),
                              detail: landmark.title(locale: self.preferences.locale), symbol: "pin")
    }.store(in: &observers)
    space.$routeStep.removeDuplicates().dropFirst().filter { $0 == 4 }.sink { [weak self] _ in
      guard let self else { return }
      self.notifications.post(title: String(localized: "已到达模拟目的地"),
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
    CommandMenu("应用") {
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
    CommandMenu("网页") {
      Button("输入网址或搜索") { model?.browser.focusAddress() }
        .keyboardShortcut("l", modifiers: .command)
        .disabled(model?.selection != .browser)
      Button("重新载入") { model?.browser.reloadOrStop() }
        .keyboardShortcut("r", modifiers: .command)
        .disabled(model?.selection != .browser)
      Button("后退") { model?.browser.goBack() }
        .keyboardShortcut("[", modifiers: .command)
        .disabled(model?.selection != .browser)
      Button("前进") { model?.browser.goForward() }
        .keyboardShortcut("]", modifiers: .command)
        .disabled(model?.selection != .browser)
    }
  }
}
