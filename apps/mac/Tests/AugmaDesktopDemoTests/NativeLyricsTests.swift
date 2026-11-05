import Foundation
import XCTest
@testable import AugmaDesktopDemo

final class NativeLyricsTests: XCTestCase {
  func testLRCHandlesRepeatedTimestampsOffsetsWordTagsAndTranslations() {
    let lines = LRCParser.parse("[ar:Artist]\n[offset:500]\n[00:01.50][00:03.500]<00:01.50>First\n[00:03.50]Second\n[00:02.00]\n[00:80.00]invalid",
      translation: "[00:01.00]Translation\n[00:03.00]Later translation")
    XCTAssertEqual(lines.map(\.time), [1, 1.5, 3])
    XCTAssertEqual(lines[0].text, "First")
    XCTAssertEqual(lines[0].translation, "Translation")
    XCTAssertEqual(lines[2].text, "First\nSecond")
    XCTAssertEqual(lines[2].translation, "Later translation")
  }

  func testActiveLineFollowsProgressAndRewindsWithoutSeekingThePlayer() {
    let doc = LyricsDocument(source: .netease, original: "[00:10.00]One\n[00:20.00]Two\n[00:30.00]Three")
    XCTAssertNil(doc.activeLine(at: 9))
    XCTAssertEqual(doc.activeLine(at: 10), 0)
    XCTAssertEqual(doc.activeLine(at: 20.5), 1)
    XCTAssertEqual(doc.activeLine(at: 100), 2)
    XCTAssertEqual(doc.activeLine(at: 11), 0)
    XCTAssertNil(doc.activeLine(at: .nan))
  }

  func testLocalQueueMatchesExactRecordingAndRejectsAmbiguousIDs() throws {
    let fixture = try LyricsFixture()
    defer { fixture.remove() }
    let resolver = NeteaseSongIDResolver(queueURL: fixture.queue)
    XCTAssertEqual(resolver.songID(for: identity), "42")
    let wrongVersion = LyricsTrackIdentity(title: "Example", artist: "Artist", album: "Album", duration: 240)
    XCTAssertNil(resolver.songID(for: wrongVersion))
    let wrongArtist = LyricsTrackIdentity(title: "Example", artist: "Another Artist", album: "Album", duration: 200)
    XCTAssertNil(resolver.songID(for: wrongArtist))
    var entries = try JSONSerialization.jsonObject(with: Data(contentsOf: fixture.queue)) as! [String: [[String: Any]]]
    var duplicate = entries["list"]![0]
    var track = duplicate["track"] as! [String: Any]; track["id"] = "43"; duplicate["track"] = track
    entries["list"]!.append(duplicate)
    try JSONSerialization.data(withJSONObject: entries).write(to: fixture.queue)
    XCTAssertNil(resolver.songID(for: identity))
  }

  func testArtistsAcceptAnExactCreditedNameOrFullListButNeverPartialNames() {
    XCTAssertTrue(NeteaseSongIDResolver.artistsMatch("A / B", ["A", "B"]))
    XCTAssertTrue(NeteaseSongIDResolver.artistsMatch("A", ["A", "B"]))
    XCTAssertFalse(NeteaseSongIDResolver.artistsMatch("Arti", ["Artist", "Another Artist"]))
    XCTAssertTrue(NeteaseSongIDResolver.artistsMatch("AC/DC", ["AC/DC"]))
  }

