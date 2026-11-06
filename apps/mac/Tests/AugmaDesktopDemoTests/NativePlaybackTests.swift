import Foundation
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class NativePlaybackTests: XCTestCase {
  func testExplicitActionUsesObservedStateAndWaitsForConfirmation() async throws {
    let reader = PlaybackTestReader(), playback = PlaybackTestController()
    let store = NativeAudioStore(client: reader, playback: playback, isRunning: { true }, observeLifecycle: false)
    defer { store.shutdown() }
    store.startObserving()
    reader.emit(sample(playing: true))
    XCTAssertTrue(playback.requests.isEmpty, "Observation must never send playback commands")
    store.togglePlayback(); store.togglePlayback()
    try await waitUntil { playback.requests.count == 1 }
    XCTAssertEqual(playback.requests, [.pause])
    XCTAssertTrue(store.isChangingPlayback)
    XCTAssertFalse(store.canControlPlayback)
    guard case .track(let track) = store.status else { return XCTFail("Missing track") }
    XCTAssertTrue(track.playing, "Do not invent a successful pause before the player confirms it")
    reader.emit(sample(playing: false))
    XCTAssertFalse(store.isChangingPlayback)
    XCTAssertTrue(store.canControlPlayback)
    store.togglePlayback()
    try await waitUntil { playback.requests.count == 2 }
    XCTAssertEqual(playback.requests, [.pause, .play])
    reader.emit(sample(playing: true))
    XCTAssertNil(store.playbackError)
  }

  func testFailedCommandCanBeRetriedAndAnUnconfirmedCommandTimesOut() async throws {
    let reader = PlaybackTestReader(), playback = PlaybackTestController()
    playback.fails = true
    let store = NativeAudioStore(client: reader, playback: playback, playbackConfirmationTimeout: .milliseconds(20),
                                isRunning: { true }, observeLifecycle: false)
    defer { store.shutdown() }
    store.startObserving(); reader.emit(sample(playing: false))
    store.togglePlayback()
    try await waitUntil { store.playbackError != nil }
    XCTAssertTrue(store.canControlPlayback)
    guard case .track(let track) = store.status else { return XCTFail("Keep the current track after failure") }
    XCTAssertFalse(track.playing)
    playback.fails = false
    store.togglePlayback()
    XCTAssertNil(store.playbackError)
    try await waitUntil { playback.requests.count == 2 && store.playbackError != nil }
    XCTAssertEqual(playback.requests, [.play, .play])
    XCTAssertFalse(store.isChangingPlayback, "An acknowledged request still requires observed playback confirmation")
  }

  func testUnavailableUnrelatedAndStaleSessionsCannotBeControlled() {
    let reader = PlaybackTestReader(), playback = PlaybackTestController()
    var running = false
    var date = Date(timeIntervalSince1970: 1000)
    let store = NativeAudioStore(client: reader, playback: playback, isRunning: { running }, now: { date }, observeLifecycle: false)
    defer { store.shutdown() }
    store.startObserving(); store.togglePlayback()
    running = true; store.refresh(); store.togglePlayback()
    var unrelated = sample(playing: true); unrelated.bundleIdentifier = "com.apple.Music"
    reader.emit(unrelated); store.togglePlayback()
    store.previousTrack(); store.nextTrack()
    reader.fail(); store.togglePlayback()
    reader.emit(sample(playing: false))
    date = date.addingTimeInterval(9)
    XCTAssertFalse(store.canControlPlayback)
    store.togglePlayback()
    store.previousTrack(); store.nextTrack()
    XCTAssertTrue(playback.requests.isEmpty)
  }

  func testSkipWaitsForAcknowledgementAndOnlyTheReaderChangesMetadata() async throws {
    let reader = PlaybackTestReader(), playback = PlaybackTestController()
    playback.holdsRequest = true
    let store = NativeAudioStore(client: reader, playback: playback, isRunning: { true }, observeLifecycle: false)
    defer { store.shutdown() }
    store.startObserving(); reader.emit(sample(playing: true))
    store.nextTrack(); store.nextTrack(); store.previousTrack(); store.togglePlayback()
    try await waitUntil { playback.requests.count == 1 }
    XCTAssertEqual(playback.requests, [.nextTrack])
    reader.emit(sample(playing: true))
    XCTAssertTrue(store.isChangingPlayback, "An unchanged playing state cannot confirm a skip")
    playback.completeHeldRequest()
    try await waitUntil { !store.isChangingPlayback }
    guard case .track(let current) = store.status else { return XCTFail("Missing track") }
    XCTAssertEqual(current.title, "Example", "Do not guess the next track from a local queue")
    var next = sample(playing: true); next.title = "Next song"
    reader.emit(next)
    guard case .track(let updated) = store.status else { return XCTFail("Missing updated track") }
    XCTAssertEqual(updated.title, "Next song")
    XCTAssertNil(store.playbackError)
  }

  func testPreviousTrackCanRestartTheSameSongWithoutAFalseTimeout() async throws {
    let reader = PlaybackTestReader(), playback = PlaybackTestController()
    let store = NativeAudioStore(client: reader, playback: playback, playbackConfirmationTimeout: .milliseconds(20),
                                isRunning: { true }, observeLifecycle: false)
    defer { store.shutdown() }
    store.startObserving(); reader.emit(sample(playing: false))
    store.previousTrack()
    try await waitUntil { playback.requests.count == 1 && !store.isChangingPlayback }
    reader.emit(sample(playing: false))
    XCTAssertEqual(playback.requests, [.previousTrack], "Do not send a separate play command for a skip")
    XCTAssertTrue(store.canControlPlayback)
    XCTAssertNil(store.playbackError)
  }

  func testSkipFailureCanBeRetriedAndSwitchingPlayersCancelsPendingSkip() async throws {
    let reader = PlaybackTestReader(), playback = PlaybackTestController()
    playback.fails = true
    let store = NativeAudioStore(client: reader, playback: playback, isRunning: { true }, observeLifecycle: false)
    defer { store.shutdown() }
    store.startObserving(); reader.emit(sample(playing: true)); store.nextTrack()
    try await waitUntil { store.playbackError != nil }
    XCTAssertTrue(store.canControlPlayback)
    playback.fails = false; playback.holdsRequest = true
    store.nextTrack()
    try await waitUntil { playback.requests.count == 2 }
    var unrelated = sample(playing: true); unrelated.bundleIdentifier = "com.apple.Music"
    reader.emit(unrelated)
    XCTAssertFalse(store.isChangingPlayback)
    XCTAssertEqual(store.status, .idle)
    playback.completeHeldRequest()
    await Task.yield()
    XCTAssertNil(store.playbackError)
    XCTAssertFalse(store.canControlPlayback)
    XCTAssertEqual(playback.requests, [.nextTrack, .nextTrack])
  }

  func testSleepAndShutdownIgnoreLateCommandCompletion() async throws {
    let reader = PlaybackTestReader(), playback = PlaybackTestController()
    playback.holdsRequest = true
    let store = NativeAudioStore(client: reader, playback: playback, isRunning: { true }, observeLifecycle: false)
    store.startObserving(); reader.emit(sample(playing: true)); store.togglePlayback()
    try await waitUntil { playback.requests.count == 1 }
    store.setSleeping(true)
    XCTAssertFalse(store.isChangingPlayback)
    XCTAssertFalse(store.canControlPlayback)
    playback.completeHeldRequest()
    await Task.yield()
    XCTAssertNil(store.playbackError)
    store.setSleeping(false)
    reader.emit(sample(playing: false)); store.togglePlayback()
    try await waitUntil { playback.requests.count == 2 }
    store.shutdown()
    playback.completeHeldRequest()
    await Task.yield()
    XCTAssertNil(store.playbackError)
    XCTAssertEqual(store.status, .idle)
    XCTAssertFalse(store.canControlPlayback)
  }

  private func sample(playing: Bool) -> NativeNowPlayingPayload {
    NativeNowPlayingPayload(bundleIdentifier: NativeNowPlayingTrack.neteaseBundleIdentifier,
                            title: "Example", playing: playing, lyrics: "Local test lyrics")
  }

  private func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0..<100 {
      if condition() { return }
      try await Task.sleep(for: .milliseconds(5))
    }
    XCTFail("Playback state did not settle")
  }
}

@MainActor
private final class PlaybackTestController: NativePlaybackControlling {
  var requests: [NativePlaybackCommand] = []
  var fails = false
  var holdsRequest = false
  private var continuation: CheckedContinuation<Void, Never>?
  func send(_ command: NativePlaybackCommand) async throws {
    requests.append(command)
    if holdsRequest { await withCheckedContinuation { continuation = $0 } }
    if fails { throw NativeNowPlayingError.unavailable }
  }
  func completeHeldRequest() { continuation?.resume(); continuation = nil }
}

@MainActor
private final class PlaybackTestReader: NativeNowPlayingReading {
  private var receive: ((Result<NativeNowPlayingPayload, NativeNowPlayingError>) -> Void)?
  func start(_ receive: @escaping (Result<NativeNowPlayingPayload, NativeNowPlayingError>) -> Void) { self.receive = receive }
  func stop() { receive = nil }
  func emit(_ payload: NativeNowPlayingPayload) { receive?(.success(payload)) }
  func fail() { receive?(.failure(.unavailable)) }
}
