import AppKit
import SwiftUI
import XCTest

@testable import AugmaDesktopDemo

final class CodexStorageTests: XCTestCase {
  func testNativeScanInspectsOnlyFixedCachesAndLogsAndNeverOffersProtectedFiles() async throws {
    let fixture = try CodexStorageFixture()
    defer { fixture.remove() }
    try fixture.file("Library/Caches/Codex/Default/Cache/old-entry", bytes: 10)
    try fixture.file("Library/Caches/Codex/Default/Cache/recent-entry", bytes: 20, old: false)
    try fixture.file(".codex/log/codex-tui.log.1", bytes: 30)
    try fixture.file(".codex/log/unknown.txt", bytes: 40)
    for path in [
      ".codex/sessions/chat.jsonl", ".codex/archived_sessions/chat.jsonl",
      ".codex/thread_history_1.sqlite",
      ".codex/artifacts/result.png", ".codex/visualizations/result.html",
      ".codex/worktrees/project/source.swift",
      "Library/Application Support/Codex/Default/IndexedDB/data",
      "Library/Application Support/Codex/Default/Cookies",
      "Library/Caches/Codex/Default/Cache/state_99.sqlite-wal",
      "Library/Caches/Codex/Default/Cache/sessions/chat.jsonl",
    ] {
      try fixture.file(path, bytes: 1000)
    }
    let scan = try await fixture.client().scan()
    XCTAssertFalse(scan.incomplete)
    XCTAssertEqual(scan.measuredBytes, 100)
    XCTAssertEqual(Set(scan.candidates.map(\.relativePath)), ["old-entry", "codex-tui.log.1"])
    XCTAssertEqual(scan.scopes.reduce(0) { $0 + $1.skippedProtected }, 2)
    for scope in scan.scopes { XCTAssertFalse(scope.displayPath.contains("IndexedDB")) }
    XCTAssertTrue(fixture.exists(".codex/thread_history_1.sqlite"))
    XCTAssertEqual(try Data(contentsOf: fixture.url(".codex/artifacts/result.png")).count, 1000)
  }

  func testLinksAndHardLinkedFilesCannotBecomePreviewItemsAndAreNotDoubleCounted() async throws {
    let fixture = try CodexStorageFixture()
    defer { fixture.remove() }
    try fixture.file("Library/Caches/Codex/Default/Cache/original", bytes: 13)
    try FileManager.default.linkItem(
      at: fixture.url("Library/Caches/Codex/Default/Cache/original"),
      to: fixture.url("Library/Caches/Codex/Default/Cache/copy"))
    try fixture.file("private/secret", bytes: 999)
    try FileManager.default.createSymbolicLink(
      at: fixture.url("Library/Caches/Codex/Default/Cache/link"),
      withDestinationURL: fixture.url("private"))
    let client = fixture.client()
    let scan = try await client.scan()
    XCTAssertEqual(scan.measuredBytes, 13)
    XCTAssertTrue(scan.candidates.isEmpty)
    let scope = try XCTUnwrap(scan.scopes.first { $0.id == "cache-0" })
    XCTAssertEqual(scope.skippedLinks, 1)
    XCTAssertEqual(scope.duplicateFiles, 1)
    XCTAssertFalse(scope.canAnalyzeWithMole)
    do {
      _ = try await client.moleScope(scanID: scan.id, scopeID: scope.id)
      XCTFail("Unsafe scope must be refused")
    } catch {}
  }

  func testMissingUnusableAndIncompleteRootsRemainDistinctAndNeverOfferPartialCandidates()
    async throws
  {
    let fixture = try CodexStorageFixture()
    defer { fixture.remove() }
    let missing = try await fixture.client().scan()
    XCTAssertTrue(missing.scopes.allSatisfy { $0.status == .missing })
    try fixture.file("Library/Caches/Codex/Default/Cache/old-entry", bytes: 50)
    try fixture.file(".codex/log", bytes: 5)  // A file is not a supported log directory.
    for client in [fixture.client(maximumEntries: 0), fixture.client(maximumDuration: 0)] {
      let scan = try await client.scan()
      XCTAssertTrue(scan.incomplete)
      XCTAssertTrue(scan.candidates.isEmpty)
      XCTAssertEqual(scan.scopes.first { $0.id == "cli-log" }?.status, .unavailable)
    }
    try fixture.file("Library/Caches/Codex/Default/Cache/nested/deeper/file", bytes: 5)
    let deep = try await fixture.client(maximumDepth: 1).scan()
    XCTAssertTrue(deep.incomplete)
    XCTAssertFalse(deep.candidates.contains { $0.scopeID == "cache-0" })
  }