  func testNetEaseIsFirstAndFreshServiceLoadsCacheOffline() async throws {
    let fixture = try LyricsFixture()
    defer { fixture.remove() }
    let http = LyricsHTTPFixture(netease: #"{"code":200,"lrc":{"lyric":"[00:01.00]One\n[00:02.00]Two"},"tlyric":{"lyric":"[00:01.00]Translation"}}"#)
    let service = OnlineLyricsService(cache: fixture.cache, resolver: .init(queueURL: fixture.queue), transport: { try await http.send($0) })
    let fetched = try await service.lyrics(for: identity)
    let result = try XCTUnwrap(fetched)
    XCTAssertEqual(result.document.source, .netease)
    XCTAssertEqual(result.document.sourceID, "42")
    XCTAssertEqual(result.document.lines.count, 2)
    XCTAssertEqual(result.document.lines[0].translation, "Translation")
    XCTAssertFalse(result.cached)
    let requests = await http.requests
    XCTAssertEqual(requests.map { $0.url?.host }, ["music.163.com"])
    XCTAssertFalse(requests[0].httpShouldHandleCookies)
    XCTAssertNil(requests[0].value(forHTTPHeaderField: "Cookie"))
    XCTAssertTrue(requests[0].url?.query?.contains("id=42") == true)
    let offline = LyricsHTTPFixture(offline: true)
    let restored = OnlineLyricsService(cache: fixture.cache, resolver: .init(queueURL: fixture.queue), transport: { try await offline.send($0) })
    let restoredValue = try await restored.lyrics(for: identity)
    let cached = try XCTUnwrap(restoredValue)
    XCTAssertTrue(cached.cached)
    XCTAssertEqual(cached.document, result.document)
    let offlineRequests = await offline.requests
    XCTAssertTrue(offlineRequests.isEmpty)
  }

  func testNetEaseFailureFallsBackToMatchedLRCLIB() async throws {
    let fixture = try LyricsFixture()
    defer { fixture.remove() }
    let http = LyricsHTTPFixture(neteaseStatus: 503, lrclib: matchingLRCLIB)
    let service = OnlineLyricsService(cache: fixture.cache, resolver: .init(queueURL: fixture.queue), transport: { try await http.send($0) })
    let fetched = try await service.lyrics(for: identity)
    let result = try XCTUnwrap(fetched)
    XCTAssertEqual(result.document.source, .lrclib)
    let requests = await http.requests
    XCTAssertEqual(requests.map { $0.url?.host }, ["music.163.com", "lrclib.net"])
  }

  func testMissingQueueUsesLRCLIBAndWrongVersionIsRejected() async throws {
    let fixture = try LyricsFixture()
    defer { fixture.remove() }
    try FileManager.default.removeItem(at: fixture.queue)
    let http = LyricsHTTPFixture(lrclib: matchingLRCLIB.replacingOccurrences(of: "200,", with: "240,"))
    let service = OnlineLyricsService(cache: fixture.cache, resolver: .init(queueURL: fixture.queue), transport: { try await http.send($0) })
    let result = try await service.lyrics(for: identity)
    XCTAssertNil(result)
    XCTAssertNil(fixture.cache.load(identity))
    let requests = await http.requests
    XCTAssertEqual(requests.map { $0.url?.host }, ["lrclib.net"])
  }

  func testMalformedNetEaseFallsBackAndNotFoundIsDistinctFromOffline() async throws {
    let fixture = try LyricsFixture()
    defer { fixture.remove() }
    let http = LyricsHTTPFixture(netease: "not JSON", lrclib: matchingLRCLIB)
    let service = OnlineLyricsService(cache: fixture.cache, resolver: .init(queueURL: fixture.queue), transport: { try await http.send($0) })
    let result = try await service.lyrics(for: identity)
    XCTAssertEqual(result?.document.source, .lrclib)
    let missing = LyricsHTTPFixture(netease: #"{"code":200}"#, lrclibStatus: 404)
    let noCache = LyricsDiskCache(directory: fixture.root.appending(path: "missing-cache"))
    let noLyrics = OnlineLyricsService(cache: noCache, resolver: .init(queueURL: fixture.queue), transport: { try await missing.send($0) })
    let noResult = try await noLyrics.lyrics(for: identity)
    XCTAssertNil(noResult)
    let offline = LyricsHTTPFixture(offline: true)
    let unavailable = OnlineLyricsService(cache: noCache, resolver: .init(queueURL: fixture.queue), transport: { try await offline.send($0) })
    do { _ = try await unavailable.lyrics(for: identity); XCTFail("Expected a recoverable network error") } catch is LyricsError { }
  }

  func testInstrumentalPlainLyricsAndCacheValidation() async throws {
    let fixture = try LyricsFixture()
    defer { fixture.remove() }
    let http = LyricsHTTPFixture(netease: #"{"code":200,"nolyric":true}"#)
    let service = OnlineLyricsService(cache: fixture.cache, resolver: .init(queueURL: fixture.queue), transport: { try await http.send($0) })
    let fetched = try await service.lyrics(for: identity)
    let result = try XCTUnwrap(fetched)
    XCTAssertTrue(result.document.instrumental)
    let plain = LyricsDocument(source: .lrclib, plainText: "Plain lyric text")
    XCTAssertTrue(plain.isUsable)
    XCTAssertTrue(plain.lines.isEmpty)
    try Data("corrupt".utf8).write(to: fixture.cache.fileURL(identity))
    XCTAssertNil(fixture.cache.load(identity))
    let bounded = LyricsDiskCache(directory: fixture.root.appending(path: "bounded-cache"), maximumEntries: 2)
    for value in 0..<3 {
      bounded.save(plain, for: LyricsTrackIdentity(title: "Track \(value)", artist: "Artist", album: nil, duration: 200))
    }
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: bounded.directory.path).count, 2)
  }

  private var identity: LyricsTrackIdentity { .init(title: "Example", artist: "Artist", album: "Album", duration: 200) }
  private var matchingLRCLIB: String { #"{"id":7,"trackName":"Example","artistName":"Artist","albumName":"Album","duration":200,"syncedLyrics":"[00:01.00]One"}"# }
}

@MainActor
final class NativeLyricsStoreTests: XCTestCase {
  func testProgressSamplesDoNotRefetchAndLateSongCannotReplaceCurrentLyrics() async throws {
    let provider = DelayedLyricsProvider()
    let store = NativeLyricsStore(service: provider)
    let first = makeTrack("First", elapsed: 1)
    store.update(first)
    await waitUntil { await provider.count == 1 }
    store.update(makeTrack("First", elapsed: 20))
    let count = await provider.count
    XCTAssertEqual(count, 1)
    store.update(makeTrack("Second", elapsed: 0))
    await waitUntil { await provider.count == 2 }
    await provider.finish(1)
    await waitUntil {
      if case .available(let value) = store.state { return value.document.plainText == "Second" }
      return false
    }
    await provider.finish(0)
    await Task.yield()
    guard case .available(let result) = store.state else { return XCTFail("Expected current lyrics") }
    XCTAssertEqual(result.document.plainText, "Second")
    store.clear()
    if case .idle = store.state { } else { XCTFail("Old lyrics must disappear without a current track") }
  }

  private func makeTrack(_ title: String, elapsed: Double) -> NativeNowPlayingTrack {
    NativeNowPlayingTrack(payload: .init(bundleIdentifier: NativeNowPlayingTrack.neteaseBundleIdentifier, title: title, artist: "Artist", playing: true, duration: 200, elapsed: elapsed), receivedAt: .now)!
  }

  private func waitUntil(_ condition: () async -> Bool) async {
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while !(await condition()), ContinuousClock.now < deadline { try? await Task.sleep(for: .milliseconds(2)) }
    let ready = await condition()
    XCTAssertTrue(ready)
  }
}

private actor DelayedLyricsProvider: LyricsProviding {
  private var pending: [(String, CheckedContinuation<LyricsLookupResult?, Never>)] = []
  var count: Int { pending.count }
  func lyrics(for track: LyricsTrackIdentity) async throws -> LyricsLookupResult? {
    await withCheckedContinuation { pending.append((track.title, $0)) }
  }
  func finish(_ index: Int) {
    let (title, continuation) = pending[index]
    continuation.resume(returning: .init(document: .init(source: .lrclib, plainText: title), cached: false))
  }
}

private actor LyricsHTTPFixture {
  private(set) var requests: [URLRequest] = []
  let netease: String
  let neteaseStatus: Int
  let lrclib: String
  let lrclibStatus: Int
  let offline: Bool
  init(netease: String = #"{"code":200}"#, neteaseStatus: Int = 200, lrclib: String = "{}", lrclibStatus: Int = 200, offline: Bool = false) {
    self.netease = netease; self.neteaseStatus = neteaseStatus; self.lrclib = lrclib; self.lrclibStatus = lrclibStatus; self.offline = offline
  }
  func send(_ request: URLRequest) throws -> (Data, Int) {
    requests.append(request)
    if offline { throw URLError(.notConnectedToInternet) }
    return request.url?.host == "music.163.com" ? (Data(netease.utf8), neteaseStatus) : (Data(lrclib.utf8), lrclibStatus)
  }
}

private struct LyricsFixture {
  let root: URL
  var queue: URL { root.appending(path: "playingList") }
  var cache: LyricsDiskCache { .init(directory: root.appending(path: "cache")) }
  init() throws {
    root = FileManager.default.temporaryDirectory.appending(path: "augma-lyrics-tests-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data(#"{"list":[{"track":{"id":"42","name":"Example","artists":[{"name":"Artist"}],"album":{"name":"Album"},"duration":200000}}]}"#.utf8).write(to: queue)
  }
  func remove() { try? FileManager.default.removeItem(at: root) }
}
