import SwiftUI

enum NativeSettingsTab: String {
  case capture, shortcuts, voice, appearance, menuBar, monitor, assistant
  static let storageKey = "augma.settings.tab"
}

struct NativeAppSettingsView: View {
  @AppStorage(NativeSettingsTab.storageKey) private var selectedTab = NativeSettingsTab.capture
  @ObservedObject var monitor: SystemMonitorStore
  @ObservedObject var preferences: NativePreferencesStore
  @ObservedObject var immersiveShortcut: ImmersiveShortcutStore
  let menuBarShelf: MenuBarShelfStore
  let captures: QuickCaptureStore
  let navigation: NativeNavigationStore
  let sessions: DemoSessionRegistry
  let startVoiceInput: () -> Void

  var body: some View {
    TabView(selection: $selectedTab) {
      CaptureConnectionsView(captures: captures)
        .tabItem { Label("快速记录", systemImage: "square.and.pencil") }
        .tag(NativeSettingsTab.capture)
      ImmersiveShortcutSettingsView(store: immersiveShortcut, navigation: navigation, sessions: sessions)
        .tabItem { Label("窗口与快捷键", systemImage: "keyboard") }
        .tag(NativeSettingsTab.shortcuts)
      NativeVoiceSettingsView(start: startVoiceInput)
        .tabItem { Label("语音输入", systemImage: "mic") }
        .tag(NativeSettingsTab.voice)
      NativeScenePreferencesView(store: preferences)
        .tabItem { Label("外观与语言", systemImage: "viewfinder") }
        .tag(NativeSettingsTab.appearance)
      MenuBarShelfSettingsView(store: menuBarShelf)
        .tabItem { Label("菜单栏", systemImage: "menubar.rectangle") }
        .tag(NativeSettingsTab.menuBar)
      Form {
        Section("系统监控") {
          Toggle("启用系统监控", isOn: $monitor.enabled)
          SystemMonitorFeatureControls(store: monitor)
          Toggle("菜单栏显示监控摘要", isOn: $monitor.menuBarSummaryEnabled)
          Toggle("固定系统监控到 HUD", isOn: $monitor.hudPinned)
          Text("仅在监控面板、菜单栏摘要或 HUD 可见时采样；磁盘容量每 30 秒刷新，休眠时暂停。")
            .font(.caption).foregroundStyle(.secondary)
        }
      }
      .formStyle(.grouped)
      .contentMargins(NativePageLayout.pagePadding, for: .scrollContent)
      .tabItem { Label("系统监控", systemImage: "gauge.with.dots.needle.50percent") }
      .tag(NativeSettingsTab.monitor)
      AssistantSettingsView()
        .tabItem { Label("助手", systemImage: "sparkles") }
        .tag(NativeSettingsTab.assistant)
    }
    .controlSize(.regular)
    .frame(width: 540, height: 620)
  }
}
