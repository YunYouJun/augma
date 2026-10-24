import XCTest
@testable import AugmaDesktopDemo

final class NativeAssistantConversationTests: XCTestCase {
  func testLocalActionsWorkInAllThreeLanguages() {
    let examples: [(NativeAssistantAction, [String])] = [
      (.map, ["请打开地图", "Open the map", "地図を開いて"]),
      (.scan, ["扫描周围空间", "Scan the room", "空間をスキャンして"]),
      (.audio, ["播放音乐", "Play some music", "サウンドを再生して"]),
      (.audioPause, ["暂停声音", "Stop the music", "音楽を止めて"]),
      (.hide, ["隐藏 HUD", "Hide the HUD", "HUDを隠して"]),
      (.show, ["显示 HUD", "Restore the HUD", "HUDを表示して"]),
      (.weather, ["看看天气", "Show the forecast", "天気を見せて"]),
      (.notifications, ["查看通知", "Read my notifications", "通知を確認"]),
      (.settings, ["打开设置", "Open settings", "設定を開いて"]),
      (.camera, ["打开摄像头", "Open the camera", "カメラを起動"]),
      (.browser, ["打开网页", "Open browser", "ブラウザを開く"]),
      (.dark, ["打开深色模式", "Turn on dark mode", "ダークモードにして"]),
      (.light, ["切换浅色模式", "Switch to light mode", "ライトモードにして"]),
      (.routeStart, ["开始路线", "Start the route", "ルートを開始"]),
      (.routeNext, ["前进一步", "Next step", "一歩進む"]),
      (.routeStop, ["结束导航", "Stop navigation", "ナビを終了"]),
    ]
    XCTAssertEqual(examples.count, NativeAssistantAction.allCases.count)
    for (command, phrases) in examples {
      for phrase in phrases {
        XCTAssertEqual(NativeAssistantCommandParser.match(phrase), .action(command), phrase)
      }
    }
  }

  func testRefusalsWinOverStopAndOpenActions() {
    for text in ["不要停止音乐", "请别打开摄像头", "Don't stop the music", "Do not open the browser", "地図を開かないで", "音楽を止めないで"] {
      XCTAssertEqual(NativeAssistantCommandParser.match(text), .refused, text)
    }
    XCTAssertEqual(NativeAssistantCommandParser.match("Explain how clouds form"), .unmatched)
  }

