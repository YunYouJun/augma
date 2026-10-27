import SwiftUI

struct NativeCommandView: View {
  @ObservedObject var store: NativeAssistantStore
  let commands: WorkspaceCommands
  @State private var previewsVoice = false
  private let examples = ["打开地图", "扫描空间", "打开天气", "播放声音", "打开浏览器", "打开深色模式", "隐藏 HUD"]

  var body: some View {
    ScrollView {
      page
        .nativePageContent()
    }
    .accessibilityIdentifier("native-assistant")
    .sheet(isPresented: $previewsVoice) { VoiceEffectPreview() }
    .alert(store.permission?.title ?? "", isPresented: Binding(get: { store.permission != nil }, set: { if !$0 { store.permission?.resolve(false) } })) {
      Button(store.text("允许一次")) { store.permission?.resolve(true) }
      Button(store.text("拒绝"), role: .cancel) { store.permission?.resolve(false) }
    }
  }

  private var page: some View {
    VStack(alignment: .leading, spacing: NativePageLayout.sectionSpacing) {
      section("语音助手") {
        voiceControls
        Divider()
        commandInput
        if hasResponse {
          Divider()
          response
        }
      }
      section("指令示例") {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), alignment: .leading)], alignment: .leading, spacing: 10) {
          ForEach(examples, id: \.self) { command in
            exampleButton(command)
          }
        }
        Text(store.text("还可打开通知、设置和摄像头面板，切换浅色模式，控制模拟路线，或暂停声音。打开摄像头面板不会开始拍摄。"))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      section("AI 助手") {
        Text(store.text("未匹配的问题会发送给所选 AI 运行时。DSH 管理模型上下文；原生工具仅提供已授权的系统摘要、应用占用与面板操作。"))
          .font(.caption).foregroundStyle(.secondary)
        SettingsLink { Label(store.text("AI 助手设置"), systemImage: "gearshape") }
      }
    }
  }

  private func exampleButton(_ command: String) -> some View {
    Button { store.submit(store.text(command)) } label: {
      Text(store.text(command))
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .padding(.vertical, 4)
    }
    .buttonStyle(.bordered)
    .disabled(store.isBusy)
  }

  private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    NativePageSection(title: Text(store.text(title)), content: content)
  }

  private var voiceControls: some View {
    VStack(spacing: 12) {
      VoiceActivityView(activity: store.voice)
      Text(store.text("点击开始说话，再次点击结束并执行；每次最多录音 12 秒，也可以直接输入指令。"))
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 440)
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 12) {
          recordingControls
          previewButton
        }
        .fixedSize(horizontal: true, vertical: false)
        VStack(spacing: 12) {
          recordingControls
          previewButton
        }
      }
      .controlSize(.large)
    }
    .frame(maxWidth: .infinity)
  }

  private var recordingControls: some View {
    HStack(spacing: 12) {
      Button(voiceButtonTitle, systemImage: store.phase == "listening" ? "stop.fill" : "mic.fill") { store.toggleVoice() }
        .buttonStyle(.borderedProminent)
        .disabled(!["idle", "listening"].contains(store.phase))
        .accessibilityIdentifier("native-assistant-record")
      if store.isBusy {
        Button(store.text("取消")) { store.cancel() }
          .accessibilityIdentifier("native-assistant-cancel")
      }
    }
  }

  @ViewBuilder private var previewButton: some View {
    if !store.isBusy {
      Button(store.text("预览语音动效"), systemImage: "waveform") { previewsVoice = true }
        .buttonStyle(.bordered)
    }
  }

  private var commandInput: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(store.text("输入指令")).font(.callout.weight(.medium))
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        TextField(store.text("输入指令"), text: $store.draft, prompt: Text(store.text("例如：打开地图，或记下 买咖啡豆")), axis: .vertical)
          .labelsHidden()
          .multilineTextAlignment(.leading)
          .lineLimit(1...4)
          .textFieldStyle(.roundedBorder)
          .frame(maxWidth: .infinity)
          .onSubmit { store.submit() }
          .disabled(store.isBusy)
          .accessibilityLabel(store.text("输入指令"))
          .accessibilityIdentifier("native-assistant-input")
        Button(store.text("执行")) { store.submit() }
          .fixedSize(horizontal: true, vertical: false)
          .disabled(store.isBusy || store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          .accessibilityIdentifier("native-assistant-submit")
      }
      .controlSize(.large)
    }
  }

  private var hasResponse: Bool {
    !store.transcript.isEmpty || !store.reply.isEmpty || !store.runtimeProgress.isEmpty || !store.error.isEmpty
  }

  private var response: some View {
    VStack(alignment: .leading, spacing: 12) {
      if !store.transcript.isEmpty { message(store.text("你"), text: store.transcript) }
      if !store.reply.isEmpty { message("Augma", text: store.reply) }
      if !store.runtimeProgress.isEmpty { Text(store.runtimeProgress).font(.caption).foregroundStyle(.secondary) }
      if !store.error.isEmpty { Text(store.error).foregroundStyle(.red).textSelection(.enabled) }
    }
  }

  private func message(_ title: String, text: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
      Text(text).textSelection(.enabled)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
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