  func testPreviewRevalidatesFilesAndRejectsUnknownExpiredAndPreviousScanIDsWithoutDeleting()
    async throws
  {
    let fixture = try CodexStorageFixture()
    defer { fixture.remove() }
    try fixture.file(".codex/log/codex.log", bytes: 50)
    let clock = CodexStorageClock(fixture.now)
    let client = CodexStorageScanner(home: fixture.home, environmentHome: nil, now: { clock.date })
    let scan = try await client.scan()
    let candidate = try XCTUnwrap(scan.candidates.first)
    let preview = try await client.preview(scanID: scan.id, ids: [candidate.id])
    XCTAssertEqual(preview.bytes, 50)
    XCTAssertTrue(fixture.exists(".codex/log/codex.log"))
    do {
      _ = try await client.preview(scanID: scan.id, ids: [UUID()])
      XCTFail("Unknown IDs must fail")
    } catch {}
    clock.advance(301)
    do {
      _ = try await client.preview(scanID: scan.id, ids: [candidate.id])
      XCTFail("Expired scan must fail")
    } catch {}
    clock.advance(-301)
    let fresh = try await client.scan()
    do {
      _ = try await client.preview(scanID: scan.id, ids: [candidate.id])
      XCTFail("Old scan must fail")
    } catch {}
    let freshID = try XCTUnwrap(fresh.candidates.first?.id)
    try fixture.file(".codex/log/codex.log", bytes: 51)
    do {
      _ = try await client.preview(scanID: fresh.id, ids: [freshID])
      XCTFail("Changed file must fail")
    } catch {}
    XCTAssertEqual(try Data(contentsOf: fixture.url(".codex/log/codex.log")).count, 51)
  }

  func testScopeReplacementCannotReachMoleOrPreview() async throws {
    let fixture = try CodexStorageFixture()
    defer { fixture.remove() }
    try fixture.file(".codex/log/codex.log", bytes: 12)
    let client = fixture.client()
    let scan = try await client.scan()
    let candidate = try XCTUnwrap(scan.candidates.first)
    try FileManager.default.moveItem(
      at: fixture.url(".codex/log"), to: fixture.url(".codex/moved-log"))
    try FileManager.default.createSymbolicLink(
      at: fixture.url(".codex/log"), withDestinationURL: fixture.url(".codex/moved-log"))
    do {
      _ = try await client.moleScope(scanID: scan.id, scopeID: "cli-log")
      XCTFail("Changed root must fail")
    } catch {}
    do {
      _ = try await client.preview(scanID: scan.id, ids: [candidate.id])
      XCTFail("Changed root must fail")
    } catch {}
    let after = try await client.scan()
    XCTAssertEqual(after.scopes.first { $0.id == "cli-log" }?.status, .unavailable)
    XCTAssertTrue(after.candidates.isEmpty)
  }

  func testCustomCodexHomeIsExplicitAndInvalidOrProtectedOverridesDoNotFallBack() async throws {
    let fixture = try CodexStorageFixture()
    defer { fixture.remove() }
    try fixture.file("custom/log/diagnostic.log", bytes: 7)
    try fixture.file(".codex/log/other.log", bytes: 100)
    let client = CodexStorageScanner(
      home: fixture.home, environmentHome: fixture.url("custom").path, now: { fixture.now })
    let scan = try await client.scan()
    XCTAssertEqual(scan.measuredBytes, 7)
    for invalid in ["relative", "", "~/.codex", "/", fixture.url(".codex/sessions").path] {
      do {
        _ = try await CodexStorageScanner(home: fixture.home, environmentHome: invalid).scan()
        XCTFail("Invalid overrides must not silently scan the default home")
      } catch {}
    }
  }