  func testAnswerRequiresAnExactSchemaAndAllowedAction() throws {
    XCTAssertEqual(try NativeAssistantConversation.parse(#"{"reply":" Hello ","command":null}"#), .init(reply: "Hello", command: nil))
    for action in NativeAssistantAction.allCases {
      let result = try NativeAssistantConversation.parse("{\"reply\":\"\",\"command\":\"\(action.rawValue)\"}")
      XCTAssertEqual(result.command, action)
    }
    for invalid in [
      "null", "[]", "true", "not json", #"{"reply":"hi"}"#, #"{"reply":"hi","command":false}"#,
      #"{"reply":"hi","command":"cameraStart"}"#, #"{"reply":"hi","command":"runShell"}"#,
      #"{"reply":"hi","command":"browser","url":"https://example.com"}"#,
      #"{"reply":"hi","command":null,"extra":1}"#, #"{"reply":" ","command":null}"#,
    ] { XCTAssertThrowsError(try NativeAssistantConversation.parse(invalid), invalid) }
    let long = String(repeating: "天", count: 700)
    XCTAssertEqual(try NativeAssistantConversation.parse("{\"reply\":\"\(long)\",\"command\":null}").reply.count, 600)
  }

  func testConversationBoundsInputHistoryAndContext() throws {
    let history = (0..<8).map { NativeAssistantTurn(question: "question \($0)", answer: .init(reply: "answer \($0)", command: nil)) }
    let messages = try NativeAssistantConversation.messages(question: "  question 8  ", locale: "ja-JP", history: history)
    XCTAssertEqual(messages.count, 10)
    XCTAssertEqual(messages[1]["content"], "question 4")
    XCTAssertEqual(messages.last?["content"], "question 8")
    XCTAssertTrue(messages[0]["content"]?.contains("Japanese") == true)
    XCTAssertTrue(messages[0]["content"]?.contains("native macOS app") == true)
    XCTAssertTrue(messages[0]["content"]?.contains("never activate the camera") == true)
    XCTAssertFalse(messages[0]["content"]?.contains("running in a web page") == true)
    for question in ["", "  ", String(repeating: "x", count: 501)] {
      XCTAssertThrowsError(try NativeAssistantConversation.messages(question: question, locale: "en-US", history: []))
    }
    XCTAssertNoThrow(try NativeAssistantConversation.messages(question: String(repeating: "天", count: 500), locale: "zh-CN", history: []))
  }
}

@MainActor
final class NativeAssistantStoreTests: XCTestCase {
  func testLocalActionsNeedNoKeyAndUseNativeResult() {
    let store = makeStore()
    var performed: [NativeAssistantAction] = []
    store.performAction = { action in performed.append(action); return .init(message: "opened") }
    store.draft = "Open browser"
    store.submit()
    XCTAssertEqual(performed, [.browser])
    XCTAssertEqual(store.transcript, "Open browser")
    XCTAssertEqual(store.reply, "opened")
    XCTAssertTrue(store.draft.isEmpty)
    XCTAssertTrue(store.error.isEmpty)
    XCTAssertTrue(store.history.isEmpty)
    XCTAssertFalse(store.assistantReady)
    store.shutdown()
  }

  func testNotesCaptureEmbeddedActionWithoutExecutingIt() {
    let store = makeStore()
    var command: WorkspaceCommand?
    var actions = 0
    store.performWorkspaceCommand = { command = $0; return .init(message: "saved") }
    store.performAction = { _ in actions += 1; return .init(message: "wrong") }
    store.submit("记下 不要打开地图")
    XCTAssertEqual(command, .note("不要打开地图"))
    XCTAssertEqual(actions, 0)
    XCTAssertEqual(store.reply, "saved")
    store.shutdown()
  }

  func testRefusalsAndInvalidInputNeverRequestOrExecute() {
    let store = makeStore(keyProvider: { "test-key" }, completion: { _, _ in
      XCTFail("Should not call a remote assistant")
      return ""
    })
    store.performAction = { _ in XCTFail("Should not execute a refused action"); return .init(message: "wrong") }
    store.submit("不要停止音乐")
    XCTAssertFalse(store.reply.isEmpty)
    store.submit(String(repeating: "x", count: 501))
    XCTAssertFalse(store.error.isEmpty)
    XCTAssertEqual(store.phase, "idle")
    store.draft = String(repeating: "界", count: 800)
    XCTAssertEqual(store.draft.count, 500)
    store.shutdown()
  }

  func testMissingKeyAndInvalidResponseAreRecoverable() async {
    let noKey = makeStore()
    noKey.submit("Explain cloud formation")
    XCTAssertFalse(noKey.error.isEmpty)
    XCTAssertEqual(noKey.phase, "idle")
    noKey.shutdown()
    let store = makeStore(keyProvider: { "test-key" }, completion: { _, _ in #"{"reply":"x","command":"cameraStart"}"# })
    var actions = 0
    store.performAction = { _ in actions += 1; return .init(message: "wrong") }
    store.submit("Explain cloud formation")
    await waitUntil { store.phase == "idle" }
    XCTAssertFalse(store.error.isEmpty)
    XCTAssertEqual(actions, 0)
    XCTAssertTrue(store.history.isEmpty)
    store.shutdown()
  }

  func testHistoryIsBoundedAndRetainedOnPresentationChange() async {
    let store = makeStore(keyProvider: { "test-key" }, completion: { _, _ in #"{"reply":"A short answer","command":null}"# })
    for index in 0..<6 {
      store.submit("Question \(index)")
      await waitUntil { store.phase == "idle" }
    }
    XCTAssertEqual(store.history.count, 4)
    XCTAssertEqual(store.history.first?.question, "Question 2")
    // Both presentations hold this same reference; cancellation keeps context.
    let immersiveStore = store
    immersiveStore.draft = "Follow-up"
    store.cancel()
    XCTAssertEqual(immersiveStore.history.count, 4)
    XCTAssertEqual(store.draft, "Follow-up")
    XCTAssertEqual(store.reply, "A short answer")
    store.shutdown()
  }

  func testCancelledRequestCannotReplaceNewerReplyOrRunAnAction() async {
    let gate = AssistantCompletionGate()
    let store = makeStore(keyProvider: { "test-key" }, completion: { _, _ in await gate.next() })
    var actions = 0
    store.performAction = { _ in actions += 1; return .init(message: "wrong") }
    store.submit("First question")
    await waitUntilAsync { await gate.count == 1 }
    store.cancel()
    store.submit("Second question")
    await waitUntilAsync { await gate.count == 2 }
    await gate.finish(1, with: #"{"reply":"Current answer","command":null}"#)
    await waitUntil { store.phase == "idle" }
    await gate.finish(0, with: #"{"reply":"","command":"camera"}"#)
    await Task.yield()
    XCTAssertEqual(store.reply, "Current answer")
    XCTAssertEqual(store.history.map(\.question), ["Second question"])
    XCTAssertEqual(actions, 0)
    store.shutdown()
  }

  func testLocaleAndConfigurationChangesCancelAndClearConversation() async {
    var key: String? = "test-key"
    let store = makeStore(keyProvider: { key }, completion: { _, _ in #"{"reply":"Answer","command":null}"# })
    store.submit("A question")
    await waitUntil { store.phase == "idle" }
    XCTAssertEqual(store.history.count, 1)
    store.preferences.locale = "ja-JP"
    XCTAssertTrue(store.history.isEmpty)
    store.submit("Another question")
    await waitUntil { store.phase == "idle" }
    key = nil
    NotificationCenter.default.post(name: .augmaDeepSeekConfigChanged, object: nil)
    XCTAssertFalse(store.assistantReady)
    XCTAssertTrue(store.history.isEmpty)
    XCTAssertEqual(store.phase, "idle")
    store.shutdown()
  }

  func testShutdownRejectsLateSpeechAndFutureCommands() {
    let store = makeStore()
    var actions = 0
    store.performAction = { _ in actions += 1; return .init(message: "wrong") }
    store.shutdown()
    store.receiveSpeech(type: "final", text: "打开摄像头")
    store.submit("打开摄像头")
    XCTAssertEqual(actions, 0)
    XCTAssertTrue(store.transcript.isEmpty)
    XCTAssertEqual(store.phase, "idle")
  }

  func testFeedbackUsesNativeSpeechPreference() {
    var spoken: [String] = []
    let store = makeStore(feedbackSpeaker: { text, _ in spoken.append(text) })
    store.performAction = { _ in .init(message: "opened") }
    store.submit("Open browser")
    XCTAssertTrue(spoken.isEmpty)
    store.preferences.set("speechFeedback", value: true)
    store.submit("Open browser")
    XCTAssertEqual(spoken, ["opened"])
    store.shutdown()
  }

  private func makeStore(
    keyProvider: @escaping () -> String? = { nil },
    completion: @escaping NativeAssistantStore.Completion = { _, _ in
      XCTFail("Unexpected assistant request")
      return ""
    },
    feedbackSpeaker: ((String, String) -> Void)? = nil
  ) -> NativeAssistantStore {
    let suite = "augma.native-assistant-tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let preferences = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
    preferences.set("speechFeedback", value: false)
    addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
    return NativeAssistantStore(preferences: preferences, keyProvider: keyProvider, completion: completion, feedbackSpeaker: feedbackSpeaker)
  }

  private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while !condition(), ContinuousClock.now < deadline { try? await Task.sleep(for: .milliseconds(2)) }
    XCTAssertTrue(condition(), file: file, line: line)
  }

  private func waitUntilAsync(_ condition: () async -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while !(await condition()), ContinuousClock.now < deadline { try? await Task.sleep(for: .milliseconds(2)) }
    let result = await condition()
    XCTAssertTrue(result, file: file, line: line)
  }
}

private actor AssistantCompletionGate {
  private var continuations: [CheckedContinuation<String, Never>?] = []
  var count: Int { continuations.count }
  func next() async -> String {
    await withCheckedContinuation { continuations.append($0) }
  }
  func finish(_ index: Int, with response: String) {
    guard continuations.indices.contains(index), let continuation = continuations[index] else { return }
    continuations[index] = nil
    continuation.resume(returning: response)
  }
}
