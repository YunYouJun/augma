import AppKit
import Combine

@MainActor
final class WorkspaceCommands: ObservableObject {
  enum SpeechMode { case command, dictation }
  @Published var query = ""
  @Published private(set) var speechPhase = "idle"
  @Published private(set) var speechMode = SpeechMode.command
  @Published private(set) var result: String?
  @Published private(set) var resultIsError = false
  @Published private(set) var resultDestination: DemoModule?
  let voice = VoiceActivityModel()
  let store: WorkspaceStore
  let captures: QuickCaptureStore?
  var navigate: ((DemoModule) -> Void)?
  var operateSpace: ((NativeSpaceAction) -> Void)?
  var requestCleanup: ((String) -> Bool)?
  var pendingVoice = false
  private var dictationPrefix = ""
  private var speechStartTask: Task<Void, Never>?
  private var observers: [AnyCancellable] = []
  private lazy var recognizer = SpeechCommandRecognizer(onLevel: { [weak self] value in
    self?.voice.receive(level: value)
  }, onEvent: { [weak self] type, text, code in self?.receiveSpeech(type: type, text: text, code: code) })

  init(store: WorkspaceStore, captures: QuickCaptureStore? = nil) {
    self.store = store
    self.captures = captures
    NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
      .sink { [weak self] _ in
        guard let self, ["listening", "processing"].contains(self.voice.phase) else { return }
        self.cancelVoice()
      }.store(in: &observers)
    NotificationCenter.default.publisher(for: .augmaCancelNativeSpeech)
      .sink { [weak self] _ in self?.cancelVoice() }.store(in: &observers)
  }

  @discardableResult
  func submit() -> Bool {
    guard let command = WorkspaceCommand.parse(query) else {
      feedback(String(appLocalized: "未识别这条指令。试试“记下 买咖啡豆”或“专注 25 分钟”。"), error: true)
      return false
    }
    return execute(command)
  }

  func isAvailable(_ command: WorkspaceCommand) -> Bool {
    switch command {
    case .pause: store.data.focus?.status == .running
    case .resume: store.data.focus?.status == .paused
    case .extend: store.data.focus != nil && store.data.focus?.status != .completed && (store.data.focus?.duration ?? 0) <= 86_100
    case .cancel: store.data.focus != nil && store.data.focus?.status != .completed
    case .undo: store.canUndo
    case .startFocus: store.writable && (store.data.focus == nil || store.data.focus?.status == .completed)
    case .note, .task: store.writable
    case .open: true
    case .space: operateSpace != nil
    case .cleanup: requestCleanup != nil
    }
  }

  @discardableResult
  func execute(_ command: WorkspaceCommand, actionID: String? = nil) -> Bool {
    store.reconcile()
    var success = true
    var message = ""
    resultDestination = nil
    switch command {
    case .note(let text):
      success = captures?.submit(text, destination: .appleNotes) ?? (store.enqueueCapture(text, destination: .appleNotes) != nil)
      message = String(appLocalized: "已加入待发送列表，可在快速记录中查看结果。")
      resultDestination = .notes
    case .task(let text):
      success = captures?.submit(text, destination: .microsoftToDo) ?? (store.enqueueCapture(text, destination: .microsoftToDo) != nil)
      message = String(appLocalized: "已加入待发送列表，可在快速记录中查看结果。")
      resultDestination = .notes
    case .startFocus(let duration):
      success = store.startFocus(seconds: duration)
      message = String(appLocalized: "计时已开始，关闭主窗口后仍会继续。")
      resultDestination = .focus
    case .pause: success = store.pauseFocus(); message = String(appLocalized: "计时已暂停。")
    case .resume: success = store.resumeFocus(); message = String(appLocalized: "计时已继续。")
    case .extend: success = store.extendFocus(); message = String(appLocalized: "已延长 5 分钟。")
    case .cancel: success = store.cancelFocus(); message = String(appLocalized: "计时已结束。")
    case .undo:
      success = store.canUndo
      if success { store.undoLastAction() }
      message = String(appLocalized: "已撤销上一步。")
    case .open(let module):
      navigate?(module)
      message = String(format: String(appLocalized: "已打开 %@。"), module.title)
    case .space(let action):
      guard let operateSpace else {
        feedback(String(appLocalized: "原生空间暂不可用。"), error: true)
        return false
      }
      operateSpace(action)
      message = String(appLocalized: "已将操作交给原生空间。")
      resultDestination = .space
    case .cleanup(let text):
      guard requestCleanup?(text) == true else {
        feedback(String(appLocalized: "清理工具正忙，请等待当前操作完成。"), error: true)
        return false
      }
      navigate?(.market)
      resultDestination = .market
      message = String(appLocalized: "已打开 Augma Link 本地工具，按保留规则生成计划；执行前请核对并确认。")
    }
    if success {
      if let actionID { store.rememberAction(actionID) }
      feedback(message, destination: resultDestination)
    } else {
      resultDestination = nil
      feedback(store.saveError ?? String(appLocalized: "当前无法执行。请检查已有计时、输入内容或操作状态。"), error: true)
    }
    return success
  }

