import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class NativeVoiceInputTests: XCTestCase {
  func testProviderPreferenceDefaultsToAppleAndRestoresWeChat() throws {
    let name = "augma-voice-provider-tests-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    XCTAssertEqual(VoiceInputProvider.read(from: defaults), .apple)
    defaults.set("weChat", forKey: VoiceInputProvider.storageKey)
    XCTAssertEqual(VoiceInputProvider.read(from: defaults), .weChat)
    defaults.set("invalid", forKey: VoiceInputProvider.storageKey)
    XCTAssertEqual(VoiceInputProvider.read(from: defaults), .apple)
  }

  func testDictationFillsTheInputWithoutExecutingRecognizedCommands() async throws {
    try await withCommands { commands, workspace in
      commands.preparePendingVoice(mode: .dictation)
      commands.receiveSpeech(type: "partial", text: "专注")
      XCTAssertEqual(commands.query, "专注")
      commands.receiveSpeech(type: "final", text: "专注二十五分钟")
      XCTAssertEqual(commands.query, "专注二十五分钟")
      XCTAssertEqual(commands.speechPhase, "idle")
      XCTAssertNil(workspace.data.focus, "Dictated text must wait for explicit submission")
      XCTAssertNil(commands.result)
      XCTAssertTrue(commands.submit())
      XCTAssertEqual(workspace.data.focus?.duration, 1500)
    }
  }

  func testDictationPreservesExistingInputAndReplacesPartialTranscripts() async throws {
    try await withCommands { commands, _ in
      commands.query = "草稿："
      commands.preparePendingVoice(mode: .dictation)
      commands.receiveSpeech(type: "partial", text: "星星")
      commands.receiveSpeech(type: "partial", text: "星星和月亮")
      commands.receiveSpeech(type: "final", text: "星星和月亮都在天空")
      XCTAssertEqual(commands.query, "草稿：星星和月亮都在天空")
    }
  }

  func testReleaseBeforeThePanelStartsCancelsPendingDictation() async throws {
    try await withCommands { commands, _ in
      commands.query = "保留草稿"
      commands.preparePendingVoice(mode: .dictation)
      XCTAssertTrue(commands.pendingVoice)
      commands.finishDictation()
      commands.startPendingVoice()
      XCTAssertFalse(commands.pendingVoice)
      XCTAssertEqual(commands.speechPhase, "idle")
      XCTAssertEqual(commands.query, "保留草稿")
    }
  }

  func testReopeningAnActiveDictationDoesNotTurnItsTextIntoAnAutomaticCommand() async throws {
    try await withCommands { commands, workspace in
      commands.preparePendingVoice(mode: .dictation)
      commands.receiveSpeech(type: "listening", text: nil)
      commands.preparePendingVoice(mode: .command)
      commands.receiveSpeech(type: "final", text: "专注二十五分钟")
      XCTAssertEqual(commands.speechMode, .dictation)
      XCTAssertEqual(commands.query, "专注二十五分钟")
      XCTAssertNil(workspace.data.focus)
    }
  }

  private func withCommands(_ body: (WorkspaceCommands, WorkspaceStore) throws -> Void) async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "augma-native-voice-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let workspace = WorkspaceStore(url: directory.appending(path: "workspace.json"),
      notifications: FocusNotifications(enabled: false), observeLifecycle: false)
    try body(WorkspaceCommands(store: workspace), workspace)
    _ = await workspace.flush()
  }
}
