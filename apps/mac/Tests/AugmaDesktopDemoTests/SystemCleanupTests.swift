import AppKit
import SwiftUI
import XCTest
@testable import AugmaDesktopDemo

final class SystemCleanupTests: XCTestCase {
  func testScanOnlyIncludesOldInstallersAndEntirelyInactiveDerivedData() async throws {
    let fixture = try CleanupFixture()
    defer { fixture.remove() }
    try fixture.file("Downloads/old.dmg", old: true)
    try fixture.file("Downloads/new.pkg")
    try fixture.file("Downloads/personal.zip", old: true)
    try fixture.file("Documents/private.dmg", old: true)
    try fixture.file("Library/Developer/Xcode/DerivedData/Old/Build/object", old: true)
    try fixture.age("Library/Developer/Xcode/DerivedData/Old/Build")
    try fixture.age("Library/Developer/Xcode/DerivedData/Old")
    try fixture.file("Library/Developer/Xcode/DerivedData/Active/Build/object")
    try fixture.age("Library/Developer/Xcode/DerivedData/Active/Build")
    try fixture.age("Library/Developer/Xcode/DerivedData/Active")
    let scan = try await fixture.scanner().scan()
    XCTAssertFalse(scan.incomplete)
    XCTAssertEqual(Set(scan.candidates.map { $0.url.lastPathComponent }), ["old.dmg", "Old"])
    XCTAssertTrue(scan.candidates.allSatisfy { $0.bytes > 0 && !$0.fingerprint.isEmpty })
  }

  func testTrashRevalidatesFilesAndMovesOnlySelectedCatalogItems() async throws {
    let fixture = try CleanupFixture()
    defer { fixture.remove() }
    for name in ["selected.dmg", "changed.dmg", "keep.pkg"] { try fixture.file("Downloads/" + name, old: true) }
    let scanner = fixture.scanner()
    let scan = try await scanner.scan()
    let selected = try XCTUnwrap(scan.candidates.first { $0.url.lastPathComponent == "selected.dmg" })
    let changed = try XCTUnwrap(scan.candidates.first { $0.url.lastPathComponent == "changed.dmg" })
    try fixture.file("Downloads/changed.dmg")
    let outcome = await scanner.moveToTrash(ids: [selected.id, changed.id, UUID()])
    XCTAssertEqual(outcome.moved, [selected.id])
    XCTAssertEqual(outcome.failures.count, 2)
    XCTAssertTrue(fixture.exists("Trash/selected.dmg"))
    XCTAssertTrue(fixture.exists("Downloads/changed.dmg"))
    XCTAssertTrue(fixture.exists("Downloads/keep.pkg"))
  }

  func testChangedDescendantAndReplacedRootCannotBeTrashed() async throws {
    let fixture = try CleanupFixture()
    defer { fixture.remove() }
    let base = "Library/Developer/Xcode/DerivedData/Old"
    try fixture.file(base + "/object", old: true)
    try fixture.age(base)
    let scanner = fixture.scanner()
    let scan = try await scanner.scan()
    let candidate = try XCTUnwrap(scan.candidates.first)
    // Keep both the root mtime and byte count unchanged; the nested identity/date still changes.
    try fixture.file(base + "/object")
    try fixture.age(base + "/object", days: 9)
    try fixture.age(base)
    let outcome = await scanner.moveToTrash(ids: [candidate.id])
    XCTAssertTrue(outcome.moved.isEmpty)
    XCTAssertEqual(outcome.failures.count, 1)
    let fresh = try await scanner.scan()
    let freshCandidate = try XCTUnwrap(fresh.candidates.first)
    try FileManager.default.moveItem(at: fixture.url(base), to: fixture.url(base + "-moved"))
    try FileManager.default.createSymbolicLink(at: fixture.url(base), withDestinationURL: fixture.url(base + "-moved"))
    let linked = await scanner.moveToTrash(ids: [freshCandidate.id])
    XCTAssertTrue(linked.moved.isEmpty)
    XCTAssertTrue(fixture.exists(base + "-moved/object"))
  }

