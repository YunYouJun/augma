import AppKit
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class ProjectWorkspaceTests: XCTestCase {
  func testWebsiteValidationDeduplicationAndLocalDevelopment() throws {
    XCTAssertEqual(try ProjectWebsite.parse("  HTTPS://Example.COM/docs?q=1#intro\n\nhttp://localhost:3000/\nhttps://example.com/docs?q=1#intro"),
                   ["https://example.com/docs?q=1#intro", "http://localhost:3000/"])
    for value in ["file:///etc/passwd", "javascript:alert(1)", "vscode://file/tmp", "example.com", "https://user:secret@example.com", "https://exa mple.com", "https://", "http://localhost:99999", "https://example.com/\u{0}"] {
      XCTAssertThrowsError(try ProjectWebsite.parse(value), value)
    }
    XCTAssertThrowsError(try ProjectWebsite.parse((0..<11).map { "https://example.com/\($0)" }.joined(separator: "\n")))
    XCTAssertEqual(try ProjectWebsite.parse("\n "), [])
  }

  func testBookmarkFolderAndApplicationBindingsPersist() throws {
    let f = ProjectFixture(); defer { f.close() }
    let id = f.add("Workspace A")
    f.draft(id, name: "My Workspace", websites: "https://example.com/docs\nhttp://localhost:3000")
    XCTAssertTrue(f.store.saveDraft(id))
    let restored = ProjectWorkspaceStore(client: f.client, persistence: f.persistence)
    defer { restored.shutdown() }
    XCTAssertEqual(restored.regions, f.store.regions)
    XCTAssertEqual(restored.regions[0].editor?.id, "com.microsoft.VSCode")
    XCTAssertEqual(restored.regions[0].browser?.id, "com.google.Chrome")
    XCTAssertEqual(restored.regions[0].websites.count, 2)
    XCTAssertFalse(restored.regions[0].folder.bookmark.isEmpty)
  }

  func testSharedDraftsSurviveMainImmersiveAndWindowClosure() {
    let f = ProjectFixture(); defer { f.close() }
    let id = f.add()
    let first = NativeDemoModel(projects: f.store), second = NativeDemoModel(projects: f.store)
    defer { first.closeScene(); second.closeScene() }
    first.space.selectedProjectID = id
    first.space.setView(yaw: 0.4, pitch: 0.1, scale: 1.2)
    f.draft(id, name: "Editing", websites: "https://example.com")
    first.setImmersive(true); first.setImmersive(false)
    XCTAssertTrue(first.space.projects === second.space.projects)
    XCTAssertEqual(first.space.selectedProjectID, id)
    XCTAssertEqual(first.space.viewYaw, 0.4, accuracy: 0.001)
    XCTAssertEqual(second.space.projects.drafts[id]?.name, "Editing")
    first.closeScene()
    XCTAssertTrue(second.space.projects.saveDraft(id))
    XCTAssertEqual(second.space.projects.regions[0].name, "Editing")
  }

  func testInvalidEditsKeepLastSavedConfigurationAndPreventOpen() {
    let f = ProjectFixture(); defer { f.close() }
    let id = f.add(), saved = f.store.regions
    f.draft(id, websites: "javascript:alert(1)")
    f.store.open(id)
    XCTAssertEqual(f.store.regions, saved)
    XCTAssertTrue(f.client.opened.isEmpty)
    XCTAssertTrue(f.store.hasUnsavedDrafts)
    XCTAssertFalse(f.store.flush())
    f.store.discardDraft(id)
    XCTAssertFalse(f.store.hasUnsavedDrafts)
    XCTAssertTrue(f.store.flush())
  }

  func testBoundedRegionsAndPositionSwapping() {
    let f = ProjectFixture(); defer { f.close() }
    let ids = (0..<6).map { f.add("Project \($0)") }
    XCTAssertNil(f.store.add(folderURL: URL(fileURLWithPath: "/tmp/extra")))
    f.store.move(ids[0], to: 5)
    XCTAssertEqual(f.store.regions.first { $0.id == ids[0] }?.slot, 5)
    XCTAssertEqual(f.store.regions.first { $0.id == ids[5] }?.slot, 0)
    XCTAssertEqual(Set(f.store.regions.map(\.slot)).count, 6)
  }

  func testRemovalUndoKeepsBindingsWhenOriginalPositionIsOccupied() {
    let f = ProjectFixture(); defer { f.close() }
    let id = f.add()
    f.draft(id, websites: "https://example.com"); _ = f.store.saveDraft(id)
    f.store.remove(id); _ = f.add("Second")
    f.store.undoRemoval()
    XCTAssertEqual(f.store.regions.first { $0.id == id }?.websites, ["https://example.com"])
    XCTAssertEqual(f.store.regions.first { $0.id == id }?.slot, 1)
    XCTAssertFalse(f.store.canUndoRemoval)
  }

  func testOpenUsesSavedSnapshotAndCoalescesRepeatedClicks() async {
    let f = ProjectFixture(); defer { f.close() }
    let id = f.add(); f.draft(id, websites: "https://example.com/a\nhttps://example.com/b")
    f.client.pauseNext = true
    f.store.open(id); await waitFor { f.client.pending != nil }
    f.store.open(id)
    XCTAssertEqual(f.client.opened, ["editor"])
    f.draft(id, name: "Ignored while opening", websites: "https://different.example")
    f.client.finishPending()
    await waitFor { f.store.openingID == nil }
    XCTAssertEqual(f.client.opened, ["editor", "https://example.com/a", "https://example.com/b"])
    XCTAssertEqual(f.store.reports[id]?.items.map(\.state), [.opened, .opened, .opened])
    XCTAssertEqual(f.completed, 1)
  }

  func testPartialFailureRetryDoesNotReopenSuccessfulItems() async {
    let f = ProjectFixture(); defer { f.close() }
    let id = f.add(); f.draft(id, websites: "https://example.com/a\nhttps://example.com/b")
    f.client.failures = ["https://example.com/a"]
    f.store.open(id); await waitFor { f.store.openingID == nil }
    XCTAssertTrue(f.store.reports[id]?.hasFailures == true)
    XCTAssertEqual(f.completed, 0)
    f.client.failures = []
    f.store.open(id, failedOnly: true); await waitFor { f.store.openingID == nil }
    XCTAssertEqual(f.client.opened, ["editor", "https://example.com/a", "https://example.com/b", "https://example.com/a"])
    XCTAssertEqual(f.completed, 1)
  }

  func testRebindingMissingFolderKeepsSuccessfulWebsiteResults() async {
    let f = ProjectFixture(); defer { f.close() }
    let id = f.add(); f.draft(id, websites: "https://example.com")
    f.client.failures = ["editor"]
    f.store.open(id); await waitFor { f.store.openingID == nil }
    f.store.rebindFolder(id, url: URL(fileURLWithPath: "/tmp/moved-project"))
    f.client.failures = []
    f.store.open(id, failedOnly: true); await waitFor { f.store.openingID == nil }
    XCTAssertEqual(f.client.opened, ["editor", "https://example.com", "editor"])
    XCTAssertEqual(f.client.lastFolder?.displayPath, "/tmp/moved-project")
  }

  func testCancelledRequestRejectsLateCompletionAndSkipsRemainingWebsites() async {
    let f = ProjectFixture(); defer { f.close() }
    let id = f.add(); f.draft(id, websites: "https://example.com")
    f.client.pauseNext = true
    f.store.open(id); await waitFor { f.client.pending != nil }
    f.store.cancelOpening(); f.client.finishPending()
    await Task.yield()
    XCTAssertEqual(f.store.reports[id]?.items.map(\.state), [.cancelled, .cancelled])
    XCTAssertEqual(f.client.opened, ["editor"])
    XCTAssertEqual(f.completed, 0)
  }

  func testRemoveDuringOpenDoesNotRestoreDeletedRegion() async {
    let f = ProjectFixture(); defer { f.close() }
    let id = f.add(); f.client.pauseNext = true
    f.store.open(id); await waitFor { f.client.pending != nil }
    f.store.remove(id); f.client.finishPending()
    await Task.yield()
    XCTAssertTrue(f.store.regions.isEmpty)
    XCTAssertNil(f.store.reports[id])
    XCTAssertEqual(f.completed, 0)
  }

  func testSaveFailureRetainsEditsAndRetriesLatestConfiguration() {
    let f = ProjectFixture(); defer { f.close() }
    let id = f.add(); f.persistence.failSave = true
    f.draft(id, name: "Saved later", websites: "https://example.com")
    XCTAssertTrue(f.store.saveDraft(id))
    XCTAssertNotNil(f.store.saveError)
    XCTAssertFalse(f.store.flush())
    f.persistence.failSave = false
    XCTAssertTrue(f.store.flush())
    XCTAssertEqual(f.persistence.document.regions[0].name, "Saved later")
    XCTAssertNil(f.store.saveError)
  }

  func testFailedPersistenceBlocksBatchOpeningUntilRetry() async {
    let f = ProjectFixture(); defer { f.close() }
    let id = f.add(); f.persistence.failSave = true
    f.draft(id, websites: "https://example.com")
    f.store.open(id)
    XCTAssertNil(f.store.openingID)
    XCTAssertTrue(f.client.opened.isEmpty)
    XCTAssertNotNil(f.store.saveError)
    f.persistence.failSave = false
    f.store.open(id); await waitFor { f.store.openingID == nil }
    XCTAssertEqual(f.client.opened, ["editor", "https://example.com"])
  }

  func testResumeCancelledBatchKeepsAlreadyOpenedItems() async {
    let f = ProjectFixture(); defer { f.close() }
    let id = f.add(); f.draft(id, websites: "https://example.com")
    // Finish one run, then make only the website retryable by changing its outcome.
    f.client.failures = ["https://example.com"]
    f.store.open(id); await waitFor { f.store.openingID == nil }
    f.client.failures = []; f.client.pauseNext = true
    f.store.open(id, failedOnly: true); await waitFor { f.client.pending != nil }
    f.store.cancelOpening(); f.client.finishPending(); await Task.yield()
    f.store.open(id, failedOnly: true); await waitFor { f.store.openingID == nil }
    XCTAssertEqual(f.client.opened.filter { $0 == "editor" }.count, 1)
    XCTAssertEqual(f.store.reports[id]?.items.map(\.state), [.opened, .opened])
  }

  func testConfigurationRejectsDuplicatesUnknownVersionAndInvalidBindings() throws {
    let f = ProjectFixture(); defer { f.close() }; _ = f.add()
    let region = try XCTUnwrap(f.store.regions.first)
    XCTAssertThrowsError(try ProjectWorkspaceDocument(version: 2, regions: [region]).validated())
    XCTAssertThrowsError(try ProjectWorkspaceDocument(regions: [region, region]).validated())
    var invalid = region; invalid.editor?.id = "com.apple.Terminal"
    XCTAssertThrowsError(try ProjectWorkspaceDocument(regions: [invalid]).validated())
    invalid = region; invalid.folder.bookmark = Data()
    XCTAssertThrowsError(try ProjectWorkspaceDocument(regions: [invalid]).validated())
    invalid = region; invalid.name = "\n"
    XCTAssertThrowsError(try ProjectWorkspaceDocument(regions: [invalid]).validated())
  }

  func testRealConfigurationRoundTripAndCorruptBackup() throws {
    let folder = FileManager.default.temporaryDirectory.appending(path: "augma-project-test-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = ProjectWorkspaceFile(url: folder.appending(path: "regions.json"))
    let f = ProjectFixture(); defer { f.close() }; _ = f.add()
    let document = ProjectWorkspaceDocument(regions: f.store.regions)
    try file.save(document); XCTAssertEqual(try file.load(), document)
    let corrupt = Data("broken".utf8); try corrupt.write(to: file.url)
    let store = ProjectWorkspaceStore(client: f.client, persistence: file); defer { store.shutdown() }
    XCTAssertFalse(store.writable); store.retrySave()
    XCTAssertEqual(try Data(contentsOf: file.url), corrupt)
    store.rebuildUnreadableConfiguration()
    XCTAssertTrue(store.writable)
    let backups = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("project-regions-preserved-") }
    XCTAssertEqual(backups.count, 1)
    XCTAssertEqual(try Data(contentsOf: XCTUnwrap(backups.first)), corrupt)
  }

  func testRealFolderBookmarkRejectsMissingFolderWithoutUsingDisplayPath() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: "augma-bookmark-test-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let folder = root.appending(path: "Project with 空格 #1")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let client = SystemProjectWorkspaceClient()
    var bookmark = try client.captureFolder(folder)
    let access = try client.resolveFolder(bookmark)
    XCTAssertEqual(access.url.standardizedFileURL.path, folder.standardizedFileURL.path)
    access.release()
    bookmark.bookmark = Data("invalid bookmark".utf8)
    // A valid display path cannot bypass a failed bookmark.
    XCTAssertThrowsError(try client.resolveFolder(bookmark))
    let valid = try client.captureFolder(folder)
    try FileManager.default.removeItem(at: folder)
    XCTAssertThrowsError(try client.resolveFolder(valid))
    XCTAssertThrowsError(try client.captureFolder(root.appending(path: "missing")))
  }

  private func waitFor(_ predicate: () -> Bool) async {
    for _ in 0..<100 where !predicate() { await Task.yield() }
    XCTAssertTrue(predicate())
  }
}

