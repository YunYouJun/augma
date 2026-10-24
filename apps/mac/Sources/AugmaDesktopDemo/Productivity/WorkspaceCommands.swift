import AppKit
import Combine

@MainActor
final class WorkspaceCommands: ObservableObject {
  @Published var query = ""
  @Published private(set) var speechPhase = "idle"
  @Published private(set) var result: String?
  @Published private(set) var resultIsError = false
  @Published private(set) var resultDestination: DemoModule?
  let voice = VoiceActivityModel()
  let store: WorkspaceStore
  let captures: QuickCaptureStore?
  private let audio: NativeAudioStore?
  var navigate: ((DemoModule) -> Void)?
  var operateSpace: ((NativeSpaceAction) -> Void)?
  var pendingVoice = false
  private var observers: [AnyCancellable] = []
  private lazy var recognizer = SpeechCommandRecognizer(onLevel: { [weak self] value in
    self?.voice.receive(level: value)
  }, onEvent: { [weak self] type, text, code in self?.receiveSpeech(type: type, text: text, code: code) })

  init(store: WorkspaceStore, audio: NativeAudioStore? = nil, captures: QuickCaptureStore? = nil) {
    self.store = store
    self.captures = captures
    self.audio = audio
    if let audio {
      // Transport controls can change from another window. Forward only the
      // availability flags, not the audio progress clock, to the command list.
      audio.$playing.combineLatest(audio.$busy).dropFirst()
        .sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &observers)
    }
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
      feedback(String(localized: "未识别这条指令。试试“记下 买咖啡豆”或“专注 25 分钟”。"), error: true)
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
    case .audio(let action): isAudioAvailable(action)
    case .space: operateSpace != nil
    }
  }

  private func isAudioAvailable(_ action: NativeAudioAction) -> Bool {
    guard let audio, !audio.busy else { return false }
    switch action {
    case .play: return !audio.playing
    case .pause: return audio.playing
    case .next, .previous: return true
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
      message = String(localized: "已加入待发送列表，可在快速记录中查看结果。")
      resultDestination = .notes
    case .task(let text):
      success = captures?.submit(text, destination: .microsoftToDo) ?? (store.enqueueCapture(text, destination: .microsoftToDo) != nil)
      message = String(localized: "已加入待发送列表，可在快速记录中查看结果。")
      resultDestination = .notes
    case .startFocus(let duration):
      success = store.startFocus(seconds: duration)
      message = String(localized: "计时已开始，关闭主窗口后仍会继续。")
      resultDestination = .focus
    case .pause: success = store.pauseFocus(); message = String(localized: "计时已暂停。")
    case .resume: success = store.resumeFocus(); message = String(localized: "计时已继续。")
    case .extend: success = store.extendFocus(); message = String(localized: "已延长 5 分钟。")
    case .cancel: success = store.cancelFocus(); message = String(localized: "计时已结束。")
    case .undo:
      success = store.canUndo
      if success { store.undoLastAction() }
      message = String(localized: "已撤销上一步。")
    case .open(let module):
      navigate?(module)
      message = String(format: String(localized: "已打开 %@。"), module.title)
    case .audio(let action):
      return executeAudio(action, actionID: actionID)
    case .space(let action):
      guard let operateSpace else {
        feedback(String(localized: "原生空间暂不可用。"), error: true)
        return false
      }
      operateSpace(action)
      message = String(localized: "已将操作交给原生空间。")
      resultDestination = .space
    }
    if success {
      if let actionID { store.rememberAction(actionID) }
      feedback(message, destination: resultDestination)
    } else {
      resultDestination = nil
      feedback(store.saveError ?? String(localized: "当前无法执行。请检查已有计时、输入内容或操作状态。"), error: true)
    }
    return success
  }

  private func executeAudio(_ action: NativeAudioAction, actionID: String?) -> Bool {
    guard let audio else {
      feedback(String(localized: "声音暂不可用。"), error: true)
      return false
    }
    guard !audio.busy else {
      feedback(String(localized: "声音正在准备，请稍后重试。"), error: true)
      return false
    }
    let message: String
    switch action {
    case .play:
      audio.play()
      message = String(localized: "已开始播放。")
    case .pause:
      audio.pause()
      message = String(localized: "已暂停播放。")
    case .next:
      audio.next()
      message = String(localized: "已切换到下一首。")
    case .previous:
      audio.previous()
      message = String(localized: "已切换到上一首。")
    }
    if let error = audio.error {
      feedback(error, error: true)
      return false
    }
    if action == .play, !audio.playing {
      feedback(String(localized: "声音暂不可用。"), error: true)
      return false
    }
    if let actionID { store.rememberAction(actionID) }
    feedback(message, destination: .audio)
    return true
  }

  func feedback(_ text: String, error: Bool = false, destination: DemoModule? = nil) {
    result = text
    resultIsError = error
    resultDestination = destination
  }

  func toggleVoice() {
    switch voice.phase {
    case "listening": recognizer.stop()
    case "requesting", "processing": cancelVoice()
    default:
      NotificationCenter.default.post(name: .augmaCancelSpeech, object: nil)
      setPhase("requesting")
      query = ""
      result = nil
      Task { await recognizer.start(localeIdentifier: Bundle.main.preferredLocalizations.first, maximumDuration: 60) }
    }
  }

  private func setPhase(_ value: String) {
    speechPhase = value
    voice.setPhase(value)
  }

  func cancelVoice() {
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
    case "partial": query = text ?? ""
    case "final":
      setPhase("idle")
      query = text ?? ""
      if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { submit() }
    case "error":
      setPhase("error")
      let message: String
      switch code {
      case "speechPermission", "microphonePermission": message = String(localized: "请在系统设置中允许 Augma 使用麦克风和语音识别，也可以直接输入指令。")
      case "noSpeech": message = String(localized: "没有听清，请重试或直接输入指令。")
      case "appInactive": message = String(localized: "请回到 Augma 后再开始语音。")
      default: message = String(localized: "语音暂不可用，请重试或直接输入指令。")
      }
      feedback(message, error: true)
    default: break
    }
  }
}

extension Notification.Name {
  static let augmaCancelNativeSpeech = Notification.Name("cn.yunyoujun.augma.cancel-native-speech")
}