  func testLinksAreNotFollowedAndNewScanInvalidatesOldIDs() async throws {
    let fixture = try CleanupFixture()
    defer { fixture.remove() }
    try fixture.file("Outside/private.dmg", old: true)
    try FileManager.default.createSymbolicLink(at: fixture.url("Downloads"), withDestinationURL: fixture.url("Outside"))
    let scanner = fixture.scanner()
    let linkedRoot = try await scanner.scan()
    XCTAssertTrue(linkedRoot.candidates.isEmpty)
    XCTAssertTrue(linkedRoot.incomplete)
    try FileManager.default.removeItem(at: fixture.url("Downloads"))
    try fixture.file("Downloads/old.dmg", old: true)
    let first = try await scanner.scan()
    let candidate = try XCTUnwrap(first.candidates.first)
    _ = try await scanner.scan()
    let obsolete = await scanner.moveToTrash(ids: [candidate.id])
    XCTAssertTrue(obsolete.moved.isEmpty)
    XCTAssertTrue(fixture.exists("Downloads/old.dmg"))
    XCTAssertTrue(fixture.exists("Outside/private.dmg"))
  }

  func testNestedLinkRecordsOnlyTheLinkAndNotItsDestination() async throws {
    let fixture = try CleanupFixture()
    defer { fixture.remove() }
    let base = "Library/Developer/Xcode/DerivedData/Old"
    try fixture.file(base + "/object", old: true)
    try fixture.file("Outside/recent-secret")
    try FileManager.default.createSymbolicLink(at: fixture.url(base + "/link"), withDestinationURL: fixture.url("Outside"))
    // touch -h equivalent: setting FileManager attributes follows symlinks on some OS versions.
    var times = [timeval(tv_sec: Int(fixture.old.timeIntervalSince1970), tv_usec: 0),
                 timeval(tv_sec: Int(fixture.old.timeIntervalSince1970), tv_usec: 0)]
    XCTAssertEqual(lutimes(fixture.url(base + "/link").path, &times), 0)
    try fixture.age(base)
    let scanner = fixture.scanner()
    let scan = try await scanner.scan()
    let candidate = try XCTUnwrap(scan.candidates.first)
    let outcome = await scanner.moveToTrash(ids: [candidate.id])
    XCTAssertEqual(outcome.moved, [candidate.id])
    XCTAssertTrue(fixture.exists("Outside/recent-secret"))
  }

  func testBoundedAndCancelledScansDoNotOfferPartiallyInspectedTrees() async throws {
    let fixture = try CleanupFixture()
    defer { fixture.remove() }
    try fixture.file("Library/Developer/Xcode/DerivedData/Old/a", old: true)
    try fixture.file("Library/Developer/Xcode/DerivedData/Old/b", old: true)
    try fixture.age("Library/Developer/Xcode/DerivedData/Old")
    let limited = try await fixture.scanner(maximumEntries: 2).scan()
    XCTAssertTrue(limited.incomplete)
    XCTAssertTrue(limited.candidates.isEmpty)
    let scanner = fixture.scanner()
    let task = Task { withUnsafeCurrentTask { $0?.cancel() }; return try await scanner.scan() }
    do { _ = try await task.value; XCTFail("Cancelled scans must stop") }
    catch is CancellationError {}
  }

