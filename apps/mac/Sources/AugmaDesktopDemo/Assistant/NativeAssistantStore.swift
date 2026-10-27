import AppKit
import AVFoundation
import Combine
import Foundation

/// A window owns one assistant and lends it to both native presentations.
/// Neither the prompt nor conversation history comes from a web page.
@MainActor
final class NativeAssistantStore: ObservableObject {
  typealias Completion = @Sendable ([[String: String]], String) async throws -> String

  @Published var draft = "" {
    didSet {
      if draft.count > NativeAssistantConversation.maxQuestionLength {
        draft = String(draft.prefix(NativeAssistantConversation.maxQuestionLength))
      }
    }
  }
  @Published private(set) var transcript = ""
  @Published private(set) var reply = ""
  @Published private(set) var error = ""
  @Published private(set) var phase = "idle"
  @Published private(set) var runtimeProgress = ""
  @Published private(set) var permission: AssistantPermission?
  private let runtimeOwner = UUID()
  private let toolScope = NativeToolScope()
  private let usesRuntime: Bool
  @Published private(set) var assistantReady: Bool
  let voice = VoiceActivityModel()
  let preferences: NativePreferencesStore
  var performAction: ((NativeAssistantAction) -> NativeAssistantResult)?
  var performWorkspaceCommand: ((WorkspaceCommand) -> NativeAssistantResult)?
  var performCleanupRequest: ((String) -> NativeAssistantResult)?
  private(set) var history: [NativeAssistantTurn] = []

  var isBusy: Bool { phase != "idle" }
  private let completion: Completion
  private let keyProvider: () -> String?
  private let feedbackSpeaker: ((String, String) -> Void)?
  private let synthesizer = AVSpeechSynthesizer()
  private var request: Task<Void, Never>?
  private var recordingStart: Task<Void, Never>?
  private var generation = 0
  private var closed = false
  private var observers: [AnyCancellable] = []
  private lazy var recognizer = SpeechCommandRecognizer(onLevel: { [weak self] level in
    self?.voice.receive(level: level)
  }, onEvent: { [weak self] type, text, code in
    self?.receiveSpeech(type: type, text: text, code: code)
  })

