import SwiftUI

struct NativeVoiceSettingsView: View {
  @AppStorage(VoiceInputProvider.storageKey) private var provider = VoiceInputProvider.apple
  @AppStorage(WeChatVoiceInput.Trigger.holdStorageKey) private var weChatTrigger = WeChatVoiceInput.Trigger.controlFn
  @AppStorage(WeChatVoiceShortcut.storageKey) private var shortcut = WeChatVoiceShortcut.defaultValue
  let start: () -> Void

  var body: some View {
    Form {
      Section("语音输入") {
        Picker("识别方式", selection: $provider) {
          ForEach(VoiceInputProvider.allCases) { provider in Text(provider.title).tag(provider) }
        }
        .accessibilityIdentifier("voice-input-provider")
        if provider == .apple {
          Text("使用 macOS 原生语音识别。首次启动需允许麦克风与语音识别权限。")
            .font(.caption).foregroundStyle(.secondary)
          Text("识别文字填入快捷指令输入框，确认后再执行；点击面板中的结束按钮可完成输入。")
            .font(.caption).foregroundStyle(.secondary)
        } else {
          Picker("微信语音输入快捷键", selection: $weChatTrigger) {
            ForEach(WeChatVoiceInput.Trigger.allCases) { trigger in Text(trigger.title).tag(trigger) }
          }
          .accessibilityIdentifier("wechat-voice-trigger")
          Text("微信需保持登录，控制范围设为所有窗口；上方选择需与微信的语音输入快捷键一致。")
            .font(.caption).foregroundStyle(.secondary)
        }
        Button("开始语音输入", systemImage: "mic", action: start)
          .accessibilityIdentifier("voice-input-start")
      }
      Section("快捷键") {
        LabeledContent("唤起快捷键") {
          WeChatVoiceShortcutRecorder(shortcut: $shortcut).frame(width: 210, height: 28)
        }
        Button("恢复默认快捷键") { shortcut = .defaultValue }
        Text("按住自定义快捷键开始输入，松开结束；点击快捷键按钮可改绑，Esc 取消录制。")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .contentMargins(NativePageLayout.pagePadding, for: .scrollContent)
  }
}
