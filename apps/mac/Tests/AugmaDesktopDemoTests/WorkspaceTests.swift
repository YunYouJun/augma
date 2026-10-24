import XCTest
@testable import AugmaDesktopDemo

final class WorkspaceTests: XCTestCase {
  private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "augma-workspace-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  @MainActor private func store(_ directory: URL) -> WorkspaceStore {
    WorkspaceStore(url: directory.appending(path: "workspace.json"), notifications: FocusNotifications(enabled: false), observeLifecycle: false)
  }

  func testVoiceAndTextCommandsHaveBoundariesAndPreserveNoteContent() {
    XCTAssertEqual(WorkspaceCommand.parse("记下：明天暂停计时，买咖啡！"), .note("明天暂停计时，买咖啡！"))
    XCTAssertEqual(WorkspaceCommand.parse("note buy milk\nand coffee"), .note("buy milk\nand coffee"))
    XCTAssertEqual(WorkspaceCommand.parse("notes"), .open(.notes))
    XCTAssertNil(WorkspaceCommand.parse("notebook"))
    XCTAssertEqual(WorkspaceCommand.parse("开始专注二十五分钟。"), .startFocus(1500))
    XCTAssertEqual(WorkspaceCommand.parse("专注半小时"), .startFocus(1800))
    XCTAssertEqual(WorkspaceCommand.parse("start focus twenty-five minutes"), .startFocus(1500))
    XCTAssertEqual(WorkspaceCommand.parse("25分集中"), .startFocus(1500))
    XCTAssertEqual(WorkspaceCommand.parse("暂停计时"), .pause)
    XCTAssertEqual(WorkspaceCommand.parse("继续计时"), .resume)
    XCTAssertEqual(WorkspaceCommand.parse("延长五分钟"), .extend)
    XCTAssertEqual(WorkspaceCommand.parse("stop timer"), .cancel)
    XCTAssertEqual(WorkspaceCommand.parse("撤销"), .undo)
    XCTAssertNil(WorkspaceCommand.parse("我不想暂停计时"))
    XCTAssertNil(WorkspaceCommand.parse("专注 -5 分钟"))
    XCTAssertNil(WorkspaceCommand.parse("专注 25 小时"))
    XCTAssertNil(WorkspaceCommand.parse("专注 0 秒"))
  }

  @MainActor func testMapAndCameraCommandsOpenNativePanelsWithoutAWebSession() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let workspace = store(directory)
    let commands = WorkspaceCommands(store: workspace)
    var destinations: [DemoModule] = []
    commands.navigate = { destinations.append($0) }
    commands.query = "打开地图"
    XCTAssertTrue(commands.submit())
    commands.receiveSpeech(type: "final", text: "open camera")
    commands.receiveSpeech(type: "final", text: "地図を開く")
    XCTAssertEqual(destinations, [.navigation, .camera, .navigation])
    XCTAssertFalse(commands.resultIsError)
    XCTAssertEqual(WorkspaceCommand.parse("记下 打开摄像头"), .note("打开摄像头"))
    XCTAssertNil(WorkspaceCommand.parse("不要打开摄像头"))
    XCTAssertEqual(WorkspaceCommand.parse("カメラを開く"), .open(.camera))
    _ = await workspace.flush()
  }

  @MainActor func testNotesDraftAndFocusSurviveRestart() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let first = store(directory)
    first.updateDraft("还没写完的草稿")
    XCTAssertTrue(first.addNote("已完成的记录"))
    XCTAssertTrue(first.startFocus(seconds: 120))
    first.rememberAction("focus25")
    let deadline = first.data.focus?.deadline
    let saved = await first.flush()
    XCTAssertTrue(saved)
    let restored = store(directory)
    XCTAssertEqual(restored.data.notes.first?.text, "已完成的记录")
    XCTAssertEqual(restored.data.noteDraft, "还没写完的草稿")
    XCTAssertEqual(restored.data.focus?.deadline, deadline)
    XCTAssertEqual(restored.data.focus?.status, .running)
    XCTAssertEqual(restored.data.recentActions, ["focus25"])
  }

  @MainActor func testDraftAndActionBurstPersistsLatestRevision() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let workspace = store(directory)
    for index in 0..<30 { workspace.updateDraft("草稿 \(index)") }
    workspace.addNote(workspace.data.noteDraft, clearDraft: true)
    workspace.updateDraft("下一条")
    let saved = await workspace.flush()
    XCTAssertTrue(saved)
    let restored = store(directory)
    XCTAssertEqual(restored.data.notes.map(\.text), ["草稿 29"])
    XCTAssertEqual(restored.data.noteDraft, "下一条")
  }

  @MainActor func testPauseResumeExtendAndRejectReplacement() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let workspace = store(directory)
    let start = Date.now
    XCTAssertTrue(workspace.startFocus(seconds: 120, at: start))
    XCTAssertFalse(workspace.startFocus(seconds: 180, at: start))
    XCTAssertTrue(workspace.pauseFocus(at: start.addingTimeInterval(30)))
    XCTAssertEqual(workspace.data.focus?.secondsRemaining(at: start.addingTimeInterval(3000)), 90)
    XCTAssertTrue(workspace.extendFocus(at: start.addingTimeInterval(100)))
    XCTAssertEqual(workspace.data.focus?.remaining, 390)
    XCTAssertTrue(workspace.resumeFocus(at: start.addingTimeInterval(3000)))
    XCTAssertEqual(workspace.data.focus?.deadline, start.addingTimeInterval(3390))
    XCTAssertTrue(workspace.cancelFocus())
    XCTAssertNil(workspace.data.focus)
    workspace.undoLastAction()
    XCTAssertEqual(workspace.data.focus?.deadline, start.addingTimeInterval(3390))
    _ = await workspace.flush()
  }

  @MainActor func testSleepAndRelaunchCompleteExactlyOnce() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let workspace = store(directory)
    let start = Date.now.addingTimeInterval(-100)
    XCTAssertTrue(workspace.startFocus(seconds: 30, at: start))
    _ = await workspace.flush()
    let restored = store(directory)
    XCTAssertEqual(restored.data.focus?.status, .completed)
    XCTAssertEqual(restored.data.completions.count, 1)
    XCTAssertEqual(restored.data.completions.first?.completedAt, start.addingTimeInterval(30))
    restored.reconcile(at: .now.addingTimeInterval(100))
    XCTAssertEqual(restored.data.completions.count, 1)
    _ = await restored.flush()
    XCTAssertEqual(store(directory).data.completions.count, 1)
  }

  @MainActor func testNoteUndoAndConcurrentEditorConflict() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let workspace = store(directory)
    workspace.addNote("original")
    let note = try XCTUnwrap(workspace.data.notes.first)
    XCTAssertTrue(workspace.editNote(note.id, text: "edited elsewhere", expected: "original"))
    XCTAssertFalse(workspace.editNote(note.id, text: "stale editor", expected: "original"))
    XCTAssertEqual(workspace.data.notes.first?.text, "edited elsewhere")
    workspace.deleteNote(note.id)
    workspace.undoLastAction()
    XCTAssertEqual(workspace.data.notes.first?.text, "edited elsewhere")
    _ = await workspace.flush()
  }

  @MainActor func testClockChangeCompletesTimerWithoutLosingNoteUndo() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let workspace = store(directory)
    let start = Date.now
    workspace.startFocus(seconds: 30, at: start)
    workspace.addNote("keep undo available")
    workspace.refreshClock(at: start.addingTimeInterval(60))
    XCTAssertEqual(workspace.data.focus?.status, .completed)
    XCTAssertEqual(workspace.data.completions.count, 1)
    XCTAssertTrue(workspace.canUndo)
    workspace.undoLastAction()
    XCTAssertTrue(workspace.data.notes.isEmpty)
    XCTAssertEqual(workspace.data.completions.count, 1)
    _ = await workspace.flush()
  }

  @MainActor func testWriteFailureIsVisibleAndRetryKeepsUnsavedData() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let blocked = directory.appending(path: "blocked")
    try Data("not a directory".utf8).write(to: blocked)
    let workspace = store(blocked)
    workspace.addNote("must not disappear")
    let failed = await workspace.flush()
    XCTAssertFalse(failed)
    XCTAssertNotNil(workspace.saveError)
    XCTAssertEqual(workspace.data.notes.first?.text, "must not disappear")
    try FileManager.default.removeItem(at: blocked)
    workspace.retrySave()
    let saved = await workspace.flush()
    XCTAssertTrue(saved)
    XCTAssertNil(workspace.saveError)
    XCTAssertEqual(store(blocked).data.notes.first?.text, "must not disappear")
  }

  @MainActor func testCorruptionPreservesOriginalAndRestoresValidBackup() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let workspace = store(directory)
    workspace.addNote("first")
    _ = await workspace.flush()
    workspace.addNote("second")
    _ = await workspace.flush()
    let url = directory.appending(path: "workspace.json")
    let broken = Data("broken original".utf8)
    try broken.write(to: url)
    let recovered = store(directory)
    XCTAssertFalse(recovered.writable)
    XCTAssertFalse(recovered.addNote("overwrite"))
    XCTAssertEqual(try Data(contentsOf: url), broken)
    await recovered.restoreBackup()
    _ = await recovered.flush()
    XCTAssertTrue(recovered.writable)
    XCTAssertNil(recovered.saveError)
    XCTAssertTrue(recovered.data.notes.contains(where: { $0.text == "first" }))
    let preserved = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("workspace-preserved-") }
    XCTAssertEqual(preserved.count, 1)
    XCTAssertEqual(try Data(contentsOf: XCTUnwrap(preserved.first)), broken)
  }

  @MainActor func testSpeechAndTextUseTheSameNativeActionsWithoutWebView() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let workspace = store(directory)
    let commands = WorkspaceCommands(store: workspace)
    commands.query = "记下 typed note"
    XCTAssertTrue(commands.submit())
    commands.receiveSpeech(type: "partial", text: "记下 partial")
    XCTAssertEqual(workspace.data.notes.count, 1)
    commands.receiveSpeech(type: "final", text: "记下 spoken note")
    XCTAssertEqual(workspace.data.notes.map(\.text), ["spoken note", "typed note"])
    commands.receiveSpeech(type: "final", text: "专注二十五分钟")
    XCTAssertEqual(workspace.data.focus?.duration, 1500)
    commands.query = "暂停计时"
    XCTAssertTrue(commands.submit())
    XCTAssertEqual(workspace.data.focus?.status, .paused)
    commands.receiveSpeech(type: "error", text: nil, code: "speechPermission")
    XCTAssertTrue(commands.resultIsError)
    XCTAssertEqual(commands.speechPhase, "error")
    _ = await workspace.flush()
  }
}