  func testAdvicePayloadOmitsNamesAndPathsAndRejectsExecutableOrUnknownActions() throws {
    let candidate = CleanupCandidate(id: UUID(), url: URL(filePath: "/private/secret/secret-installer.dmg"),
                                     category: .installers, bytes: 4_096, fingerprint: "test")
    let scan = CleanupScan(candidates: [candidate])
    let snapshot = SystemSnapshot(memory: MemoryUsage(total: 100, used: 99, compressed: 10, swapUsed: 20, pressure: .normal),
      applicationMemory: ApplicationMemorySnapshot(applications: [ApplicationMemoryUsage(application:
        ApplicationMemoryIdentity(processIdentifier: 42, name: "Secret App", bundlePath: "/Applications/Secret.app"),
        physicalFootprint: 50, processCount: 1, measuredProcessCount: 1)]),
      disks: [DiskUsage(id: "secret-volume", name: "Private disk", total: 100, available: 10)])
    let messages = try CleanupAdvice.messages(scan: scan, snapshot: snapshot, locale: "zh-Hans")
    let payload = try XCTUnwrap(messages.last?["content"])
    for secret in ["secret", "Secret", "Private", "42", "Applications/"] { XCTAssertFalse(payload.contains(secret)) }
    XCTAssertTrue(payload.contains("app1"))
    XCTAssertTrue(payload.contains("normal"))
    let valid = #"{"summary":"请先检查旧安装包。","categories":["installers"],"applications":["app1"]}"#
    XCTAssertEqual(try CleanupAdvice.parse(valid, scan: scan, applicationIDs: ["app1"]).categories, [.installers])
    for invalid in [
      #"{"summary":"a","categories":["xcode"],"applications":[]}"#,
      #"{"summary":"a","categories":[],"applications":["app2"]}"#,
      #"{"summary":"a","categories":[],"applications":[],"command":"rm -rf /"}"#,
      #"{"summary":"a","categories":["installers","installers"],"applications":[]}"#,
    ] { XCTAssertThrowsError(try CleanupAdvice.parse(invalid, scan: scan, applicationIDs: ["app1"])) }
  }

  func testQuitIdentityRejectsPIDReuseDifferentBundlesAndTheHostApp() {
    let date = Date(timeIntervalSince1970: 1_000)
    let identity = ApplicationMemoryIdentity(processIdentifier: 42, name: "App", bundlePath: "/Applications/App.app", launchedAt: date)
    XCTAssertTrue(ApplicationCleanup.matches(identity, pid: 42, bundlePath: identity.bundlePath, launchedAt: date, ownPID: 1))
    XCTAssertFalse(ApplicationCleanup.matches(identity, pid: 42, bundlePath: identity.bundlePath, launchedAt: date.addingTimeInterval(1), ownPID: 1))
    XCTAssertFalse(ApplicationCleanup.matches(identity, pid: 42, bundlePath: "/Applications/Other.app", launchedAt: date, ownPID: 1))
    XCTAssertFalse(ApplicationCleanup.matches(identity, pid: 42, bundlePath: identity.bundlePath, launchedAt: date, ownPID: 42))
  }

  @MainActor func testStoreDoesNotAutoSelectAndDiscardsLateAIRepliesAfterCancellation() async throws {
    let fixture = try CleanupFixture()
    defer { fixture.remove() }
    try fixture.file("Downloads/old.dmg", old: true)
    let completion = DelayedCleanupCompletion()
    let store = SystemCleanupStore(scanner: fixture.scanner(), completion: { _, _ in await completion.wait() })
    store.startScan()
    try await waitUntil { !store.isBusy }
    XCTAssertEqual(store.scan?.candidates.count, 1)
    XCTAssertTrue(store.selection.isEmpty)
    store.analyze(snapshot: SystemSnapshot(), apiKey: "test-only")
    try await waitUntil { await completion.started }
    store.cancel()
    await completion.finish()
    try await Task.sleep(for: .milliseconds(20))
    XCTAssertNil(store.advice)
    XCTAssertEqual(store.phase, .idle)
    XCTAssertTrue(fixture.exists("Downloads/old.dmg"))
  }

  @MainActor func testAdviceSuccessCannotSelectOrTrashFilesAndTrashFailuresRemainVisible() async throws {
    let fixture = try CleanupFixture()
    defer { fixture.remove() }
    try fixture.file("Downloads/old.dmg", old: true)
    let date = fixture.current
    let scanner = SystemCleanupScanner(home: fixture.home, now: { date }, trash: { _ in
      throw CocoaError(.fileWriteNoPermission)
    })
    let store = SystemCleanupStore(scanner: scanner, completion: { _, _ in
      #"{"summary":"检查安装包","categories":["installers"],"applications":[]}"#
    })
    store.startScan()
    try await waitUntil { !store.isBusy }
    store.analyze(snapshot: SystemSnapshot(), apiKey: "test-only")
    try await waitUntil { !store.isBusy }
    XCTAssertEqual(store.advice?.categories, [.installers])
    XCTAssertTrue(store.selection.isEmpty)
    let candidate = try XCTUnwrap(store.scan?.candidates.first)
    store.moveToTrash(ids: [candidate.id])
    try await waitUntil { !store.isBusy }
    XCTAssertEqual(store.scan?.candidates.count, 1)
    XCTAssertTrue(store.feedback.contains("old.dmg"))
    XCTAssertTrue(fixture.exists("Downloads/old.dmg"))
  }

