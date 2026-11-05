import Foundation
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class NativeAudioTests: XCTestCase {
  func testOnlyNeteaseWithANonemptyTitleIsAccepted() throws {
    var payload = sample()
    XCTAssertEqual(try XCTUnwrap(track(payload)).title, "Example")
    payload.bundleIdentifier = "com.apple.Music"
    XCTAssertNil(track(payload))
    payload.bundleIdentifier = NativeNowPlayingTrack.neteaseBundleIdentifier
    payload.title = " \n "
    XCTAssertNil(track(payload))
  }

  func testProgressUsesPlayerTimestampAndFreezesWhilePaused() throws {
    var payload = sample()
    payload.elapsed = 20; payload.timestamp = 990; payload.duration = 100
    let playing = try XCTUnwrap(track(payload))
    XCTAssertEqual(playing.elapsed, 30)
    XCTAssertEqual(playing.elapsed(at: Date(timeIntervalSince1970: 1005)), 35)
    XCTAssertEqual(playing.elapsed(at: Date(timeIntervalSince1970: 2000)), 100)
    payload.playing = false
    let paused = try XCTUnwrap(track(payload))
    XCTAssertEqual(paused.elapsed, 20)
    XCTAssertEqual(paused.elapsed(at: Date(timeIntervalSince1970: 2000)), 20)
  }

  func testMissingAndInvalidProgressIsNotInvented() throws {
    var payload = sample()
    let missing = try XCTUnwrap(track(payload))
    XCTAssertNil(missing.elapsed)
    XCTAssertNil(missing.duration)
    XCTAssertNil(missing.lyrics)
    payload.duration = -.infinity; payload.elapsed = .nan; payload.rate = .infinity
    let invalid = try XCTUnwrap(track(payload))
    XCTAssertNil(invalid.elapsed)
    XCTAssertNil(invalid.duration)
    XCTAssertEqual(invalid.rate, 1)
    payload.elapsed = 8; payload.timestamp = 2000
    XCTAssertEqual(track(payload)?.elapsed, 8, "A future timestamp cannot rewind progress")
  }

  func testOptionalArtworkAndLyricsAreDecodedFromTheLocalPayload() throws {
    let data = Data(#"{"bundleIdentifier":"com.netease.163music","title":"Example","artwork":"AQID","lyrics":"sample line"}"#.utf8)
    let payload = try JSONDecoder().decode(NativeNowPlayingPayload.self, from: data)
    let value = try XCTUnwrap(track(payload))
    XCTAssertEqual(value.artwork, Data([1, 2, 3]))
    XCTAssertEqual(value.lyrics, "sample line")
  }

  func testStoreSharesOneReaderAndClearsStaleOrUnrelatedInformation() {
    let reader = TestNowPlayingReader()
    var running = true
    var date = Date(timeIntervalSince1970: 1000)
    let store = NativeAudioStore(client: reader, isRunning: { running }, now: { date }, observeLifecycle: false)
    defer { store.shutdown() }
    store.startObserving(); store.startObserving()
    XCTAssertEqual(reader.starts, 1)
    reader.emit(.success(sample()))
    guard case .track = store.status else { return XCTFail("Expected the current track") }
    var unrelated = sample(); unrelated.bundleIdentifier = "com.apple.Music"
    reader.emit(.success(unrelated))
    XCTAssertEqual(store.status, .idle)
    reader.emit(.success(sample()))
    date = date.addingTimeInterval(9); store.checkFreshness()
    XCTAssertEqual(store.status, .unavailable)
    store.refresh(); reader.emit(.success(sample()))
    running = false; store.checkFreshness()
    XCTAssertEqual(store.status, .notRunning)
  }

  func testNotRunningFailureSleepAndShutdownNeverControlPlayback() {
    let reader = TestNowPlayingReader()
    var running = false
    let store = NativeAudioStore(client: reader, isRunning: { running }, observeLifecycle: false)
    store.startObserving()
    XCTAssertEqual(store.status, .notRunning)
    XCTAssertEqual(reader.starts, 0)
    running = true; store.refresh()
    reader.emit(.failure(.unavailable))
    XCTAssertEqual(store.status, .unavailable)
    store.setSleeping(true)
    reader.emit(.success(sample()))
    XCTAssertEqual(store.status, .loading)
    store.setSleeping(false)
    XCTAssertEqual(reader.starts, 2)
    reader.emit(.success(sample()))
    guard case .track = store.status else { return XCTFail("Expected wake to resume observation") }
    store.shutdown(); store.refresh(); reader.emit(.success(sample()))
    XCTAssertEqual(store.status, .idle)
    XCTAssertEqual(reader.starts, 2)
  }

  private func sample() -> NativeNowPlayingPayload {
    NativeNowPlayingPayload(bundleIdentifier: NativeNowPlayingTrack.neteaseBundleIdentifier, title: "Example", playing: true)
  }

  private func track(_ payload: NativeNowPlayingPayload) -> NativeNowPlayingTrack? {
    NativeNowPlayingTrack(payload: payload, receivedAt: Date(timeIntervalSince1970: 1000))
  }
}

@MainActor
private final class TestNowPlayingReader: NativeNowPlayingReading {
  var starts = 0
  private var receive: ((Result<NativeNowPlayingPayload, NativeNowPlayingError>) -> Void)?
  func start(_ receive: @escaping (Result<NativeNowPlayingPayload, NativeNowPlayingError>) -> Void) {
    starts += 1; self.receive = receive
  }
  func stop() { receive = nil }
  func emit(_ value: Result<NativeNowPlayingPayload, NativeNowPlayingError>) { receive?(value) }
}
