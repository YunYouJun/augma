import SwiftUI

struct NativeCommandView: View {
  @ObservedObject var store: NativeAssistantStore
  let commands: WorkspaceCommands
  @State private var previewsVoice = false
  private let examples = ["打开地图", "扫描空间", "打开天气", "播放声音", "打开浏览器", "打开深色模式", "隐藏 HUD"]

  var body: some View {
    Form {
      Section(store.text("语音助手")) {
        VoiceActivityView(activity: store.voice)
        Text(store.text("点击开始说话，再次点击结束并执行；每次最多录音 12 秒，也可以直接输入指令。"))
          .font(.caption)
          .foregroundStyle(.secondary)
        HStack {
          Button(voiceButtonTitle, systemImage: store.phase == "listening" ? "stop.fill" : "mic.fill") { store.toggleVoice() }
            .buttonStyle(.borderedProminent)
            .disabled(!["idle", "listening"].contains(store.phase))
            .accessibilityIdentifier("native-assistant-record")
          if store.isBusy {
            Button(store.text("取消")) { store.cancel() }
              .accessibilityIdentifier("native-assistant-cancel")
          }
        }
        HStack(alignment: .top) {
          TextField(store.text("输入指令"), text: $store.draft, prompt: Text(store.text("例如：打开地图，或记下 买咖啡豆")), axis: .vertical)
            .lineLimit(1...4)
            .textFieldStyle(.roundedBorder)
            .onSubmit { store.submit() }
            .disabled(store.isBusy)
            .accessibilityIdentifier("native-assistant-input")
          Button(store.text("执行")) { store.submit() }
            .disabled(store.isBusy || store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("native-assistant-submit")
        }
        if !store.transcript.isEmpty {
          LabeledContent(store.text("你")) { Text(store.transcript).textSelection(.enabled) }
        }
        if !store.reply.isEmpty {
          LabeledContent("Augma") { Text(store.reply).textSelection(.enabled) }
        }
        if !store.error.isEmpty {
          Text(store.error).foregroundStyle(.red).textSelection(.enabled)
        }
        if !store.isBusy {
          Button(store.text("预览语音动效"), systemImage: "waveform") { previewsVoice = true }
            .sheet(isPresented: $previewsVoice) { VoiceEffectPreview() }
        }
      }
      Section(store.text("指令示例")) {
        ForEach(examples, id: \.self) { command in
          Button(store.text(command)) { store.submit(store.text(command)) }
            .disabled(store.isBusy)
        }
        Text(store.text("还可打开通知、设置和摄像头面板，切换浅色模式，控制模拟路线，或暂停声音。打开摄像头面板不会开始拍摄。"))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Section(store.text("DeepSeek 助手")) {
        Text(store.text(store.assistantReady
          ? "未匹配的指令和问题会连同最近四轮对话发送给 DeepSeek。"
          : "在 Augma 设置中启用 DeepSeek 助手后，可处理其他指令和问题。"))
          .font(.caption)
          .foregroundStyle(.secondary)
        SettingsLink { Label(store.text("DeepSeek 助手"), systemImage: "gearshape") }
      }
    }
    .formStyle(.grouped)
    .accessibilityIdentifier("native-assistant")
  }

  private var voiceButtonTitle: String {
    switch store.phase {
    case "requesting": store.text("正在申请权限…")
    case "listening": store.text("结束并执行")
    case "processing": store.text("正在识别…")
    case "interpreting": store.text("正在理解指令…")
    default: store.text("开始语音识别")
    }
  }
}
