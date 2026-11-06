import Foundation
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class NativePlaybackPositionTests: XCTestCase {
  func testScrubKeepsDraftUntilCommitAndRejectsAnotherSong() throws {
    let track = try XCTUnwrap(NativeNowPlayingTrack(payload: sample(), receivedAt: date))
    var scrub = NativePlaybackScrubState()
    scrub.update(75, track: track)
    XCTAssertEqual(scrub.position, 75)
    // New playback samples never replace this independent drag preview.
    XCTAssertEqual(scrub.takeRequest(currentIdentifier: "song"), .seek(position: 75, trackIdentifier: "song"))
    XCTAssertNil(scrub.position)
    scrub.update(90, track: track)
    XCTAssertNil(scrub.takeRequest(currentIdentifier: "another-song"))
    scrub.update(.nan, track: track)
    XCTAssertNil(scrub.position)
    scrub.update(-10, track: track)
    XCTAssertEqual(scrub.takeRequest(currentIdentifier: "song"), .seek(position: 0, trackIdentifier: "song"))
    scrub.update(999, track: track)
    XCTAssertEqual(scrub.takeRequest(currentIdentifier: "song"), .seek(position: 180, trackIdentifier: "song"))
  }

  func testSeekWaitsForAcknowledgementAndActualPosition() async throws {
    let reader = SeekTestReader(), playback = SeekTestController()
    playback.hold = true
    let store = makeStore(reader, playback)
    defer { store.shutdown() }
    store.startObserving(); reader.emit(sample())
    XCTAssertTrue(store.canSeek)
    store.seek(to: 75, trackIdentifier: "song")
    store.seek(to: 90, trackIdentifier: "song")
    try await waitUntil { playback.requests.count == 1 }
    XCTAssertEqual(playback.requests, [.seek(position: 75, trackIdentifier: "song")])
    reader.emit(sample(elapsed: 75))
    XCTAssertTrue(store.isChangingPlayback, "A position sample cannot acknowledge the helper request")
    XCTAssertEqual(store.requestedSeekPosition, 75)
    playback.complete()
    try await waitUntil { !store.isChangingPlayback }
    XCTAssertNil(store.requestedSeekPosition)
    XCTAssertNil(store.playbackError)
    guard case .track(let track) = store.status else { return XCTFail("Missing track") }
    XCTAssertFalse(track.playing, "Seeking a paused song must not send play")
  }

  func testAcknowledgedSeekKeepsPreviewUntilReaderConfirms() async throws {
    let reader = SeekTestReader(), playback = SeekTestController()
    let store = makeStore(reader, playback)
    defer { store.shutdown() }
    store.startObserving(); reader.emit(sample(playing: true))
    store.seek(to: 120, trackIdentifier: "song")
    try await waitUntil { playback.requests.count == 1 }
    await Task.yield()
    reader.emit(sample(playing: true, elapsed: 12))
    XCTAssertEqual(store.requestedSeekPosition, 120)
    XCTAssertTrue(store.isChangingPlayback)
    reader.emit(sample(playing: true, elapsed: 121))
    XCTAssertFalse(store.isChangingPlayback)
    XCTAssertNil(store.playbackError)
  }

  func testUnconfirmedOrFailedSeekReturnsToObservedPosition() async throws {
    let reader = SeekTestReader(), playback = SeekTestController()
    let store = makeStore(reader, playback, timeout: .milliseconds(20))
    defer { store.shutdown() }
    store.startObserving(); reader.emit(sample())
    store.seek(to: 80, trackIdentifier: "song")
    try await waitUntil { store.playbackError != nil }
    XCTAssertNil(store.requestedSeekPosition)
    XCTAssertTrue(store.canSeek)
    guard case .track(let track) = store.status else { return XCTFail("Missing track") }
    XCTAssertEqual(track.elapsed, 10, "A successful helper response must not invent a position")
    playback.fail = true
    store.seek(to: 90, trackIdentifier: "song")
    try await waitUntil { playback.requests.count == 2 && store.playbackError != nil }
    XCTAssertNil(store.requestedSeekPosition)
    XCTAssertTrue(store.canSeek)
  }

  func testTrackChangeCancelsSeekAndIgnoresLateCompletion() async throws {
    let reader = SeekTestReader(), playback = SeekTestController()
    playback.hold = true
    let store = makeStore(reader, playback)
    defer { store.shutdown() }
    store.startObserving(); reader.emit(sample())
    store.seek(to: 75, trackIdentifier: "song")
    try await waitUntil { playback.requests.count == 1 }
    var next = sample(); next.trackIdentifier = "next"; next.title = "Next"
    reader.emit(next)
    XCTAssertNil(store.requestedSeekPosition)
    XCTAssertFalse(store.isChangingPlayback)
    playback.complete(); await Task.yield()
    XCTAssertNil(store.playbackError)
    store.seek(to: 100, trackIdentifier: "song")
    await Task.yield()
    XCTAssertEqual(playback.requests.count, 1)
  }

  func testMissingCapabilityInvalidPositionAndStaleStateCannotSeek() async throws {
    let reader = SeekTestReader(), playback = SeekTestController()
    var now = date
    let store = NativeAudioStore(client: reader, playback: playback, isRunning: { true }, now: { now }, observeLifecycle: false)
    defer { store.shutdown() }
    store.startObserving()
    var unsupported = sample(); unsupported.canSeek = false
    reader.emit(unsupported)
    XCTAssertFalse(store.canSeek)
    store.seek(to: 20, trackIdentifier: "song")
    reader.emit(sample()); store.seek(to: .infinity, trackIdentifier: "song")
    store.seek(to: .nan, trackIdentifier: "song")
    now = now.addingTimeInterval(9)
    store.seek(to: 20, trackIdentifier: "song")
    await Task.yield()
    XCTAssertTrue(playback.requests.isEmpty)
    var invalidDuration = sample(); invalidDuration.duration = .greatestFiniteMagnitude
    let track = try XCTUnwrap(NativeNowPlayingTrack(payload: invalidDuration, receivedAt: date))
    XCTAssertFalse(track.canSeek)
    XCTAssertNil(track.duration)
  }

  func testCommandArgumentsAreFiniteBoundedAndLocaleIndependent() {
    XCTAssertEqual(NativePlaybackCommand.seek(position: 12.3456, trackIdentifier: "song").arguments, ["--seek", "12.346", "song"])
    for value in [Double.nan, .infinity, -1, 604_801] {
      XCTAssertNil(NativePlaybackCommand.seek(position: value, trackIdentifier: "song").arguments)
    }
    XCTAssertNil(NativePlaybackCommand.seek(position: 1, trackIdentifier: "").arguments)
    XCTAssertEqual(NativePlaybackPositionView.time(.infinity), "0:00")
  }

  private let date = Date(timeIntervalSince1970: 1000)
  private func sample(playing: Bool = false, elapsed: Double = 10) -> NativeNowPlayingPayload {
    NativeNowPlayingPayload(bundleIdentifier: NativeNowPlayingTrack.neteaseBundleIdentifier,
      title: "Song", playing: playing, duration: 180, elapsed: elapsed, rate: 1,
      trackIdentifier: "song", canSeek: true)
  }
  private func makeStore(_ reader: SeekTestReader, _ playback: SeekTestController,
                         timeout: Duration = .seconds(5)) -> NativeAudioStore {
    NativeAudioStore(client: reader, playback: playback, playbackConfirmationTimeout: timeout,
                     isRunning: { true }, now: { self.date }, observeLifecycle: false)
  }
  private func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0..<100 {
      if condition() { return }
      try await Task.sleep(for: .milliseconds(5))
    }
    XCTFail("Seek state did not settle")
  }
}

@MainActor private final class SeekTestReader: NativeNowPlayingReading {
  var receive: ((Result<NativeNowPlayingPayload, NativeNowPlayingError>) -> Void)?
  func start(_ receive: @escaping (Result<NativeNowPlayingPayload, NativeNowPlayingError>) -> Void) { self.receive = receive }
  func stop() { receive = nil }
  func emit(_ sample: NativeNowPlayingPayload) { receive?(.success(sample)) }
}

@MainActor private final class SeekTestController: NativePlaybackControlling {
  var requests: [NativePlaybackCommand] = []
  var hold = false, fail = false
  var continuation: CheckedContinuation<Void, Never>?
  func send(_ command: NativePlaybackCommand) async throws {
    requests.append(command)
    if hold { await withCheckedContinuation { continuation = $0 } }
    if fail { throw NativeNowPlayingError.unavailable }
  }
  func complete() { continuation?.resume(); continuation = nil }
}