  init(
    preferences: NativePreferencesStore,
    keyProvider: (() -> String?)? = nil,
    completion: Completion? = nil,
    feedbackSpeaker: ((String, String) -> Void)? = nil
  ) {
    self.preferences = preferences
    usesRuntime = keyProvider == nil && completion == nil
    self.keyProvider = keyProvider ?? { DeepSeekSettings.isReady ? DeepSeekKeychain.load() : nil }
    self.completion = completion ?? { try await DeepSeekClient.complete($0, apiKey: $1) }
    self.feedbackSpeaker = feedbackSpeaker
    assistantReady = usesRuntime ? AssistantRuntimeSettings.isReady : self.keyProvider() != nil
    if usesRuntime {
      NativeAssistantRuntime.shared.$permission.sink { [weak self] value in
        guard let self else { return }
        self.permission = value?.owner == self.runtimeOwner ? value : nil
      }.store(in: &observers)
    }
    NotificationCenter.default.publisher(for: .augmaDeepSeekConfigChanged)
      .sink { [weak self] _ in self?.refreshConfiguration() }.store(in: &observers)
    NotificationCenter.default.publisher(for: .augmaCancelSpeech)
      .sink { [weak self] _ in self?.cancel() }.store(in: &observers)
    NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
      .sink { [weak self] _ in self?.cancel() }.store(in: &observers)
    NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)
      .merge(with: NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidSleepNotification))
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in self?.cancel() }.store(in: &observers)
    preferences.$value.map(\.locale).removeDuplicates().dropFirst()
      .sink { [weak self] _ in
        self?.cancel()
        self?.history = []
        self?.objectWillChange.send()
      }.store(in: &observers)
    preferences.$value.map(\.speechFeedback).removeDuplicates().dropFirst()
      .sink { [weak self] enabled in
        if !enabled { self?.synthesizer.stopSpeaking(at: .immediate) }
      }.store(in: &observers)
  }

  /// Resolve the selected UI language without depending on JavaScript labels.
  func text(_ key: String) -> String {
    let language = preferences.locale.hasPrefix("en") ? "en" : preferences.locale.hasPrefix("ja") ? "ja" : "zh-Hans"
    let bundle = Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    return bundle.localizedString(forKey: key, value: key, table: nil)
  }

  func submit(_ suppliedText: String? = nil) {
    guard !closed else { return }
    let question = (suppliedText ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
    cancel()
    transcript = question
    reply = ""
    error = ""
    guard !question.isEmpty, question.count <= NativeAssistantConversation.maxQuestionLength else {
      fail(text("请输入 1 至 500 字的指令。"))
      return
    }
    draft = ""
    let workspaceCommand = WorkspaceCommand.parse(question)
    // Capturing a note must not execute commands embedded in the note text.
    if let workspaceCommand, let performWorkspaceCommand {
      switch workspaceCommand {
      case .note, .task:
        finish(performWorkspaceCommand(workspaceCommand))
        return
      default: break
      }
    }
    let match = NativeAssistantCommandParser.match(question)
    if match == .refused {
      finish(.init(message: text("已保留当前状态。")))
      return
    }
    if DiskCleanupGoal.parse(question) != nil, let performCleanupRequest {
      finish(performCleanupRequest(question))
      return
    }
    if let workspaceCommand, let performWorkspaceCommand {
      finish(performWorkspaceCommand(workspaceCommand))
      return
    }
    if case .action(let action) = match {
      execute(action)
      return
    }
    if usesRuntime {
      guard AssistantRuntimeSettings.isReady else {
        assistantReady = false
        fail(AssistantRuntimeError.notEnabled.localizedDescription)
        return
      }
      assistantReady = true
      if AssistantRuntimeSettings.backend() == .dsh { askRuntime(question); return }
      ask(question, key: "")
      return
    }
    guard let key = keyProvider() else {
      assistantReady = false
      fail(text("未识别这条指令。可尝试示例，或在设置中启用 DeepSeek 助手。"))
      return
    }
    assistantReady = true
    ask(question, key: key)
  }

  func toggleVoice() {
    guard !closed else { return }
    switch phase {
    case "listening": recognizer.stop()
    case "requesting", "processing", "interpreting": cancel()
    default:
      NotificationCenter.default.post(name: .augmaCancelNativeSpeech, object: nil)
      // Stop another window's assistant before starting this one.
      NotificationCenter.default.post(name: .augmaCancelSpeech, object: nil)
      transcript = ""
      reply = ""
      error = ""
      setPhase("requesting")
      let token = generation
      recordingStart = Task { [weak self] in
        guard let self, !self.closed, self.generation == token else { return }
        await self.recognizer.start(localeIdentifier: self.preferences.locale, maximumDuration: 12)
      }
    }
  }

  func cancel() {
    generation += 1
    if usesRuntime, request != nil { NativeAssistantRuntime.shared.cancel(owner: runtimeOwner) }
    toolScope.revoke()
    runtimeProgress = ""
    request?.cancel()
    request = nil
    recordingStart?.cancel()
    recordingStart = nil
    recognizer.cancel()
    synthesizer.stopSpeaking(at: .immediate)
    setPhase("idle")
  }

  func shutdown() {
    closed = true
    cancel()
    history = []
    if usesRuntime { NativeAssistantRuntime.shared.cancel(owner: runtimeOwner) }
    observers.removeAll()
  }

  private func refreshConfiguration() {
    cancel()
    history = []
    if usesRuntime { NativeAssistantRuntime.shared.cancel(owner: runtimeOwner) }
    assistantReady = usesRuntime ? AssistantRuntimeSettings.isReady : keyProvider() != nil
  }

  private func ask(_ question: String, key: String) {
    let messages: [[String: String]]
    do {
      messages = try NativeAssistantConversation.messages(question: question, locale: preferences.locale, history: history)
    } catch {
      fail(text("请输入 1 至 500 字的指令。"))
      return
    }
    setPhase("interpreting")
    let token = generation
    let complete = completion
    request = Task { [weak self] in
      do {
        let content: String
        if let self, self.usesRuntime {
          content = try await NativeAssistantRuntime.shared.complete(messages: messages, owner: self.runtimeOwner)
        } else {
          content = try await complete(messages, key)
        }
        guard !Task.isCancelled, let self, !self.closed, self.generation == token else { return }
        let answer = try NativeAssistantConversation.parse(content)
        self.request = nil
        self.setPhase("idle")
        self.history.append(.init(question: question, answer: answer))
        self.history = Array(self.history.suffix(NativeAssistantConversation.historyLimit))
        if let action = answer.command { self.execute(action) }
        else { self.finish(.init(message: answer.reply)) }
      } catch {
        guard !Task.isCancelled, let self, !self.closed, self.generation == token else { return }
        self.request = nil
        self.fail(self.completionError(error))
      }
    }
  }

  private func askRuntime(_ question: String) {
    setPhase("interpreting")
    runtimeProgress = text("正在连接 DSH…")
    let token = generation
    toolScope.openPanel = { [weak self] action in
      guard let self, !self.closed, self.generation == token, let perform = self.performAction else {
        return NativeAssistantResult(message: "Window unavailable", isError: true)
      }
      return perform(action)
    }
    request = Task { [weak self] in
      guard let self else { return }
      do {
        let messages = [
          ["role": "system", "content": "Answer in \(self.preferences.locale). Return JSON only: {\"reply\": string, \"command\": null}. Reply in at most 600 characters. Native tools provide real system data and can open requested panels. Only report actual tool outcomes. Do not invent readings. For advice use memory pressure, not just high RAM usage."],
          ["role": "user", "content": question],
        ]
        let content = try await NativeAssistantRuntime.shared.complete(messages: messages, owner: self.runtimeOwner,
          scope: self.toolScope, onEvent: { [weak self] status in
            guard self?.generation == token else { return }; self?.runtimeProgress = status
          })
        guard !Task.isCancelled, !self.closed, self.generation == token else { return }
        let answer = try NativeAssistantConversation.parse(content)
        guard answer.command == nil else { throw AssistantRuntimeError.protocolViolation }
        self.history.append(.init(question: question, answer: answer))
        self.history = Array(self.history.suffix(NativeAssistantConversation.historyLimit))
        self.request = nil; self.runtimeProgress = ""
        self.finish(.init(message: answer.reply))
      } catch {
        guard !Task.isCancelled, !self.closed, self.generation == token else { return }
        self.request = nil; self.runtimeProgress = ""
        self.fail((error as? AssistantRuntimeError)?.localizedDescription ?? AssistantRuntimeError.taskFailed.localizedDescription)
      }
    }
  }

  private func execute(_ action: NativeAssistantAction) {
    guard let performAction else {
      fail(text("当前无法执行这条指令。"))
      return
    }
    finish(performAction(action))
  }

  private func finish(_ result: NativeAssistantResult) {
    setPhase("idle")
    if result.isError { fail(result.message) }
    else {
      error = ""
      reply = result.message
      speak(reply)
    }
  }

  private func fail(_ message: String) {
    setPhase("idle")
    error = message
    voice.setPhase("error")
  }

  private func setPhase(_ value: String) {
    phase = value
    voice.setPhase(value)
  }

  private func speak(_ message: String) {
    guard preferences.value.speechFeedback, !message.isEmpty else { return }
    if let feedbackSpeaker { feedbackSpeaker(message, preferences.locale); return }
    synthesizer.stopSpeaking(at: .immediate)
    let utterance = AVSpeechUtterance(string: String(message.prefix(NativeAssistantConversation.maxReplyLength)))
    utterance.voice = AVSpeechSynthesisVoice(language: preferences.locale)
    synthesizer.speak(utterance)
  }

  // Late audio cannot execute a command after cancellation or a module change.
  func receiveSpeech(type: String, text value: String?, code: String? = nil) {
    guard !closed, ["requesting", "listening", "processing"].contains(phase) else { return }
    switch type {
    case "listening", "processing": setPhase(type)
    case "partial": transcript = String((value ?? "").prefix(NativeAssistantConversation.maxQuestionLength))
    case "final":
      setPhase("idle")
      submit(value ?? "")
    case "error":
      let message: String
      switch code {
      case "speechPermission", "microphonePermission": message = text("请在系统设置中允许 Augma 使用麦克风和语音识别，也可以直接输入指令。")
      case "noSpeech": message = text("没有听清，请重试或直接输入指令。")
      case "appInactive": message = text("请回到 Augma 后再开始语音。")
      case "recognizerUnavailable": message = text("当前语言的语音识别暂不可用，请直接输入指令。")
      case "noMicrophone": message = text("没有可用的麦克风输入。")
      default: message = text("语音暂不可用，请重试或直接输入指令。")
      }
      fail(message)
    default: break
    }
  }

  private func completionError(_ error: Error) -> String {
    guard let failure = error as? DeepSeekClient.Failure else {
      return text("DeepSeek 请求失败，请检查网络后重试。")
    }
    switch failure {
    case .invalidInput: return text("请输入 1 至 500 字的指令。")
    case .invalidKey: return text("DeepSeek 密钥无效，请在设置中修改。")
    case .insufficientBalance: return text("DeepSeek 账户余额不足。")
    case .rateLimited: return text("DeepSeek 请求过于频繁，请稍后重试。")
    case .invalidResponse: return text("DeepSeek 未返回可用的回答。")
    case .http(let status): return String(format: text("DeepSeek 请求失败（HTTP %@）。"), String(status))
    }
  }
}

extension Notification.Name {
  static let augmaCancelSpeech = Notification.Name("cn.yunyoujun.augma.cancel-speech")
}
