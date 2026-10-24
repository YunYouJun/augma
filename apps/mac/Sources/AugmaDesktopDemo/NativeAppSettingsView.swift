import SwiftUI

struct NativeAppSettingsView: View {
  @ObservedObject var monitor: SystemMonitorStore
  @ObservedObject var preferences: NativePreferencesStore
  @ObservedObject var immersiveShortcut: ImmersiveShortcutStore
  let captures: QuickCaptureStore

  var body: some View {
    TabView {
      CaptureConnectionsView(captures: captures)
        .tabItem { Label("快速记录", systemImage: "square.and.pencil") }
      ImmersiveShortcutSettingsView(store: immersiveShortcut)
        .tabItem { Label("窗口与快捷键", systemImage: "keyboard") }
      NativeScenePreferencesView(store: preferences)
        .tabItem { Label("场景", systemImage: "viewfinder") }
      Form {
        Section("系统监控") {
          Picker("刷新间隔", selection: $monitor.sampleInterval) {
            Text("1 秒").tag(1.0)
            Text("2 秒").tag(2.0)
            Text("5 秒").tag(5.0)
          }
          Toggle("菜单栏显示监控摘要", isOn: $monitor.menuBarSummaryEnabled)
          Toggle("固定系统监控到 HUD", isOn: $monitor.hudPinned)
          Text("仅在监控面板、菜单栏摘要或 HUD 可见时采样；磁盘容量每 30 秒刷新，休眠时暂停。")
            .font(.caption).foregroundStyle(.secondary)
        }
      }
      .formStyle(.grouped)
      .tabItem { Label("系统监控", systemImage: "gauge.with.dots.needle.50percent") }
      DeepSeekSettingsView()
        .tabItem { Label("助手", systemImage: "sparkles") }
    }
    .frame(width: 540, height: 620)
    .padding()
  }
}
