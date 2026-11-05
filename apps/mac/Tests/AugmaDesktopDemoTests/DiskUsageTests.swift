import AppKit
import Darwin
import SwiftUI
import XCTest
@testable import AugmaDesktopDemo

final class DiskUsageTests: XCTestCase {
  func testMetadataTotalsIncludeHiddenFilesAndSparseFilesWithoutChangingContents() async throws {
    let fixture = try DiskUsageFixture()
    defer { fixture.remove() }
    try fixture.file("project/node_modules/dependency", bytes: 8_192)
    try fixture.file("project/.git/objects/object", bytes: 4_096)
    try fixture.file("notes.txt", bytes: 500)
    let sparse = fixture.url("disk-image")
    let descriptor = open(sparse.path, O_CREAT | O_WRONLY, 0o600)
    XCTAssertGreaterThanOrEqual(descriptor, 0)
    XCTAssertEqual(ftruncate(descriptor, 100_000_000), 0)
    close(descriptor)
    let before = try FileManager.default.attributesOfItem(atPath: fixture.root.path)[.modificationDate] as? Date
    let scan = try await DiskUsageScanner().scan(fixture.root)
    XCTAssertFalse(scan.root.incomplete)
    XCTAssertEqual(scan.root.logicalBytes, 100_012_788)
    XCTAssertLessThan(scan.root.allocatedBytes, scan.root.logicalBytes)
    XCTAssertEqual(scan.root.fileCount, 4)
    XCTAssertEqual(scan.root.find(fixture.url("project").path)?.logicalBytes, 12_288)
    XCTAssertEqual(try Data(contentsOf: fixture.url("notes.txt")), Data(repeating: 1, count: 500))
    XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: fixture.root.path)[.modificationDate] as? Date, before)
    XCTAssertTrue(scan.issues.isEmpty)
  }

  func testHardLinksDeduplicateAndSymlinksAndSpecialFilesAreExcluded() async throws {
    let fixture = try DiskUsageFixture()
    defer { fixture.remove() }
    try fixture.file("original", bytes: 1_024)
    try FileManager.default.linkItem(at: fixture.url("original"), to: fixture.url("hard-link"))
    try FileManager.default.createSymbolicLink(at: fixture.url("cycle"), withDestinationURL: fixture.root)
    try FileManager.default.createSymbolicLink(at: fixture.url("external"), withDestinationURL: fixture.root.deletingLastPathComponent())
    XCTAssertEqual(mkfifo(fixture.url("pipe").path, 0o600), 0)
    let scan = try await DiskUsageScanner().scan(fixture.root)
    XCTAssertEqual(scan.root.logicalBytes, 1_024)
    XCTAssertEqual(scan.root.fileCount, 1)
    XCTAssertEqual(scan.duplicateFiles, 1)
    XCTAssertEqual(scan.skippedSymlinks, 2)
    XCTAssertEqual(scan.skippedSpecialFiles, 1)
    XCTAssertFalse(scan.root.incomplete)
  }

  func testSymlinkScopeAndFileScopeAreRejected() async throws {
    let fixture = try DiskUsageFixture()
    defer { fixture.remove() }
    try fixture.file("file", bytes: 20)
    try FileManager.default.createSymbolicLink(at: fixture.url("link"), withDestinationURL: fixture.root)
    for url in [fixture.url("link"), fixture.url("file")] {
      do { _ = try await DiskUsageScanner().scan(url); XCTFail("Scope should be rejected") }
      catch is DiskUsageError { }
    }
  }

  func testBudgetsPreservePartialResultsAndExplainUnknownScope() async throws {
    let fixture = try DiskUsageFixture()
    defer { fixture.remove() }
    for index in 0..<10 { try fixture.file("folder/deeper/file\(index)", bytes: 100) }
    let entries = try await DiskUsageScanner(maximumEntries: 5).scan(fixture.root)
    XCTAssertTrue(entries.root.incomplete)
    XCTAssertEqual(entries.entries, 5)
    XCTAssertTrue(entries.issues.contains { $0.reason == .entryLimit })
    let depth = try await DiskUsageScanner(maximumDepth: 1).scan(fixture.root)
    XCTAssertTrue(depth.root.incomplete)
    XCTAssertTrue(depth.issues.contains { $0.reason == .depthLimit })
    let time = try await DiskUsageScanner(maximumDuration: 0).scan(fixture.root)
    XCTAssertTrue(time.root.incomplete)
    XCTAssertTrue(time.issues.contains { $0.reason == .timeLimit })
  }

  func testUnreadableDirectoryIsPartialInsteadOfAnEmptySuccess() async throws {
    let fixture = try DiskUsageFixture()
    defer { fixture.remove() }
    try fixture.file("locked/file", bytes: 100)
    try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: fixture.url("locked").path)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fixture.url("locked").path) }
    let scan = try await DiskUsageScanner().scan(fixture.root)
    XCTAssertTrue(scan.root.incomplete)
    XCTAssertEqual(scan.root.find(fixture.url("locked").path)?.incomplete, true)
    XCTAssertTrue(scan.issues.contains { $0.reason == .unreadable })
  }

  func testReplacingRootDuringTraversalDoesNotFollowTheReplacement() async throws {
    let fixture = try DiskUsageFixture()
    let outside = try DiskUsageFixture()
    let moved = fixture.root.appendingPathExtension("moved")
    defer {
      fixture.remove(); outside.remove()
      try? FileManager.default.removeItem(at: moved)
    }
    for index in 0..<300 { try fixture.file("file\(index)", bytes: 1) }
    try outside.file("private", bytes: 10_000)
    let replacement = DiskUsageRootReplacement(root: fixture.root, moved: moved, target: outside.root)
    let scan = try await DiskUsageScanner().scan(fixture.root) { _ in replacement.replaceOnce() }
    XCTAssertTrue(scan.root.incomplete)
    XCTAssertTrue(scan.issues.contains { $0.reason == .changed })
    XCTAssertEqual(scan.root.logicalBytes, 300)
    XCTAssertFalse(scan.root.children.contains { $0.url.lastPathComponent == "private" })
  }

  func testCancelledScanThrowsAndCanBeStartedAgain() async throws {
    let fixture = try DiskUsageFixture()
    defer { fixture.remove() }
    let scanner = DiskUsageScanner()
    let request = Task {
      await Task.yield()
      return try await scanner.scan(fixture.root)
    }
    request.cancel()
    do { _ = try await request.value; XCTFail("Expected cancellation") }
    catch is CancellationError { }
    let scan = try await scanner.scan(fixture.root)
    XCTAssertFalse(scan.root.incomplete)
  }

  func testTreemapConservesAreaAndHasNoOverlaps() {
    let bounds = CGRect(x: 0, y: 0, width: 640, height: 230)
    let weights = [50.0, 30, 15, 5, 0, -1, .infinity, .nan]
    let tiles = DiskUsageTreemapLayout.tiles(weights: weights, in: bounds)
    XCTAssertEqual(tiles.count, 4)
    for tile in tiles {
      XCTAssertTrue(bounds.contains(tile.frame))
      XCTAssertEqual(tile.frame.width * tile.frame.height / (bounds.width * bounds.height), weights[tile.index] / 100, accuracy: 0.000001)
      for other in tiles where other.index != tile.index {
        let overlap = tile.frame.intersection(other.frame)
        XCTAssertTrue(overlap.isNull || overlap.width * overlap.height < 0.000001)
      }
    }
    XCTAssertTrue(DiskUsageTreemapLayout.tiles(weights: [0], in: bounds).isEmpty)
  }

  func testDirectoryRankingAndSuggestionsDoNotPromiseDeletionOrReclaimedBytes() async throws {
    let fixture = try DiskUsageFixture()
    defer { fixture.remove() }
    try fixture.file("node_modules/package/file", bytes: 4_096)
    try fixture.file("personal/photo", bytes: 8_192)
    try fixture.file("installer.dmg", bytes: 500)
    let scan = try await DiskUsageScanner().scan(fixture.root)
    let ranked = scan.root.largestDirectories(metric: .logical)
    XCTAssertEqual(ranked.first?.url.lastPathComponent, "personal")
    let advice = DiskUsageAdvice.suggestions(for: scan.root, metric: .logical)
    XCTAssertEqual(advice.first?.kind, .review)
    XCTAssertEqual(advice.first { $0.node.url.lastPathComponent == "node_modules" }?.kind, .build)
    XCTAssertEqual(advice.first { $0.node.url.lastPathComponent == "installer.dmg" }?.kind, .installer)
  }

  func testProjectMatchingRequiresComponentBoundaryAndPrefersNestedProject() {
    let projects = [
      CraftHubProject(id: "outer", name: "Outer", path: "/projects/app", trust: "untrusted"),
      CraftHubProject(id: "inner", name: "Inner", path: "/projects/app/packages/web", trust: "trusted"),
    ]
    XCTAssertNil(DiskUsageAdvice.matchingProject(URL(filePath: "/projects/app-copy"), projects: projects))
    XCTAssertNil(DiskUsageAdvice.matchingProject(URL(filePath: "/projects"), projects: projects))
    XCTAssertEqual(DiskUsageAdvice.matchingProject(URL(filePath: "/projects/app/node_modules"), projects: projects)?.id, "outer")
    XCTAssertEqual(DiskUsageAdvice.matchingProject(URL(filePath: "/projects/app/packages/web/dist"), projects: projects)?.id, "inner")
  }

  @MainActor func testStoreRejectsLateProgressAndResultsAfterScopeChangeAndCancel() async throws {
    let provider = DeferredDiskUsageScanner()
    let store = DiskUsageStore(scanner: provider)
    store.start(URL(filePath: "/first"))
    try await waitUntil { await provider.count == 1 }
    store.start(URL(filePath: "/second"))
    try await waitUntil { await provider.count == 2 }
    await provider.finish(0)
    XCTAssertNil(store.snapshot)
    await provider.finish(1)
    try await waitUntil { !store.scanning }
    XCTAssertEqual(store.snapshot?.root.id, "/second")
    store.start(URL(filePath: "/cancelled"))
    try await waitUntil { await provider.count == 3 }
    store.cancel()
    await provider.finish(2)
    await Task.yield()
    XCTAssertNil(store.snapshot)
    XCTAssertEqual(store.progress.entries, 0)
  }

  @MainActor func testDrillDownStaysWithinTheSnapshot() async throws {
    let fixture = try DiskUsageFixture()
    defer { fixture.remove() }
    try fixture.file("project/build/file", bytes: 4_096)
    let store = DiskUsageStore()
    store.start(fixture.root)
    try await waitUntil { !store.scanning }
    let root = try XCTUnwrap(store.snapshot?.root)
    let project = try XCTUnwrap(root.children.first)
    store.focus(project)
    XCTAssertEqual(store.focusedNode?.id, project.id)
    store.focus(.init(url: URL(filePath: "/outside"), isDirectory: true))
    XCTAssertEqual(store.focusedNode?.id, project.id)
    store.goUp()
    XCTAssertEqual(store.focusedNode?.id, root.id)
  }

  @MainActor func testSpaceAnalysisRendersAtNarrowAndWideWidthsInBothAppearances() async throws {
    let fixture = try DiskUsageFixture()
    defer { fixture.remove() }
    for (name, bytes) in [("project/node_modules/large-package/file", 200_000), ("project/build/object", 100_000),
                          ("Downloads/long-installer-name-for-space-analysis.dmg", 64_000), ("Documents/notes.txt", 8_000)] {
      try fixture.file(name, bytes: bytes)
    }
    let store = DiskUsageStore()
    store.start(fixture.root)
    try await waitUntil { !store.scanning }
    for width in [480, 780] {
      for dark in [false, true] {
        let content = DiskUsageView(store: store).frame(width: CGFloat(width), height: 800)
          .background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, dark ? .dark : .light)
        let host = NSHostingView(rootView: content)
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        host.frame = NSRect(x: 0, y: 0, width: width, height: 800)
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(host.fittingSize.width, CGFloat(width), accuracy: 1)
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        if let directory = ProcessInfo.processInfo.environment["AUGMA_RENDER_DISK_USAGE_DIR"] {
          try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
          try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(to: URL(filePath: directory).appendingPathComponent("space-\(width)-\(dark ? "dark" : "light").png"))
        }
      }
    }
  }

  @MainActor private func waitUntil(_ condition: () async -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while !(await condition()), .now < deadline { try await Task.sleep(for: .milliseconds(5)) }
    let done = await condition()
    XCTAssertTrue(done)
  }
}

