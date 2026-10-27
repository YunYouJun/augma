import SwiftUI

struct ImmersiveAssistantCommands: Commands {
  @ObservedObject var store: ImmersiveShortcutStore
  let toggle: () -> Void

  var body: some Commands {
    CommandMenu("沉浸助手") {
      Button("唤起／隐藏沉浸助手", action: toggle)
        .keyboardShortcut(menuShortcut)
      SettingsLink { Text("配置全局快捷键…") }
    }
  }

  private var menuShortcut: KeyboardShortcut? {
    switch store.shortcut {
    case .controlOptionA: KeyboardShortcut("a", modifiers: [.control, .option])
    case .controlOptionCommandSpace: KeyboardShortcut(.space, modifiers: [.control, .option, .command])
    case .disabled: nil
    }
  }
}

struct ImmersiveShortcutSettingsView: View {
  @ObservedObject var store: ImmersiveShortcutStore
  @AppStorage(NativeWindowLayout.storageKey) private var layout = NativeWindowLayout.augma
  let navigation: NativeNavigationStore
  let sessions: DemoSessionRegistry

  var body: some View {
    Form {
      NativeStartupSettingsView(store: navigation, sessions: sessions)
      Section("主窗口布局") {
        Picker("窗口布局", selection: $layout) {
          Text("Augma 布局").tag(NativeWindowLayout.augma)
          Text("侧栏布局").tag(NativeWindowLayout.sidebar)
        }
        Text("两种布局共享应用状态；也可按 ⌥⌘0 切换。")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section("沉浸助手") {
        Picker("全局唤起／隐藏", selection: $store.shortcut) {
          ForEach(ImmersiveShortcut.allCases) { shortcut in Text(shortcut.title).tag(shortcut) }
        }
        .accessibilityIdentifier("immersive-global-shortcut")
        Text("Augma 运行时，在其他应用中也可使用。再次按下隐藏助手，保留当前面板和内容；Esc 或右上退出按钮返回主窗口。")
          .font(.caption).foregroundStyle(.secondary)
        if let error = store.registrationError {
          Label("快捷键注册失败，可能已被其他应用占用。请更换组合或重试。", systemImage: "exclamationmark.triangle")
            .foregroundStyle(.orange)
          Text(String(format: String(localized: "系统错误码：%d"), error)).font(.caption)
          Button("重新注册快捷键", action: store.refresh)
        }
      }
    }
    .formStyle(.grouped)
    .controlSize(.regular)
    .contentMargins(NativePageLayout.pagePadding, for: .scrollContent)
  }
}
