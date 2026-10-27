import SwiftUI

struct DemoContentView: View {
  @EnvironmentObject private var sessions: DemoSessionRegistry
  @Environment(\.openWindow) private var openWindow
  let appDelegate: HudAppDelegate
  @AppStorage(NativeWindowLayout.storageKey) private var layout = NativeWindowLayout.augma
  @AppStorage("demoWindowAlwaysOnTop") private var alwaysOnTop = false
  @StateObject private var model: NativeDemoModel
  @ObservedObject private var preferences: NativePreferencesStore

  init(appDelegate: HudAppDelegate) {
    self.appDelegate = appDelegate
    _model = StateObject(wrappedValue: NativeDemoModel(preferences: appDelegate.preferences, audio: appDelegate.audio,
                                                    commands: appDelegate.commands, applications: appDelegate.applicationDistrict,
                                                    projects: appDelegate.projectWorkspaces, navigation: appDelegate.navigation,
                                                    market: appDelegate.market))
    preferences = appDelegate.preferences
  }

  var body: some View {
    Group {
      if layout == .sidebar { sidebarLayout }
      else {
        AugmaWindowLayout(model: model, preferences: preferences, appDelegate: appDelegate,
                          switchLayout: { layout = .sidebar }) { detail }
      }
    }
    .navigationTitle("Augma")
    .navigationSubtitle(model.selection?.title ?? "")
    .frame(minWidth: 840, minHeight: 580)
    .focusedSceneValue(\.nativeDemo, model)
    .onAppear {
      sessions.register(model)
      appDelegate.openScene = { openWindow(id: $0) }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
      if let window = notification.object as? NSWindow, window === model.window {
        sessions.activate(model)
        appDelegate.mainWindowReady(model)
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
      if let window = notification.object as? NSWindow, window === model.window {
        if model.isImmersive { appDelegate.exitImmersive() }
        model.closeScene()
        sessions.unregister(model)
      }
    }
    .background {
      DemoWindowLevelView(alwaysOnTop: alwaysOnTop, onWindow: { window in
        model.window = window
        if window != nil { appDelegate.mainWindowReady(model) }
      })
        .frame(width: 0, height: 0)
    }
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        Button("返回首页", systemImage: "house") { model.goHome() }
          .help("返回首页（⇧⌘H）")
          .accessibilityIdentifier("main-go-home")
        Button("快速记录", systemImage: "square.and.pencil") {
          preferences.value.showHud = true
          model.selection = .notes
        }
        .help("快速记录（⇧⌘N）")
        .accessibilityIdentifier("main-quick-capture")
        Button("打开 Microsoft To Do", systemImage: "checklist") { appDelegate.captures.openDestination(.microsoftToDo) }
          .help("打开 Microsoft To Do（⌥⌘T）")
          .accessibilityIdentifier("main-open-todo")
      }
      ToolbarItem(placement: .primaryAction) {
        Button(layout == .augma ? "切换为侧栏布局" : "切换为 Augma 布局",
               systemImage: layout == .augma ? "sidebar.left" : "circle.grid.2x2") { layout = layout.toggled }
          .accessibilityIdentifier("main-layout-toggle")
          .keyboardShortcut("0", modifiers: [.command, .option])
      }
      if layout == .sidebar {
        ToolbarItemGroup(placement: .primaryAction) {
          Button {
            appDelegate.showCommands(voice: true)
          } label: {
            Label("语音指令", systemImage: "mic")
          }
          .help("开始或结束语音指令")
          Button("快捷指令", systemImage: "command") { appDelegate.showCommands() }
          Toggle(isOn: preferences.binding(\.showHud)) {
            Label("显示 HUD", systemImage: "viewfinder")
          }
          .toggleStyle(.button)
          .disabled(model.selection != .space)
        }
      }
      ToolbarItem(placement: .primaryAction) {
        Toggle(isOn: $alwaysOnTop) {
          Label("始终置顶", systemImage: "pin")
        }
        .toggleStyle(.button)
        .help("让演示窗口始终显示在其他普通窗口上方")
      }
      if layout == .sidebar {
        ToolbarItem(placement: .primaryAction) {
          Button {
            appDelegate.enterImmersive(model)
          } label: {
            Label("沉浸模式", systemImage: "rectangle.inset.filled.and.person.filled")
          }
          .help("将透明界面悬浮在桌面上")
        }
      }
    }
  }

  private var detail: some View {
    WorkspaceDetailView(model: model, store: appDelegate.workspace, commands: appDelegate.commands,
                        monitor: appDelegate.monitor, weather: appDelegate.weather,
                        preferences: preferences, audio: appDelegate.audio,
                        maps: appDelegate.maps, camera: appDelegate.camera)
  }

  private var sidebarLayout: some View {
    NavigationSplitView {
      List(selection: $model.selection) {
        Section("日常") {
          ForEach(DemoModule.productivity) { module in
            Label(module.title, systemImage: module.symbol).tag(module)
          }
        }
        Section("应用") {
          ForEach(DemoModule.dock) { module in
            Label(module.title, systemImage: module.symbol)
              .tag(module)
          }
        }
        Section("系统") {
          ForEach(DemoModule.system) { module in
            Label(module.title, systemImage: module.symbol)
              .tag(module)
          }
        }
      }
      .listStyle(.sidebar)
      .safeAreaInset(edge: .bottom) { SidebarBrand() }
      .navigationTitle("Augma")
      .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
    } detail: {
      detail
        .navigationTitle("Augma")
        .navigationSubtitle(model.selection?.title ?? "")
    }
    .navigationSplitViewStyle(.balanced)
  }
}

private struct SidebarBrand: View {
  var body: some View {
    HStack(spacing: 10) {
      AugmaRing(size: 28, spinning: false)
      VStack(alignment: .leading, spacing: 1) {
        Text("Augma")
          .font(.system(size: 13, weight: .semibold))
        Text("界面，浮现于现实。")
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }
}
