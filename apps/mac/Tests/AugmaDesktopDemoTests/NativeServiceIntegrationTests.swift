import Foundation
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class NativeServiceIntegrationTests: XCTestCase {
  func testAudioCommandParsingIsExplicitAcrossThreeLanguagesAndPreservesNoteText() {
    let phrases: [(String, NativeAudioAction)] = [
      ("播放声音。", .play), ("播放音乐", .play), ("Play Sound!", .play), ("play audio", .play), ("音楽を再生", .play),
      ("暂停声音", .pause), ("Pause Sound", .pause), ("pause audio", .pause), ("サウンドを一時停止", .pause),
      ("下一首", .next), ("next track", .next), ("次の曲", .next),
      ("上一首", .previous), ("previous song", .previous), ("前の曲", .previous),
    ]
    for (phrase, action) in phrases {
      XCTAssertEqual(WorkspaceCommand.parse(phrase), .audio(action), phrase)
    }
    XCTAssertEqual(WorkspaceCommand.parse("记下：下一首是我喜欢的歌"), .note("下一首是我喜欢的歌"))
    XCTAssertEqual(WorkspaceCommand.parse("note play sound later"), .note("play sound later"))
    XCTAssertEqual(WorkspaceCommand.parse("pause"), .pause, "An unqualified pause retains its existing focus-timer meaning")
    XCTAssertEqual(WorkspaceCommand.parse("打开声音"), .open(.audio))
    XCTAssertNil(WorkspaceCommand.parse("不要播放声音"))
    XCTAssertNil(WorkspaceCommand.parse("play soundtrack"))
  }

  func testSpeechAudioTransportWorksWithoutWebViewOrWritableWorkspaceAndDoesNotNavigate() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "augma-audio-command-tests-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let fileURL = directory.appending(path: "workspace.json")
    let corruptData = Data("unreadable workspace".utf8)
    try corruptData.write(to: fileURL)
    try withServices { fixture in
      let workspace = WorkspaceStore(url: fileURL, notifications: FocusNotifications(enabled: false), observeLifecycle: false)
      XCTAssertFalse(workspace.writable)
      let commands = WorkspaceCommands(store: workspace, audio: fixture.audio)
      var navigations: [DemoModule] = []
      commands.navigate = { navigations.append($0) }
      XCTAssertTrue(commands.isAvailable(.audio(.play)))
      XCTAssertFalse(commands.isAvailable(.audio(.pause)))
      XCTAssertTrue(commands.isAvailable(.audio(.next)))

      commands.receiveSpeech(type: "final", text: "播放声音")
      XCTAssertTrue(fixture.audio.playing)
      XCTAssertFalse(commands.resultIsError)
      XCTAssertEqual(commands.resultDestination, .audio)
      XCTAssertFalse(commands.isAvailable(.audio(.play)))
      XCTAssertTrue(commands.isAvailable(.audio(.pause)))
      XCTAssertEqual(fixture.engine.plays.count, 1)
      commands.query = "play sound"
      XCTAssertTrue(commands.submit())
      XCTAssertEqual(fixture.engine.plays.count, 1, "Repeating an explicit play intent must not create another engine request")

      commands.receiveSpeech(type: "final", text: "下一首")
      XCTAssertEqual(fixture.audio.trackIndex, 1)
      XCTAssertTrue(fixture.audio.playing)
      commands.receiveSpeech(type: "final", text: "previous track")
      XCTAssertEqual(fixture.audio.trackIndex, 0)
      commands.receiveSpeech(type: "final", text: "pause sound")
      XCTAssertFalse(fixture.audio.playing)
      commands.receiveSpeech(type: "final", text: "サウンドを再生")
      XCTAssertTrue(fixture.audio.playing)
      commands.receiveSpeech(type: "final", text: "サウンドを一時停止")
      XCTAssertFalse(fixture.audio.playing)
      commands.receiveSpeech(type: "final", text: "前の曲")
      XCTAssertEqual(fixture.audio.trackIndex, 2)
      XCTAssertFalse(fixture.audio.playing, "Selecting a track while paused preserves the paused state")
      XCTAssertFalse(commands.resultIsError)
      XCTAssertTrue(navigations.isEmpty)
      XCTAssertEqual(try Data(contentsOf: fileURL), corruptData)
    }
  }

  func testAudioCommandErrorsUseAudioFailureAndMissingServiceIsUnavailable() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "augma-audio-command-failure-tests-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let workspace = WorkspaceStore(url: directory.appending(path: "workspace.json"), notifications: FocusNotifications(enabled: false), observeLifecycle: false)
    let disconnected = WorkspaceCommands(store: workspace)
    XCTAssertFalse(disconnected.isAvailable(.audio(.play)))
    XCTAssertFalse(disconnected.isAvailable(.audio(.pause)))
    XCTAssertFalse(disconnected.isAvailable(.audio(.next)))
    XCTAssertFalse(disconnected.execute(.audio(.play)))
    XCTAssertTrue(disconnected.resultIsError)
    withServices { fixture in
      let commands = WorkspaceCommands(store: workspace, audio: fixture.audio)
      fixture.engine.shouldFail = true
      commands.receiveSpeech(type: "final", text: "播放声音")
      XCTAssertFalse(fixture.audio.playing)
      XCTAssertTrue(commands.resultIsError)
      XCTAssertEqual(commands.result, fixture.audio.error)
      XCTAssertNil(commands.resultDestination)
      fixture.engine.shouldFail = false
      commands.receiveSpeech(type: "final", text: "播放声音")
      XCTAssertTrue(fixture.audio.playing)
      XCTAssertFalse(commands.resultIsError)
      fixture.engine.shouldFail = true
      XCTAssertFalse(commands.execute(.audio(.next)))
      XCTAssertFalse(fixture.audio.playing)
      XCTAssertTrue(commands.resultIsError)
      XCTAssertEqual(commands.result, fixture.audio.error)
    }
  }

  private func withServices(_ check: (HostServicesFixture) throws -> Void) rethrows {
    let fixture = HostServicesFixture()
    defer { fixture.tearDown() }
    try check(fixture)
  }

}

@MainActor
private final class HostServicesFixture {
  let suite: String
  let defaults: UserDefaults
  let preferences: NativePreferencesStore
  let audio: NativeAudioStore
  let engine: HostServicesAudioEngine
  let clock: HostServicesClock

  init() {
    suite = "augma-host-services-tests-" + UUID().uuidString
    defaults = UserDefaults(suiteName: suite)!
    preferences = NativePreferencesStore(defaults: defaults, preferredLocalizations: ["zh-Hans"])
    let engine = HostServicesAudioEngine()
    let clock = HostServicesClock()
    self.engine = engine
    self.clock = clock
    audio = NativeAudioStore(defaults: defaults, engine: engine, uptime: { clock.value }, observeLifecycle: false, automaticallyTick: false)
  }

  func tearDown() {
    audio.shutdown()
    defaults.removePersistentDomain(forName: suite)
  }
}

@MainActor
private final class HostServicesClock { var value: TimeInterval = 1_000 }

@MainActor
private final class HostServicesAudioEngine: NativeAudioEngineBackend {
  var onConfigurationChange: (() -> Void)?
  var plays: [(trackIndex: Int, elapsed: TimeInterval)] = []
  var shouldFail = false
  func play(trackIndex: Int, from elapsed: TimeInterval) throws {
    if shouldFail { throw NSError(domain: "AugmaHostServicesAudioTests", code: 1) }
    plays.append((trackIndex, elapsed))
  }
  func pause() {}
  func setVolume(_ fraction: Double) {}
  func reset() {}
  func stop() {}
}
