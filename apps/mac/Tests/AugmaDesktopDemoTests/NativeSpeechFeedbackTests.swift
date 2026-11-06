import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class NativeSpeechFeedbackTests: XCTestCase {
  func testUnusedAndInjectedFeedbackDoNotInitializeSystemVoices() {
    let fixture = FeedbackFixture(); defer { fixture.close() }
    var creations = 0
    let makeSpeaker = { creations += 1; return RecordingFeedback() }
    let unused = NativeAssistantStore(preferences: fixture.preferences, keyProvider: { nil }, feedbackFactory: makeSpeaker)
    unused.cancel()
    fixture.preferences.value.speechFeedback = false
    unused.shutdown()
    var messages: [String] = []
    fixture.preferences.value.speechFeedback = true
    let injected = NativeAssistantStore(preferences: fixture.preferences, keyProvider: { nil },
      feedbackSpeaker: { text, _ in messages.append(text) }, feedbackFactory: makeSpeaker)
    injected.performAction = { _ in .init(message: "opened") }
    injected.submit("打开地图")
    injected.shutdown()
    XCTAssertEqual(messages, ["opened"])
    XCTAssertEqual(creations, 0)
  }

  func testFeedbackStartsOnlyWhenEnabledAndSpeakingAndIsReusedUntilShutdown() {
    let fixture = FeedbackFixture(); defer { fixture.close() }
    let speaker = RecordingFeedback()
    var creations = 0
    let store = NativeAssistantStore(preferences: fixture.preferences, keyProvider: { nil },
      feedbackFactory: { creations += 1; return speaker })
    store.performAction = { _ in .init(message: "opened") }
    fixture.preferences.value.speechFeedback = false
    store.submit("打开地图")
    XCTAssertEqual(creations, 0)
    XCTAssertTrue(speaker.messages.isEmpty)
    fixture.preferences.value.speechFeedback = true
    store.submit("打开地图")
    store.submit("打开天气")
    XCTAssertEqual(creations, 1)
    XCTAssertEqual(speaker.messages, ["opened", "opened"])
    let stops = speaker.stopCount
    store.cancel()
    XCTAssertEqual(speaker.stopCount, stops + 1)
    fixture.preferences.value.speechFeedback = false
    XCTAssertEqual(speaker.stopCount, stops + 2)
    store.shutdown()
    XCTAssertEqual(speaker.stopCount, stops + 3)
  }

}

@MainActor
private final class RecordingFeedback: NativeFeedbackSpeaking {
  var messages: [String] = []
  var stopCount = 0
  func speak(_ message: String, locale: String) { messages.append(message) }
  func stop() { stopCount += 1 }
}

@MainActor
private final class FeedbackFixture {
  let suite = "augma-speech-feedback-test-" + UUID().uuidString
  let defaults: UserDefaults
  let preferences: NativePreferencesStore
  init() {
    let defaults = UserDefaults(suiteName: suite)!
    self.defaults = defaults
    preferences = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
    preferences.value.speechFeedback = true
  }
  func close() { defaults.removePersistentDomain(forName: suite) }
}
