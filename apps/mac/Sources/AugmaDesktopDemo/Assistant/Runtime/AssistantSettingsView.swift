import SwiftUI

struct AssistantSettingsView: View {
  @AppStorage(AssistantRuntimeSettings.backendKey) private var selectedBackend = ""
  @AppStorage(AssistantRuntimeSettings.enabledKey) private var enabled = false
  @AppStorage(AssistantRuntimeSettings.executableKey) private var executable = ""
  @AppStorage(AssistantRuntimeSettings.modelKey) private var model = ""
  @AppStorage(AssistantRuntimeSettings.reasoningKey) private var reasoning = ""
  @AppStorage(AssistantRuntimeSettings.testedKey) private var tested = ""
  @ObservedObject private var runtime = NativeAssistantRuntime.shared
  @ObservedObject private var magpieConfiguration = AssistantMagpieConfiguration.shared
  @State private var configOptions: [AssistantConfigOption] = []
  @State private var feedback = ""
  @State private var busy = false
  @State private var task: Task<Void, Never>?
  @State private var owner = UUID()
  @State private var operation = UUID()

  private var backend: AssistantBackend { AssistantBackend(rawValue: selectedBackend) ?? AssistantRuntimeSettings.backend() }
  private var testedCurrent: Bool { tested == AssistantRuntimeSettings.fingerprint() }