  func testNewProtectedContentBlocksOptionalAnalysisBeforeAnExternalToolCanReadIt() async throws {
    let fixture = try CodexStorageFixture()
    defer { fixture.remove() }
    try fixture.file(".codex/log/diagnostic.log", bytes: 7)
    let client = fixture.client()
    let scan = try await client.scan()
    try fixture.file(".codex/log/thread_history_99.sqlite", bytes: 100)
    do {
      _ = try await client.moleScope(scanID: scan.id, scopeID: "cli-log")
      XCTFail("Protected additions must be rechecked")
    } catch {}
    let fresh = try await client.scan()
    XCTAssertFalse(try XCTUnwrap(fresh.scopes.first { $0.id == "cli-log" }).canAnalyzeWithMole)
  }

  func testCandidateLimitIsExplicitAndDoesNotChangeMeasuredUsage() async throws {
    let fixture = try CodexStorageFixture()
    defer { fixture.remove() }
    for index in 1...105 { try fixture.file(".codex/log/diagnostic-\(index).log", bytes: index) }
    let scan = try await fixture.client().scan()
    XCTAssertEqual(scan.scopes.first { $0.id == "cli-log" }?.omittedCandidates, 5)
    XCTAssertEqual(scan.candidates.count, 100)
    XCTAssertEqual(scan.candidates.first?.bytes, 105)
    XCTAssertEqual(scan.candidates.last?.bytes, 6)
    XCTAssertEqual(scan.measuredBytes, 5565)
    XCTAssertFalse(scan.incomplete)
  }

  @MainActor func testStoreKeepsSelectionEmptyAndPreviewCannotExecuteOrInstallAnything()
    async throws
  {
    let fixture = try CodexStorageFixture()
    defer { fixture.remove() }
    try fixture.file(".codex/log/old.log", bytes: 30)
    let mole = CodexMoleFixture()
    let store = CodexStorageStore(client: fixture.client(), mole: mole)
    XCTAssertNil(store.scan)
    store.startScan()
    try await idle(store)
    XCTAssertTrue(store.selection.isEmpty)
    let candidate = try XCTUnwrap(store.scan?.candidates.first)
    store.selection = [candidate.id]
    store.buildPreview()
    try await idle(store)
    XCTAssertEqual(store.preview?.items.map(\.id), [candidate.id])
    XCTAssertTrue(fixture.exists(".codex/log/old.log"))
    let calls = await mole.calls
    XCTAssertTrue(
      calls.isEmpty, "Native scan/preview must not install or invoke optional providers")
    store.selection = []
    XCTAssertNil(store.preview)
  }

  @MainActor func testOptionalMoleIsScopedAndCannotChangeNativeCandidatesOrTheirSelection()
    async throws
  {
    let fixture = try CodexStorageFixture()
    defer { fixture.remove() }
    try fixture.file(".codex/log/old.log", bytes: 30)
    let mole = CodexMoleFixture()
    let store = CodexStorageStore(client: fixture.client(), mole: mole)
    store.startScan()
    try await idle(store)
    let scan = try XCTUnwrap(store.scan)
    store.analyzeWithMole(scopeID: "sessions")
    XCTAssertFalse(store.isBusy)
    store.analyzeWithMole(scopeID: "cli-log")
    try await idle(store)
    let calls = await mole.calls
    XCTAssertEqual(calls, ["inspect", "analyze:" + fixture.url(".codex/log").path])
    XCTAssertTrue(store.moleReport?.incomplete == true)
    XCTAssertEqual(store.scan?.candidates.map(\.id), scan.candidates.map(\.id))
    XCTAssertTrue(store.selection.isEmpty)
  }

  @MainActor func testMissingAndUnsupportedMoleLeaveNativeScanAvailable() async throws {
    let fixture = try CodexStorageFixture()
    defer { fixture.remove() }
    try fixture.file(".codex/log/old.log", bytes: 30)
    for version: String? in [nil, "99.0.0"] {
      let mole = CodexMoleFixture(version: version)
      let store = CodexStorageStore(client: fixture.client(), mole: mole)
      store.startScan()
      try await idle(store)
      store.analyzeWithMole(scopeID: "cli-log")
      try await idle(store)
      XCTAssertNotNil(store.error)
      XCTAssertNotNil(store.scan)
      XCTAssertNil(store.moleReport)
      let calls = await mole.calls
      XCTAssertEqual(calls, ["inspect"])
    }
  }

