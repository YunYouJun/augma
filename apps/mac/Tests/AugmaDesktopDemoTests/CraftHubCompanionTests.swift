import XCTest

@testable import AugmaDesktopDemo

final class CraftHubCompanionTests: XCTestCase {
  private func summary(_ title: String = "Review proposal") -> String {
    """
    {"version":1,"checkedAt":"2026-11-04T01:00:00.000Z","total":1,"sourceCount":2,"loadedSourceCount":1,"completeSourceCount":0,
    "items":[{"id":"one","title":"\(title)","sourceTitle":"Tasks"}]}
    """
  }

  @MainActor func testSummarySurvivesHostExitAndCompanionRestartWithoutConnectingToRuntime() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: "augma-companion-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let suite = "augma.companion.tests.\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer {
      try? FileManager.default.removeItem(at: root)
      defaults.removePersistentDomain(forName: suite)
    }
    let file = root.appending(path: "today.json")
    try Data(summary().utf8).write(to: file)
    let original = CraftHubCompanionStore(defaults: defaults)
    original.selectSummary(file)
    XCTAssertEqual(original.summary?.items.first?.title, "Review proposal")
    XCTAssertEqual(original.summary?.loadedSourceCount, 1)
    let restarted = CraftHubCompanionStore(defaults: defaults)
    XCTAssertEqual(restarted.summary, original.summary)
    try Data("{bad".utf8).write(to: file)
    restarted.refresh()
    XCTAssertEqual(restarted.summary, original.summary)
    XCTAssertNotNil(restarted.error)
    restarted.disconnect()
    XCTAssertNil(CraftHubCompanionStore(defaults: defaults).summary)
    XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
  }

  func testRejectsUnknownVersionsOversizedAndInvalidCoverage() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: "augma-companion-validation-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appending(path: "today.json")
    for text in [
      summary().replacingOccurrences(of: "\"version\":1", with: "\"version\":2"),
      summary().replacingOccurrences(of: "\"loadedSourceCount\":1", with: "\"loadedSourceCount\":3"),
      String(repeating: "x", count: 65_537),
    ] {
      try Data(text.utf8).write(to: file)
      XCTAssertThrowsError(try CraftHubTodaySummary.read(file))
    }
  }

  @MainActor func testMenuAndCaptureWindowShareTheExistingDurableDraft() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: "augma-companion-draft-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appending(path: "workspace.json")
    let store = WorkspaceStore(url: file, notifications: FocusNotifications(enabled: false), observeLifecycle: false)
    store.updateDraft("菜单栏与浮窗共用的草稿\n中文输入恢复")
    let saved = await store.flush()
    XCTAssertTrue(saved)
    let restarted = WorkspaceStore(
      url: file, notifications: FocusNotifications(enabled: false), observeLifecycle: false)
    XCTAssertEqual(restarted.data.noteDraft, store.data.noteDraft)
    XCTAssertTrue(restarted.data.notes.isEmpty)
  }
}