@MainActor
private final class ProjectFixture {
  let client = FakeProjectClient()
  let persistence = FakeProjectPersistence()
  let store: ProjectWorkspaceStore
  var completed = 0
  init() {
    store = ProjectWorkspaceStore(client: client, persistence: persistence)
    store.onOpenCompleted = { [weak self] _ in self?.completed += 1 }
  }
  func add(_ name: String = "Project") -> UUID { store.add(folderURL: URL(fileURLWithPath: "/tmp/" + name))! }
  func draft(_ id: UUID, name: String? = nil, websites: String) {
    let region = store.regions.first { $0.id == id }!
    var draft = store.draft(for: region)
    if let name { draft.name = name }
    draft.websites = websites
    store.setDraft(id, draft)
  }
  func close() { store.shutdown(); client.finishPending() }
}

@MainActor
private final class FakeProjectPersistence: ProjectWorkspacePersisting {
  var document = ProjectWorkspaceDocument()
  var failSave = false
  func load() throws -> ProjectWorkspaceDocument { document }
  func save(_ document: ProjectWorkspaceDocument) throws {
    if failSave { throw CocoaError(.fileWriteNoPermission) }
    self.document = document
  }
  func preserveUnreadableFile() throws {}
}

@MainActor
private final class FakeProjectClient: ProjectWorkspaceClient {
  var opened: [String] = []
  var failures: Set<String> = []
  var pauseNext = false
  var pending: CheckedContinuation<Void, Never>?
  var lastFolder: ProjectFolder?
  func captureFolder(_ url: URL) throws -> ProjectFolder { ProjectFolder(bookmark: Data(url.path.utf8), displayPath: url.path, securityScoped: false) }
  func defaultApplication(_ id: String) -> ProjectApplication? {
    ProjectApplication(InstalledApplication(id: id, name: "App", path: "/Applications/\(id).app"))
  }
  func inspectApplication(_ url: URL, expectedID: String) throws -> ProjectApplication { defaultApplication(expectedID)! }
  func openEditor(folder: ProjectFolder, application: ProjectApplication?) async throws {
    lastFolder = folder; try await perform("editor")
  }
  func openWebsite(_ url: URL, application: ProjectApplication?) async throws { try await perform(url.absoluteString) }
  func revealFolder(_ folder: ProjectFolder) throws {}
  func finishPending() { let old = pending; pending = nil; old?.resume() }
  private func perform(_ id: String) async throws {
    opened.append(id)
    if pauseNext { pauseNext = false; await withCheckedContinuation { pending = $0 } }
    if failures.contains(id) { throw ProjectWorkspaceError.applicationUnavailable }
  }
}