private struct DiskUsageFixture: Sendable {
  let root: URL
  init() throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent("augma-space-" + UUID().uuidString).resolvingSymlinksInPath()
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }
  func url(_ path: String) -> URL { root.appendingPathComponent(path) }
  func file(_ path: String, bytes: Int) throws {
    try FileManager.default.createDirectory(at: url(path).deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(repeating: 1, count: bytes).write(to: url(path))
  }
  func remove() { try? FileManager.default.removeItem(at: root) }
}

private final class DiskUsageRootReplacement: @unchecked Sendable {
  private let lock = NSLock()
  private var done = false
  let root: URL
  let moved: URL
  let target: URL
  init(root: URL, moved: URL, target: URL) { self.root = root; self.moved = moved; self.target = target }
  func replaceOnce() {
    lock.lock(); defer { lock.unlock() }
    guard !done else { return }
    done = true
    try? FileManager.default.moveItem(at: root, to: moved)
    try? FileManager.default.createSymbolicLink(at: root, withDestinationURL: target)
  }
}

private actor DeferredDiskUsageScanner: DiskUsageScanning {
  struct Request {
    let root: URL
    let progress: @Sendable (DiskUsageProgress) -> Void
    let continuation: CheckedContinuation<DiskUsageSnapshot, Error>
  }
  var requests: [Request] = []
  var count: Int { requests.count }
  func scan(_ root: URL, progress: @escaping @Sendable (DiskUsageProgress) -> Void) async throws -> DiskUsageSnapshot {
    try await withCheckedThrowingContinuation { requests.append(.init(root: root, progress: progress, continuation: $0)) }
  }
  func finish(_ index: Int) {
    let request = requests[index]
    request.progress(.init(entries: 100, logicalBytes: 1_024))
    request.continuation.resume(returning: .init(root: .init(url: request.root, isDirectory: true), checkedAt: .now,
      entries: 0, skippedSymlinks: 0, duplicateFiles: 0, skippedSpecialFiles: 0, issues: [], omittedIssues: 0))
  }
}
