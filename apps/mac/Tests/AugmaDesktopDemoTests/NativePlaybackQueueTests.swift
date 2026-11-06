import Foundation
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class NativePlaybackQueueTests: XCTestCase {
  func testQueueUsesDisplayOrderAndSkipsUnsupportedOrMalformedEntries() throws {
    let data = Data(#"{"list":[{"displayOrder":2,"track":{"id":"42","name":"Example","artists":[{"name":"Artist"}],"album":{"name":"Album"},"duration":200000}},{"track":null},{"displayOrder":0,"track":{"id":43,"name":"First","artists":[]}},{"track":{"id":"invalid","name":"Bad","artists":[]}},{"track":{"name":" ","artists":[]}},{"displayOrder":1,"track":{"id":"44","name":"Second","artists":[]}},null]}"#.utf8)
    let queue = try NativePlaybackQueue(data: data)
    XCTAssertEqual(queue.items.map(\.track.name), ["First", "Second", "Example"])
    XCTAssertEqual(queue.items.map(\.id), [2, 5, 0])
    XCTAssertEqual(queue.currentItemID(for: try current()), 0)
  }

  func testHighlightRejectsWrongRecordingAndAmbiguousDuplicatePositions() throws {
    let queue = try fixture()
    XCTAssertEqual(queue.currentItemID(for: try current()), 0)
    XCTAssertNil(queue.currentItemID(for: try current(album: "Other version")))
    XCTAssertNil(queue.currentItemID(for: try current(artist: "Arti")))
    XCTAssertNil(queue.currentItemID(for: try current(artist: nil)))
    XCTAssertNil(queue.currentItemID(for: try current(duration: 240)))
    let duplicated = try NativePlaybackQueue(data: Data(#"{"list":[{"track":{"id":42,"name":"Example","artists":[{"name":"Artist"}],"album":{"name":"Album"},"duration":200000}},{"track":{"id":42,"name":"Example","artists":[{"name":"Artist"}],"album":{"name":"Album"},"duration":200000}}]}"#.utf8))
    XCTAssertNil(duplicated.currentItemID(for: try current()), "Do not highlight two positions for the same recording")
  }

  func testEmptyQueueIsDistinctFromAnUnreadableQueueFile() async throws {
    XCTAssertTrue(try NativePlaybackQueue(data: Data(#"{"list":[]}"#.utf8)).items.isEmpty)
    XCTAssertThrowsError(try NativePlaybackQueue(data: Data("broken JSON".utf8)))
    let directory = FileManager.default.temporaryDirectory.appending(path: "augma-queue-tests-\(UUID())")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "playingList")
    let client = NeteasePlaybackQueueClient(url: url)
    do { _ = try await client.read(); XCTFail("Missing queue must be unavailable") } catch {}
    try Data(#"{"list":[]}"#.utf8).write(to: url, options: .atomic)
    let empty = try await client.read()
    XCTAssertTrue(empty.items.isEmpty)
    try Data(repeating: 32, count: 16_777_217).write(to: url, options: .atomic)
    do { _ = try await client.read(); XCTFail("Reject an oversized queue") } catch {}
  }

  func testQueueOnlyReadsWhileVisibleAndSharesOneRequestAcrossWindows() async throws {
    let client = QueueTestClient(queue: try fixture())
    let store = NativePlaybackQueueStore(client: client)
    defer { store.shutdown() }
    store.update(try current())
    await Task.yield()
    let initialReads = await client.reads
    XCTAssertEqual(initialReads, 0)
    store.startObserving(); store.startObserving()
    try await waitUntil { if case .available = store.state { true } else { false } }
    let firstReads = await client.reads
    XCTAssertEqual(firstReads, 1)
    XCTAssertEqual(store.currentItemID, 0)
    store.update(try current(title: "Other", artist: "Other Artist", album: "Other Album", duration: 100))
    XCTAssertEqual(store.currentItemID, 1)
    store.stopObserving()
    store.refresh()
    for _ in 0..<100 {
      if await client.reads == 2 { break }
      try await Task.sleep(for: .milliseconds(5))
    }
    let sharedReads = await client.reads
    XCTAssertEqual(sharedReads, 2, "Closing one of two queue views must keep observation active")
    XCTAssertEqual(store.currentItemID, 1)
    store.stopObserving()
    XCTAssertEqual(store.state, .idle)
    XCTAssertNil(store.currentItemID)
    let stoppedReads = await client.reads
    store.refresh(); await Task.yield()
    let hiddenReads = await client.reads
    XCTAssertEqual(stoppedReads, hiddenReads)
  }

  func testLosingMediaSessionClearsQueueAndIgnoresLateResults() async throws {
    let client = QueueTestClient(queue: try fixture())
    await client.hold()
    let store = NativePlaybackQueueStore(client: client)
    store.startObserving(); store.update(try current())
    for _ in 0..<100 {
      if await client.reads == 1 { break }
      try await Task.sleep(for: .milliseconds(5))
    }
    store.update(nil)
    await client.complete()
    await Task.yield()
    XCTAssertEqual(store.state, .idle)
    XCTAssertNil(store.currentItemID)
    store.update(try current())
    try await waitUntil { if case .available = store.state { true } else { false } }
    XCTAssertEqual(store.currentItemID, 0)
    store.shutdown()
    XCTAssertEqual(store.state, .idle)
    store.update(try current()); store.refresh()
    XCTAssertEqual(store.state, .idle)
  }

  func testQueueReadFailureCanBeRetriedWithoutKeepingAStaleHighlight() async throws {
    let client = QueueTestClient(queue: try fixture())
    let store = NativePlaybackQueueStore(client: client)
    defer { store.shutdown() }
    store.update(try current()); store.startObserving()
    try await waitUntil { store.currentItemID == 0 }
    await client.fail(true)
    store.refresh()
    try await waitUntil { store.state == .unavailable }
    XCTAssertNil(store.currentItemID)
    await client.fail(false)
    store.refresh()
    try await waitUntil { store.currentItemID == 0 }
  }

  private func fixture() throws -> NativePlaybackQueue {
    try NativePlaybackQueue(data: Data(#"{"list":[{"track":{"id":42,"name":"Example","artists":[{"name":"Artist"}],"album":{"name":"Album"},"duration":200000}},{"track":{"id":43,"name":"Other","artists":[{"name":"Other Artist"}],"album":{"name":"Other Album"},"duration":100000}}]}"#.utf8))
  }

  private func current(title: String = "Example", artist: String? = "Artist", album: String = "Album",
                       duration: Double = 200) throws -> NativeNowPlayingTrack {
    try XCTUnwrap(NativeNowPlayingTrack(payload: .init(bundleIdentifier: NativeNowPlayingTrack.neteaseBundleIdentifier,
      title: title, artist: artist, album: album, playing: true, duration: duration), receivedAt: .now))
  }

  private func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0..<100 {
      if condition() { return }
      try await Task.sleep(for: .milliseconds(5))
    }
    XCTFail("Queue state did not settle")
  }
}

private actor QueueTestClient: NativePlaybackQueueReading {
  let queue: NativePlaybackQueue
  private(set) var reads = 0
  private var failing = false
  private var holding = false
  private var continuation: CheckedContinuation<Void, Never>?
  init(queue: NativePlaybackQueue) { self.queue = queue }
  func read() async throws -> NativePlaybackQueue {
    reads += 1
    if holding { await withCheckedContinuation { continuation = $0 } }
    if failing { throw NativeNowPlayingError.unavailable }
    return queue
  }
  func hold() { holding = true }
  func complete() { holding = false; continuation?.resume(); continuation = nil }
  func fail(_ value: Bool) { failing = value }
}