  @MainActor func testCancelledLateResultsCannotReplaceTheNextScan() async throws {
    let provider = CodexDeferredStorage()
    let store = CodexStorageStore(client: provider)
    store.startScan()
    try await waitUntil { await provider.waiters.count == 1 }
    store.cancelReadOnly()
    store.startScan()
    try await waitUntil { await provider.waiters.count == 2 }
    let stale = CodexStorageScan(id: UUID(), checkedAt: .now, scopes: [], candidates: [])
    let current = CodexStorageScan(id: UUID(), checkedAt: .now, scopes: [], candidates: [])
    await provider.finish(index: 0, scan: stale)
    XCTAssertNil(store.scan)
    await provider.finish(index: 1, scan: current)
    try await idle(store)
    XCTAssertEqual(store.scan?.id, current.id)
  }

  @MainActor func testOperationsCoordinateWithExistingCleanupAndClosingCancelsReads() async throws {
    let provider = CodexDeferredStorage()
    let codex = CodexStorageStore(client: provider)
    let system = SystemCleanupStore(codex: codex)
    codex.startScan()
    try await waitUntil { await provider.waiters.count == 1 }
    XCTAssertTrue(system.isBusy)
    XCTAssertFalse(system.isCleaning)
    system.startScan()
    XCTAssertEqual(system.phase, .idle)
    system.cancel()
    XCTAssertFalse(system.isBusy)
    await provider.finish(
      index: 0, scan: .init(id: UUID(), checkedAt: .now, scopes: [], candidates: []))
  }

  @MainActor func testSectionRendersAtNarrowAndWideWidthsInBothAppearances() async throws {
    let fixture = try CodexStorageFixture()
    defer { fixture.remove() }
    try fixture.file(
      ".codex/log/very-long-diagnostic-log-name-for-layout-validation.log", bytes: 4_000)
    let store = CodexStorageStore(client: fixture.client())
    store.startScan()
    try await idle(store)
    for width in [440, 660] {
      for dark in [false, true] {
        let content = CodexStorageSection(store: store).frame(width: CGFloat(width)).padding(20)
          .background(Color(nsColor: .windowBackgroundColor)).environment(
            \.colorScheme, dark ? .dark : .light)
        let host = NSHostingView(rootView: content)
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        host.frame = NSRect(x: 0, y: 0, width: width + 40, height: 600)
        host.layoutSubtreeIfNeeded()
        host.frame.size = host.fittingSize
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(host.frame.width, CGFloat(width + 40), accuracy: 1)
        XCTAssertLessThan(host.frame.height, 700)
        if let directory = ProcessInfo.processInfo.environment["AUGMA_RENDER_CODEX_DIR"] {
          try FileManager.default.createDirectory(
            atPath: directory, withIntermediateDirectories: true)
          let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
          host.cacheDisplay(in: host.bounds, to: bitmap)
          try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(
              to: URL(filePath: directory).appendingPathComponent(
                "codex-\(width)-\(dark ? "dark" : "light").png"))
        }
      }
    }
  }

  func testNativeReadOnlyScanWhenExplicitlyRequested() async throws {
    guard ProcessInfo.processInfo.environment["AUGMA_TEST_CODEX_STORAGE"] == "1" else {
      throw XCTSkip("Opt-in metadata-only cache/log scan; protected directories are not scanned")
    }
    let scan = try await CodexStorageScanner().scan()
    XCTAssertEqual(scan.scopes.count, 10)
    XCTAssertFalse(
      scan.scopes.contains {
        $0.displayPath.contains("sessions") || $0.displayPath.contains("artifacts")
      })
  }

  @MainActor func testInstalledMoleAnalyzesOnlyTheFixtureScopeWhenExplicitlyRequested() async throws
  {
    guard ProcessInfo.processInfo.environment["AUGMA_TEST_INSTALLED_MOLE"] == "1" else {
      throw XCTSkip("Opt-in real read-only Mole analysis of a temporary log fixture")
    }
    let fixture = try CodexStorageFixture()
    defer { fixture.remove() }
    try fixture.file(".codex/log/diagnostic.log", bytes: 100)
    let store = CodexStorageStore(client: fixture.client())
    store.startScan()
    try await idle(store)
    store.analyzeWithMole(scopeID: "cli-log")
    try await idle(store)
    XCTAssertNil(store.error)
    XCTAssertNotNil(store.moleReport)
    XCTAssertTrue(fixture.exists(".codex/log/diagnostic.log"))
    XCTAssertTrue(store.selection.isEmpty)
  }