  func feedback(_ text: String, error: Bool = false, destination: DemoModule? = nil) {
    result = text
    resultIsError = error
    resultDestination = destination
  }

  func toggleVoice() {
    toggleVoice(mode: speechMode)
  }

  func preparePendingVoice(mode: SpeechMode) {
    // Reopening an active panel may stop recording, but must not reinterpret
    // existing dictation as a command that executes automatically.
    if ["idle", "error"].contains(speechPhase) {
      speechMode = mode
      dictationPrefix = mode == .dictation ? query : ""
    }
    pendingVoice = true
  }

  func finishDictation() {
    guard speechMode == .dictation else { return }
    pendingVoice = false
    switch voice.phase {
    case "listening": recognizer.stop()
    case "requesting": cancelVoice()
    default: break
    }
  }

  func toggleVoice(mode: SpeechMode) {
    switch voice.phase {
    case "listening": recognizer.stop()
    case "requesting", "processing": cancelVoice()
    default:
      NotificationCenter.default.post(name: .augmaCancelSpeech, object: nil)
      speechMode = mode
      dictationPrefix = mode == .dictation ? query : ""
      setPhase("requesting")
      if mode == .command { query = "" }
      result = nil
      speechStartTask = Task { [weak self] in
        guard !Task.isCancelled, let self else { return }
        await recognizer.start(localeIdentifier: Bundle.main.preferredLocalizations.first, maximumDuration: 60)
      }
    }
  }

  private func setPhase(_ value: String) {
    speechPhase = value
    voice.setPhase(value)
  }

  func cancelVoice() {
    speechStartTask?.cancel()
    speechStartTask = nil
    recognizer.cancel()
    pendingVoice = false
    setPhase("idle")
  }

  func startPendingVoice() {
    guard pendingVoice else { return }
    pendingVoice = false
    toggleVoice()
  }

  // This same entry point handles recognizer results and is testable without microphone access.
  func receiveSpeech(type: String, text: String?, code: String? = nil) {
    switch type {
    case "listening", "processing": setPhase(type)
    case "partial": query = (speechMode == .dictation ? dictationPrefix : "") + (text ?? "")
    case "final":
      setPhase("idle")
      query = (speechMode == .dictation ? dictationPrefix : "") + (text ?? "")
      if speechMode == .command, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { submit() }
    case "error":
      setPhase("error")
      let message: String
      switch code {
      case "speechPermission", "microphonePermission": message = String(appLocalized: "请在系统设置中允许 Augma 使用麦克风和语音识别，也可以直接输入指令。")
      case "noSpeech": message = String(appLocalized: "没有听清，请重试或直接输入指令。")
      case "appInactive": message = String(appLocalized: "请回到 Augma 后再开始语音。")
      default: message = String(appLocalized: "语音暂不可用，请重试或直接输入指令。")
      }
      feedback(message, error: true)
    default: break
    }
  }
}

extension Notification.Name {
  static let augmaCancelNativeSpeech = Notification.Name("cn.yunyoujun.augma.cancel-native-speech")
}