  @MainActor func testCleanupPanelRendersAtNarrowAndWideWidthsInBothAppearances() async throws {
    let fixture = try CleanupFixture()
    defer { fixture.remove() }
    try fixture.file("Downloads/Augma-very-long-installer-name-for-layout.dmg", old: true)
    let store = SystemCleanupStore(scanner: fixture.scanner())
    store.startScan()
    try await waitUntil { !store.isBusy }
    let domain = "augma-cleanup-layout-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let monitor = SystemMonitorStore(defaults: defaults, observeLifecycle: false)
    monitor.enabled = false
    for width in [480, 700] {
      for dark in [false, true] {
        let content = SystemCleanupView(monitor: monitor, store: store)
          .frame(width: CGFloat(width), height: 740)
          .background(Color(nsColor: .windowBackgroundColor))
          .environment(\.colorScheme, dark ? .dark : .light)
        let host = NSHostingView(rootView: content)
        host.frame = NSRect(x: 0, y: 0, width: width, height: 740)
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(host.fittingSize.width, CGFloat(width), accuracy: 1)
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        if let directory = ProcessInfo.processInfo.environment["AUGMA_RENDER_CLEANUP_DIR"] {
          try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
          try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(to: URL(filePath: directory).appendingPathComponent("cleanup-\(width)-\(dark ? "dark" : "light").png"))
        }
      }
    }
  }

  @MainActor private func waitUntil(_ condition: () async -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(3))
    while !(await condition()), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(2)) }
    let completed = await condition()
    XCTAssertTrue(completed)
  }
}

private struct CleanupFixture: Sendable {
  let home: URL
  let current = Date(timeIntervalSince1970: 1_800_000_000)
  var old: Date { current.addingTimeInterval(-10 * 86_400) }
  init() throws {
    home = FileManager.default.temporaryDirectory.appendingPathComponent("augma-cleanup-" + UUID().uuidString).resolvingSymlinksInPath()
    try FileManager.default.createDirectory(at: home.appendingPathComponent("Trash"), withIntermediateDirectories: true)
  }
  func url(_ path: String) -> URL { home.appendingPathComponent(path) }
  func exists(_ path: String) -> Bool { FileManager.default.fileExists(atPath: url(path).path) }
  func file(_ path: String, old: Bool = false) throws {
    let target = url(path)
    try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(repeating: 1, count: 4_096).write(to: target)
    try FileManager.default.setAttributes([.modificationDate: old ? self.old : current], ofItemAtPath: target.path)
  }
  func age(_ path: String, days: Double = 10) throws {
    try FileManager.default.setAttributes([.modificationDate: current.addingTimeInterval(-days * 86_400)], ofItemAtPath: url(path).path)
  }
  func scanner(maximumEntries: Int = 50_000) -> SystemCleanupScanner {
    let date = current
    let destination = url("Trash")
    return SystemCleanupScanner(home: home, maximumEntries: maximumEntries, now: { date }, trash: { source in
      try FileManager.default.moveItem(at: source, to: destination.appendingPathComponent(source.lastPathComponent))
    })
  }
  func remove() { try? FileManager.default.removeItem(at: home) }
}

private actor DelayedCleanupCompletion {
  private(set) var started = false
  private var continuation: CheckedContinuation<String, Never>?
  func wait() async -> String {
    started = true
    return await withCheckedContinuation { continuation = $0 }
  }
  func finish() {
    continuation?.resume(returning: #"{"summary":"建议","categories":["installers"],"applications":[]}"#)
    continuation = nil
  }
}