  func testExecutionRequiresExactConfirmationAndCannotReplayThePreview() async throws {
    let fixture = try CodexStorageFixture()
    defer { fixture.remove() }
    try fixture.file(".codex/log/old.log", bytes: 30)
    try fixture.file(".codex/sessions/preserved.jsonl", bytes: 91)
    let client = fixture.executionClient()
    let scan = try await client.scan()
    let preview = try await client.preview(scanID: scan.id, ids: Set(scan.candidates.map(\.id)))
    do {
      _ = try await client.execute(previewID: preview.id, confirmedIDs: [UUID()])
      XCTFail("Confirmation must match every item")
    } catch {}
    XCTAssertTrue(fixture.exists(".codex/log/old.log"))
    let receipt = try await client.execute(
      previewID: preview.id, confirmedIDs: Set(preview.items.map(\.id)))
    XCTAssertEqual(receipt.items.map(\.status), [.trashed])
    XCTAssertEqual(receipt.trashedBytes, 30)
    XCTAssertFalse(fixture.exists(".codex/log/old.log"))
    XCTAssertTrue(fixture.exists("test-trash/old.log"))
    XCTAssertTrue(fixture.exists(".codex/sessions/preserved.jsonl"))
    let restored = try await fixture.executionClient().lastReceipt()
    XCTAssertEqual(restored?.id, receipt.id)
    XCTAssertEqual(restored?.items.first?.status, .trashed)
    let receiptAttributes = try FileManager.default.attributesOfItem(
      atPath: fixture.url("Library/Application Support/Augma/Cleanup/codex-last-receipt.json").path)
    XCTAssertEqual((receiptAttributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    do {
      _ = try await client.execute(
        previewID: preview.id, confirmedIDs: Set(preview.items.map(\.id)))
      XCTFail("A confirmed review must be consumed once")
    } catch {}
  }

  func testExecutionSkipsChangedAndSymlinkedFilesAndKeepsIndependentResults() async throws {
    let fixture = try CodexStorageFixture()
    defer { fixture.remove() }
    for (name, size) in [("changed.log", 30), ("linked.log", 20), ("good.log", 10)] {
      try fixture.file(".codex/log/" + name, bytes: size)
    }
    try fixture.file(".codex/sessions/protected.jsonl", bytes: 80)
    let client = fixture.executionClient()
    let scan = try await client.scan()
    let preview = try await client.preview(scanID: scan.id, ids: Set(scan.candidates.map(\.id)))
    try fixture.file(".codex/log/changed.log", bytes: 31)
    try FileManager.default.removeItem(at: fixture.url(".codex/log/linked.log"))
    try FileManager.default.createSymbolicLink(
      at: fixture.url(".codex/log/linked.log"),
      withDestinationURL: fixture.url(".codex/sessions/protected.jsonl"))
    let receipt = try await client.execute(
      previewID: preview.id, confirmedIDs: Set(preview.items.map(\.id)))
    XCTAssertEqual(receipt.items.map(\.status), [.skipped, .skipped, .trashed])
    XCTAssertEqual(receipt.trashedBytes, 10)
    XCTAssertEqual(try Data(contentsOf: fixture.url(".codex/sessions/protected.jsonl")).count, 80)
    XCTAssertEqual(try Data(contentsOf: fixture.url(".codex/log/changed.log")).count, 31)
  }

  func testUnavailableDataProtectionStopsCleanupBeforeMovingAnyFiles() async throws {
    let fixture = try CodexStorageFixture()
    defer { fixture.remove() }
    try fixture.file(".codex/log/old.log", bytes: 30)
    let client = fixture.executionClient(receiptWriter: ProtectedFileWriter { _, _, options in
      XCTAssertEqual(options, [.atomic, .completeFileProtectionUnlessOpen])
      throw POSIXError(.EPERM)
    })
    let scan = try await client.scan()
    let ids = Set(scan.candidates.map(\.id))
    let preview = try await client.preview(scanID: scan.id, ids: ids)
    do {
      _ = try await client.execute(previewID: preview.id, confirmedIDs: ids)
      XCTFail("Unavailable protected storage must prevent cleanup")
    } catch { XCTAssertEqual((error as? POSIXError)?.code, .EPERM) }
    XCTAssertTrue(fixture.exists(".codex/log/old.log"))
    XCTAssertFalse(fixture.exists("test-trash/old.log"))
    let receipt = try await client.lastReceipt()
    XCTAssertNil(receipt)
  }

  func testExecutionRefusesExpiredOrReplacedRootReviews() async throws {
    let fixture = try CodexStorageFixture()
    defer { fixture.remove() }
    try fixture.file(".codex/log/old.log", bytes: 30)
    let clock = CodexStorageClock(fixture.now)
    let client = CodexStorageScanner(
      home: fixture.home, environmentHome: nil, now: { clock.date },
      ensureStopped: {}, receiptWriter: .temporaryFixture)
    let scan = try await client.scan()
    let ids = Set(scan.candidates.map(\.id))
    let preview = try await client.preview(scanID: scan.id, ids: ids)
    clock.advance(301)
    do {
      _ = try await client.execute(previewID: preview.id, confirmedIDs: ids)
      XCTFail("Expired review must fail")
    } catch {}
    clock.advance(-301)
    try FileManager.default.moveItem(
      at: fixture.url(".codex/log"), to: fixture.url(".codex/old-log"))
    try FileManager.default.createSymbolicLink(
      at: fixture.url(".codex/log"), withDestinationURL: fixture.url(".codex/old-log"))
    let result = try await client.execute(previewID: preview.id, confirmedIDs: ids)
    XCTAssertEqual(result.items.first?.status, .skipped)
    XCTAssertTrue(fixture.exists(".codex/old-log/old.log"))
  }

  func testRunningCodexStopsTheEntireBatchAndProducesRecoverableReceipt() async throws {
    let fixture = try CodexStorageFixture()
    defer { fixture.remove() }
    try fixture.file(".codex/log/a.log", bytes: 30)
    try fixture.file(".codex/log/b.log", bytes: 20)
    let client = fixture.executionClient(ensureStopped: { throw CodexStorageError.running })
    let scan = try await client.scan()
    let ids = Set(scan.candidates.map(\.id))
    let preview = try await client.preview(scanID: scan.id, ids: ids)
    let result = try await client.execute(previewID: preview.id, confirmedIDs: ids)
    XCTAssertTrue(
      result.items.allSatisfy {
        $0.status == .skipped && $0.detail == CodexStorageError.running.localizedDescription
      })
    XCTAssertEqual(result.trashedBytes, 0)
    XCTAssertTrue(fixture.exists(".codex/log/a.log"))
    XCTAssertTrue(fixture.exists(".codex/log/b.log"))
    let restored = try await fixture.executionClient().lastReceipt()
    XCTAssertEqual(restored?.items.count, 2)
  }

  func testJournalFailureBeforeExecutionDoesNotMoveFilesAndInterruptedReceiptsNeverRetry()
    async throws
  {
    let fixture = try CodexStorageFixture()
    defer { fixture.remove() }
    try fixture.file(".codex/log/old.log", bytes: 30)
    try fixture.file("blocked", bytes: 1)
    let client = CodexStorageScanner(
      home: fixture.home, environmentHome: nil, now: { fixture.now },
      ensureStopped: {}, receiptURL: fixture.url("blocked/receipt.json"), receiptWriter: .temporaryFixture)
    let scan = try await client.scan()
    let ids = Set(scan.candidates.map(\.id))
    let preview = try await client.preview(scanID: scan.id, ids: ids)
    do {
      _ = try await client.execute(previewID: preview.id, confirmedIDs: ids)
      XCTFail("No mutation without a durable intent")
    } catch {}
    XCTAssertTrue(fixture.exists(".codex/log/old.log"))
    let journal = CodexStorageJournal(url: fixture.url("journal/receipt.json"), writer: .temporaryFixture)
    var item = CodexStorageReceipt.Item(
      candidate: try XCTUnwrap(preview.items.first), displayPath: "fixture/old.log")
    item.status = .uncertain
    try journal.save(.init(id: UUID(), startedAt: fixture.now, items: [item]))
    let restored = try journal.load()
    XCTAssertEqual(restored?.items.first?.status, .uncertain)
    XCTAssertNotNil(restored?.warning)
    XCTAssertTrue(fixture.exists(".codex/log/old.log"))
  }

  func testTrashFailureAndPostMutationJournalFailureStopWithHonestResults() async throws {
    let fixture = try CodexStorageFixture()
    defer { fixture.remove() }
    try fixture.file(".codex/log/failed.log", bytes: 40)
    try fixture.file(".codex/log/good.log", bytes: 30)
    let client = fixture.executionClient(trash: { url in
      if url.lastPathComponent == "failed.log" { throw CocoaError(.fileWriteNoPermission) }
      try FileManager.default.moveItem(at: url, to: fixture.url("moved.log"))
    })
    let scan = try await client.scan()
    let ids = Set(scan.candidates.map(\.id))
    let preview = try await client.preview(scanID: scan.id, ids: ids)
    let receipt = try await client.execute(previewID: preview.id, confirmedIDs: ids)
    XCTAssertEqual(receipt.items.map(\.status), [.failed, .trashed])
    try fixture.file(".codex/log/remaining.log", bytes: 10)
    let second = fixture.executionClient(trash: { url in
      try FileManager.default.moveItem(at: url, to: fixture.url("second-moved.log"))
      let journal = fixture.url("Library/Application Support/Augma/Cleanup/codex-last-receipt.json")
      try FileManager.default.removeItem(at: journal)
      try FileManager.default.createDirectory(at: journal, withIntermediateDirectories: true)
    })
    let secondScan = try await second.scan()
    let secondIDs = Set(secondScan.candidates.map(\.id))
    let secondPreview = try await second.preview(scanID: secondScan.id, ids: secondIDs)
    let secondReceipt = try await second.execute(
      previewID: secondPreview.id, confirmedIDs: secondIDs)
    XCTAssertEqual(secondReceipt.items.first?.status, .trashed)
    XCTAssertNotNil(secondReceipt.warning)
    XCTAssertEqual(secondReceipt.items.last?.status, .skipped)
    XCTAssertTrue(fixture.exists(".codex/log/remaining.log"))
  }

  func testTrashErrorAfterMoveRemainsUncertainEvenIfAnotherFileAppearsAtTheOriginalPath()
    async throws
  {
    let fixture = try CodexStorageFixture()
    defer { fixture.remove() }
    try fixture.file(".codex/log/old.log", bytes: 30)
    let client = fixture.executionClient(trash: { url in
      try FileManager.default.moveItem(at: url, to: fixture.url("moved.log"))
      try fixture.file(".codex/log/old.log", bytes: 10)
      throw CocoaError(.fileWriteUnknown)
    })
    let scan = try await client.scan()
    let ids = Set(scan.candidates.map(\.id))
    let preview = try await client.preview(scanID: scan.id, ids: ids)
    let receipt = try await client.execute(previewID: preview.id, confirmedIDs: ids)
    XCTAssertEqual(receipt.items.first?.status, .uncertain)
    XCTAssertEqual(receipt.trashedBytes, 0)
    XCTAssertTrue(fixture.exists("moved.log"))
    XCTAssertEqual(try Data(contentsOf: fixture.url(".codex/log/old.log")).count, 10)
  }

  @MainActor func testStoreProtectsMutationFromClosingAndRestoresReceipt() async throws {
    let fixture = try CodexStorageFixture()
    defer { fixture.remove() }
    try fixture.file(".codex/log/old.log", bytes: 30)
    let gate = CodexExecutionGate()
    let client = fixture.executionClient(ensureStopped: { await gate.wait() })
    let codex = CodexStorageStore(client: client)
    let system = SystemCleanupStore(codex: codex)
    codex.startScan()
    try await idle(codex)
    codex.selection = Set(try XCTUnwrap(codex.scan).candidates.map(\.id))
    codex.buildPreview()
    try await idle(codex)
    codex.execute(try XCTUnwrap(codex.preview))
    try await waitUntil { await gate.waiting }
    XCTAssertTrue(system.isCleaning)
    system.cancel()
    XCTAssertEqual(codex.phase, .cleaning)
    codex.startScan()
    XCTAssertEqual(codex.phase, .cleaning)
    await gate.finish()
    try await idle(codex)
    XCTAssertFalse(system.isCleaning)
    XCTAssertNil(codex.scan)
    XCTAssertEqual(codex.receipt?.items.first?.status, .trashed)
    let reopened = CodexStorageStore(client: fixture.executionClient())
    await reopened.restoreReceipt()
    XCTAssertEqual(reopened.receipt?.id, codex.receipt?.id)
  }

  @MainActor private func idle(_ store: CodexStorageStore) async throws {
    try await waitUntil { !store.isBusy }
  }
  @MainActor private func waitUntil(_ predicate: () async -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(4))
    while !(await predicate()), .now < deadline { try await Task.sleep(for: .milliseconds(2)) }
    let complete = await predicate()
    XCTAssertTrue(complete)
  }
}

private struct CodexStorageFixture: Sendable {
  let home: URL
  let now = Date().addingTimeInterval(30 * 86_400)
  init() throws {
    home = FileManager.default.temporaryDirectory.appendingPathComponent(
      "augma-codex-" + UUID().uuidString
    )
    .standardizedFileURL.resolvingSymlinksInPath()
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
  }
  func url(_ path: String) -> URL { home.appendingPathComponent(path) }
  func exists(_ path: String) -> Bool { FileManager.default.fileExists(atPath: url(path).path) }
  func file(_ path: String, bytes: Int, old: Bool = true) throws {
    let file = url(path)
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(repeating: 65, count: bytes).write(to: file)
    let modified = now.addingTimeInterval(old ? -14 * 86_400 : 0)
    try FileManager.default.setAttributes(
      [.modificationDate: modified, .creationDate: modified], ofItemAtPath: file.path)
  }
  func client(
    maximumEntries: Int = 5_000, maximumDuration: TimeInterval = 0.8, maximumDepth: Int = 24
  ) -> CodexStorageScanner {
    CodexStorageScanner(
      home: home, environmentHome: nil, maximumEntries: maximumEntries,
      maximumDuration: maximumDuration, maximumDepth: maximumDepth, now: { self.now })
  }
  func executionClient(
    ensureStopped: @escaping @Sendable () async throws -> Void = {},
    trash: (@Sendable (URL) throws -> Void)? = nil,
    receiptWriter: ProtectedFileWriter = .temporaryFixture
  ) -> CodexStorageScanner {
    CodexStorageScanner(
      home: home, environmentHome: nil, now: { self.now },
      trash: trash ?? { url in
        let destination = self.url("test-trash")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try FileManager.default.moveItem(
          at: url, to: destination.appendingPathComponent(url.lastPathComponent))
      }, ensureStopped: ensureStopped, receiptWriter: receiptWriter)
  }
  func remove() { try? FileManager.default.removeItem(at: home) }
}

private final class CodexStorageClock: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Date
  init(_ date: Date) { value = date }
  var date: Date { lock.withLock { value } }
  func advance(_ seconds: TimeInterval) { lock.withLock { value += seconds } }
}