  var body: some View {
    VStack(spacing: 0) {
      Picker("AI 运行时", selection: Binding(get: { backend }, set: { selectedBackend = $0.rawValue; changed() })) {
        Text("DSH / Magpie").tag(AssistantBackend.dsh)
        Text("DeepSeek API（兼容）").tag(AssistantBackend.deepseek)
      }
      .pickerStyle(.segmented)
      .padding(.horizontal, NativePageLayout.pagePadding)
      .padding(.top, NativePageLayout.pagePadding)
      .padding(.bottom, NativePageLayout.itemSpacing)
      .accessibilityIdentifier("assistant-runtime-picker")
      .disabled(magpieConfiguration.isManaged)
      if magpieConfiguration.isManaged {
        Text("模型和推理强度由 Magpie 管理。修改后返回 Augma，测试通过即可启用；断开管理会恢复原配置。")
          .font(.caption).foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, NativePageLayout.pagePadding)
          .padding(.bottom, NativePageLayout.itemSpacing)
      }
      if !magpieConfiguration.failure.isEmpty {
        Text(magpieConfiguration.failure).font(.caption).foregroundStyle(.red)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, NativePageLayout.pagePadding)
          .padding(.bottom, NativePageLayout.itemSpacing)
      }
      if backend == .deepseek { DeepSeekSettingsView() }
      else {
        Form {
          Section("AI 助手") {
            Toggle("启用 DSH 助手", isOn: $enabled)
              .disabled(!testedCurrent || busy)
              .onChange(of: enabled) { _, _ in AssistantRuntimeSettings.notifyChange() }
              .accessibilityIdentifier("assistant-dsh-enabled")
            Text("文字与语音只在本地指令未匹配时发送给 DSH，经 Magpie 使用所选模型。工具可读取系统摘要和应用名称与占用，或打开你请求的面板。清理建议仍仅发送确认后的匿名摘要。")
              .font(.caption).foregroundStyle(.secondary)
          }
          Section("DSH 连接") {
            VStack(alignment: .leading, spacing: 8) {
              Text("DSH 可执行文件").font(.callout.weight(.medium))
              TextField("DSH 可执行文件", text: $executable, prompt: Text("自动检测已安装的 DSH"))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("DSH 可执行文件")
                .accessibilityIdentifier("assistant-dsh-path")
                .onChange(of: executable) { _, _ in changed() }
            }
            Text("支持 DSH 0.2.0-rc.2。使用 Augma 专属隔离配置，不修改 DSH 桌面配置。Magpie 的登录、订阅和路由在 Magpie 中管理。")
              .font(.caption).foregroundStyle(.secondary)
            Button("检测连接与模型", systemImage: "arrow.clockwise") { discover() }
              .disabled(busy)
              .accessibilityIdentifier("assistant-dsh-detect")
            if let models = configOptions.first(where: { $0.id == "model" }) {
              Picker("模型", selection: $model) {
                ForEach(models.choices) { choice in
                  Text(choice.name + " · " + Self.modelID(choice.id)).tag(Self.modelID(choice.id))
                }
              }
              .onChange(of: model) { _, _ in
                if !magpieConfiguration.hasModel(model) { reasoning = ""; changed() }
              }
              .disabled(magpieConfiguration.isManaged)
            } else if !model.isEmpty {
              VStack(alignment: .leading, spacing: 4) {
                Text("模型").font(.caption).foregroundStyle(.secondary)
                Text(model).lineLimit(3).textSelection(.enabled)
              }
            }
            if let effort = configOptions.first(where: { $0.id == "reasoning_effort" }) {
              Picker("推理选项", selection: $reasoning) {
                Text("默认").tag("")
                ForEach(effort.choices) { choice in Text(choice.name).tag(choice.id) }
              }
              .onChange(of: reasoning) { _, _ in
                if !magpieConfiguration.hasEffort(reasoning) { changed() }
              }
              .disabled(magpieConfiguration.isManaged)
              Text("切换模型后重新检测，以读取该模型公布的推理选项。")
                .font(.caption).foregroundStyle(.secondary)
            }
          }
          Section("测试") {
            Text("测试会发送一条请求及真实系统摘要、应用名称与占用，核对模型和工具往返；可能消耗模型额度。通过后可单独启用助手。")
              .font(.caption).foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
              HStack(spacing: NativePageLayout.itemSpacing) { testActions }
                .fixedSize(horizontal: true, vertical: false)
              VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) { testActions }
            }
            if !feedback.isEmpty { Text(feedback).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
            if !runtime.status.isEmpty, runtime.status != feedback { Text(runtime.status).font(.caption).foregroundStyle(.secondary) }
          }
        }
        .formStyle(.grouped)
        .contentMargins(.horizontal, NativePageLayout.pagePadding, for: .scrollContent)
        .contentMargins(.top, NativePageLayout.itemSpacing, for: .scrollContent)
        .contentMargins(.bottom, NativePageLayout.pagePadding, for: .scrollContent)
      }
    }
    .controlSize(.regular)
    .onDisappear { cancel() }
    .onAppear { magpieConfiguration.refresh() }
  }

  @ViewBuilder private var testActions: some View {
    Button("测试模型与只读工具") { test() }
      .disabled(busy || model.isEmpty)
      .accessibilityIdentifier("assistant-dsh-test")
    if busy {
      ProgressView().controlSize(.small)
      Button("取消") { cancel() }
    }
  }

  private static func modelID(_ value: String) -> String {
    guard let data = value.data(using: .utf8), let parts = try? JSONDecoder().decode([String].self, from: data),
      parts.count == 2, parts[0] == "magpie" else { return "" }
    return parts[1]
  }
  private func changed() {
    cancel()
    tested = ""; enabled = false
    feedback = ""
    magpieConfiguration.saveLocal()
    AssistantRuntimeSettings.notifyChange()
  }
  private func cancel() {
    operation = UUID()
    task?.cancel(); task = nil; busy = false
    runtime.cancel(owner: owner)
  }
  private func discover() {
    cancel(); busy = true; feedback = ""
    let token = operation
    task = Task {
      defer { if operation == token { busy = false } }
      do {
        let options = try await runtime.discoverOptions()
        try Task.checkCancellation()
        configOptions = options
        if model.isEmpty, let current = options.first(where: { $0.id == "model" })?.current { model = Self.modelID(current) }
        feedback = String(localized: "已读取 DSH 会话的模型选项。可测试后启用。")
      } catch {
        if !Task.isCancelled { feedback = (error as? AssistantRuntimeError)?.localizedDescription ?? AssistantRuntimeError.launchFailed.localizedDescription }
      }
    }
  }
  private func test() {
    cancel(); busy = true; feedback = ""; owner = UUID()
    let token = operation
    let testOwner = owner, fingerprint = AssistantRuntimeSettings.fingerprint()
    let scope = NativeToolScope()
    task = Task {
      defer { runtime.cancel(owner: testOwner); if operation == token { busy = false } }
      do {
        _ = try await runtime.complete(messages: [
          ["role": "system", "content": "This is an Augma connection test. Use both system_summary and application_usage tools once. After receiving both results, reply with one short sentence acknowledging the read-only test. Do not open panels."],
          ["role": "user", "content": "Test the model and both native read-only tools."],
        ], owner: testOwner, scope: scope, testing: true)
        try Task.checkCancellation()
        guard scope.successfulTools.isSuperset(of: ["system_summary", "application_usage"]), fingerprint == AssistantRuntimeSettings.fingerprint() else {
          throw AssistantRuntimeError.taskFailed
        }
        tested = fingerprint
        feedback = String(localized: "模型与两项只读工具测试通过。现在可以启用助手。")
      } catch {
        if !Task.isCancelled { feedback = (error as? AssistantRuntimeError)?.localizedDescription ?? AssistantRuntimeError.taskFailed.localizedDescription }
      }
    }
  }
}
