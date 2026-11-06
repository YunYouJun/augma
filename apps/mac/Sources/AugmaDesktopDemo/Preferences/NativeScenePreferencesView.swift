import SwiftUI

struct NativeScenePreferencesView: View {
  @ObservedObject var store: NativePreferencesStore
  @State private var confirmsReset = false
  @AppStorage(NativeSettingsTab.storageKey) private var selectedSettingsTab = NativeSettingsTab.capture
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    Form {
      Section("语言") {
        Picker("应用语言", selection: store.binding(\.locale)) {
          ForEach(NativeSceneLanguage.allCases) { language in
            Text(language.displayName).tag(language.rawValue)
          }
        }
        .accessibilityIdentifier("app-language")
        Text("语言即时应用到所有窗口、菜单及内置插件，并在重启后保留。")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section("场景外观") {
        Toggle("深色场景", isOn: store.binding(\.dark))
        Toggle("专注模式", isOn: store.binding(\.focus))
        Toggle("场景背景", isOn: store.binding(\.sceneBackdrop))
        Text("这些设置用于模拟场景；应用窗口与原生控件外观跟随 macOS。")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section("HUD") {
        Toggle("显示 HUD", isOn: store.binding(\.showHud))
        Toggle("显示顶部时钟", isOn: $store.showsClock)
          .accessibilityIdentifier("hud-clock-enabled")
        Text("在 Augma 布局和沉浸模式中显示时间，默认关闭。")
          .font(.caption).foregroundStyle(.secondary)
        LabeledContent("不透明度") {
          HStack(spacing: NativePageLayout.itemSpacing) {
            Slider(value: store.binding(\.opacity), in: 60...100, step: 1) {
              Text("不透明度")
            }
            .labelsHidden()
            .accessibilityLabel("不透明度")
            Text("\(Int(store.value.opacity))%")
              .monospacedDigit().foregroundStyle(.secondary)
              .frame(width: 42, alignment: .trailing)
          }
          .frame(minWidth: 120, idealWidth: 180, maxWidth: 240)
        }
        Toggle("镜像画面", isOn: store.binding(\.mirror))
        Toggle("景深动效", isOn: store.binding(\.depthMotion))
        Toggle("曲面 HUD", isOn: store.binding(\.curvedHud))
      }
      Section("语音与快捷键") {
        Button("语音输入设置…") {
          selectedSettingsTab = .voice
          openSettings()
        }
        .accessibilityIdentifier("open-voice-input-settings")
        Toggle("指令语音反馈", isOn: store.binding(\.speechFeedback))
        Text("使用 ⌘1–⌘9 切换应用；语音快捷键可在 macOS 的 App 快捷键中修改。")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section("Dock") {
        LabeledContent("底部间距") {
          HStack(spacing: NativePageLayout.itemSpacing) {
            Slider(value: $store.dockBottomInset, in: NativePreferencesStore.dockBottomInsetRange, step: 1) {
              Text("底部间距")
            }
            .labelsHidden()
            .accessibilityLabel("底部间距")
            .accessibilityIdentifier("dock-bottom-inset")
            Text("\(Int(store.dockBottomInset)) pt")
              .monospacedDigit().foregroundStyle(.secondary)
              .frame(width: 52, alignment: .trailing)
          }
          .frame(minWidth: 120, idealWidth: 180, maxWidth: 240)
        }
        Button("与顶部间距一致") { store.dockBottomInset = Double(ImmersiveLayout.defaultDockBottomInset) }
          .accessibilityIdentifier("dock-bottom-inset-reset")
        Text("调整 Augma 布局和沉浸模式的底部 Dock 间距。沉浸模式以屏幕可用区域为准，避开系统 Dock；默认与顶部控件到菜单栏的间距一致。")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section {
        Button("恢复场景默认设置") { confirmsReset = true }
          .confirmationDialog("恢复场景默认设置？", isPresented: $confirmsReset, titleVisibility: .visible) {
            Button("恢复默认设置", role: .destructive) { store.reset() }
            Button("取消", role: .cancel) {}
          } message: {
            Text("恢复场景外观、HUD 和语言偏好；笔记、助手配置、系统监控与音频设置保持不变。")
          }
      }
    }
    .formStyle(.grouped)
    .controlSize(.regular)
  }
}