private actor CodexMoleFixture: MoleToolProviding {
  let version: String?
  var calls: [String] = []
  init(version: String? = MoleToolClient.supportedVersion) { self.version = version }
  func inspect() -> MoleInstallation {
    calls.append("inspect")
    return .init(version: version, homebrewAvailable: false)
  }
  func install() throws -> MoleInstallation {
    calls.append("install")
    throw MoleToolError.homebrewMissing
  }
  func analyze(scope: URL) -> MoleDiskReport {
    calls.append("analyze:" + scope.path)
    return .init(
      entries: [
        .init(path: scope.appendingPathComponent("old.log").path, size: 30, scan_status: "partial")
      ],
      incomplete: true, measuredBytes: 30)
  }
}

private actor CodexDeferredStorage: CodexStorageProviding {
  func execute(previewID: UUID, confirmedIDs: Set<UUID>) throws -> CodexStorageReceipt {
    throw CodexStorageError.changed
  }
  func lastReceipt() -> CodexStorageReceipt? { nil }
  var waiters: [CheckedContinuation<CodexStorageScan, Never>] = []
  func scan() async -> CodexStorageScan {
    await withCheckedContinuation { waiters.append($0) }
  }
  func finish(index: Int, scan: CodexStorageScan) { waiters[index].resume(returning: scan) }
  func preview(scanID: UUID, ids: Set<UUID>) throws -> CodexStoragePreview {
    throw CodexStorageError.changed
  }
  func moleScope(scanID: UUID, scopeID: String) throws -> URL { throw CodexStorageError.changed }
}

private actor CodexExecutionGate {
  var waiting = false
  private var continuation: CheckedContinuation<Void, Never>?
  func wait() async {
    await withCheckedContinuation {
      continuation = $0
      waiting = true
    }
  }
  func finish() {
    continuation?.resume()
    continuation = nil
  }
}
