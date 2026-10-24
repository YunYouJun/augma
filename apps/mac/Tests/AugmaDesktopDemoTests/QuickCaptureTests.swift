import XCTest
@testable import AugmaDesktopDemo

@MainActor
private final class CaptureSenderStub: CaptureSending {
  var failure: Error?
  var preparationFailure: Error?
  var calls = 0
  var received: QuickNote?
  var paused = false
  var onSend: ((QuickNote) throws -> Void)?
  private var started = false
  private var startWaiter: CheckedContinuation<Void, Never>?
  private var finishWaiter: CheckedContinuation<Void, Never>?

  func prepare(_ delivery: CaptureDelivery) async throws -> CaptureDelivery {
    if let preparationFailure { throw preparationFailure }
    return delivery
  }
  func send(_ note: QuickNote) async throws -> CaptureReceipt {
    calls += 1
    received = note
    try onSend?(note)
    started = true
    startWaiter?.resume()
    startWaiter = nil
    if paused { await withCheckedContinuation { finishWaiter = $0 } }
    if let failure { throw failure }
    return .init(destination: note.delivery!.destination, remoteID: "remote-note")
  }
  func waitUntilStarted() async {
    if !started { await withCheckedContinuation { startWaiter = $0 } }
  }
  func finish() { finishWaiter?.resume(); finishWaiter = nil }
}

@MainActor
final class MemoryMicrosoftCredentials: MicrosoftCredentialStorage {
  var value: MicrosoftCredentials?
  var writes = 0
  init(_ value: MicrosoftCredentials? = nil) { self.value = value }
  func load(clientID: String) throws -> MicrosoftCredentials? { value }
  func save(_ credentials: MicrosoftCredentials, clientID: String) throws { value = credentials; writes += 1 }
  func remove(clientID: String) throws { value = nil }
}

final class QuickCaptureTests: XCTestCase {
  @MainActor private func withFixture(_ body: (WorkspaceStore, QuickCaptureStore, CaptureSenderStub, URL) async throws -> Void) async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "augma-capture-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let suite = "augma.capture.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { try? FileManager.default.removeItem(at: directory); defaults.removePersistentDomain(forName: suite) }
    let workspace = WorkspaceStore(url: directory.appending(path: "workspace.json"), notifications: FocusNotifications(enabled: false), observeLifecycle: false)
    let sender = CaptureSenderStub()
    let microsoft = MicrosoftToDoStore(defaults: defaults, vault: MemoryMicrosoftCredentials())
    let captures = QuickCaptureStore(workspace: workspace, microsoft: microsoft, sender: sender)
    try await body(workspace, captures, sender, directory)
    _ = await workspace.flush()
  }

  @MainActor func testSavesBeforeSendingAndPreservesNextDraftAfterSuccess() async throws {
    try await withFixture { workspace, captures, sender, _ in
      sender.paused = true
      sender.onSend = { note in
        let persisted = try JSONDecoder().decode(WorkspaceData.self, from: Data(contentsOf: workspace.fileURL))
        XCTAssertEqual(persisted.notes.first?.id, note.id)
        XCTAssertEqual(persisted.notes.first?.delivery?.status, .sending)
        XCTAssertEqual(persisted.noteDraft, "")
      }
      workspace.updateDraft("send this\n完整正文")
      XCTAssertTrue(captures.submit(workspace.data.noteDraft, destination: .appleNotes, clearDraft: true))
      let id = try XCTUnwrap(workspace.data.notes.first?.id)
      await sender.waitUntilStarted()
      workspace.updateDraft("next draft typed while sending")
      captures.send(id)
      XCTAssertFalse(workspace.editNote(id, text: "unsafe edit", expected: "send this\n完整正文"))
      workspace.deleteNote(id)
      XCTAssertEqual(workspace.data.notes.count, 1)
      sender.finish()
      await captures.waitForDelivery(id)
      XCTAssertEqual(sender.calls, 1)
      XCTAssertTrue(workspace.data.notes.isEmpty)
      XCTAssertEqual(workspace.data.noteDraft, "next draft typed while sending")
      XCTAssertEqual(captures.receipt?.destination, .appleNotes)
      let restored = try WorkspaceFile.read(workspace.fileURL)
      XCTAssertTrue(restored.notes.isEmpty)
      XCTAssertEqual(restored.noteDraft, workspace.data.noteDraft)
    }
  }

  @MainActor func testFailureRetainsContentAndTargetAcrossRestartAndCanRetry() async throws {
    try await withFixture { workspace, captures, sender, _ in
      sender.failure = CaptureError.message("offline")
      workspace.updateDraft("buy coffee")
      XCTAssertTrue(captures.submit(workspace.data.noteDraft, destination: .microsoftToDo, clearDraft: true))
      let id = try XCTUnwrap(workspace.data.notes.first?.id)
      await captures.waitForDelivery(id)
      let restored = try WorkspaceFile.read(workspace.fileURL)
      XCTAssertEqual(restored.notes.first?.text, "buy coffee")
      XCTAssertEqual(restored.notes.first?.delivery?.destination, .microsoftToDo)
      XCTAssertEqual(restored.notes.first?.delivery?.status, .failed)
      XCTAssertEqual(restored.notes.first?.delivery?.error, "offline")
      XCTAssertNil(captures.receipt)
      sender.failure = nil
      captures.send(id)
      await captures.waitForDelivery(id)
      XCTAssertEqual(sender.calls, 2)
      XCTAssertTrue(workspace.data.notes.isEmpty)
    }
  }

  @MainActor func testPermissionFailureBeforeWriteIsSafeToRetry() async throws {
    try await withFixture { workspace, captures, sender, _ in
      sender.preparationFailure = CaptureError.message("automation permission denied")
      captures.submit("keep until permission is granted", destination: .appleNotes)
      let id = try XCTUnwrap(workspace.data.notes.first?.id)
      await captures.waitForDelivery(id)
      XCTAssertEqual(sender.calls, 0)
      XCTAssertEqual(workspace.data.notes.first?.delivery?.status, .failed)
      XCTAssertEqual(try WorkspaceFile.read(workspace.fileURL).notes.first?.text, "keep until permission is granted")
      sender.preparationFailure = nil
      captures.send(id)
      await captures.waitForDelivery(id)
      XCTAssertEqual(sender.calls, 1)
      XCTAssertTrue(workspace.data.notes.isEmpty)
    }
  }

  @MainActor func testUncertainDeliveryRequiresExplicitCheckBeforeResending() async throws {
    try await withFixture { workspace, captures, sender, _ in
      sender.failure = CaptureError.uncertain
      captures.submit("possibly already created")
      let id = try XCTUnwrap(workspace.data.notes.first?.id)
      await captures.waitForDelivery(id)
      XCTAssertEqual(workspace.data.notes.first?.delivery?.status, .uncertain)
      captures.send(id)
      captures.retargetAndSend(id, destination: .microsoftToDo)
      XCTAssertEqual(sender.calls, 1)
      XCTAssertFalse(workspace.editNote(id, text: "changed", expected: "possibly already created"))
      sender.failure = nil
      captures.send(id, confirmedAbsent: true)
      await captures.waitForDelivery(id)
      XCTAssertEqual(sender.calls, 2)
      XCTAssertTrue(workspace.data.notes.isEmpty)
    }
  }

  @MainActor func testDiskFailurePreventsRemoteWriteAndRetainsOriginalText() async throws {
    try await withFixture { workspace, captures, sender, directory in
      try FileManager.default.removeItem(at: directory)
      try Data("blocked parent".utf8).write(to: directory)
      captures.submit("must remain recoverable")
      let id = try XCTUnwrap(workspace.data.notes.first?.id)
      await captures.waitForDelivery(id)
      XCTAssertEqual(sender.calls, 0)
      XCTAssertEqual(workspace.data.notes.first?.text, "must remain recoverable")
      XCTAssertEqual(workspace.data.notes.first?.delivery?.status, .failed)
      XCTAssertNotNil(workspace.saveError)
      try FileManager.default.removeItem(at: directory)
      workspace.retrySave()
      _ = await workspace.flush()
    }
  }

  @MainActor func testOldNotesMigrateWithoutSendingAndInterruptedWritesBecomeUncertain() async throws {
    try await withFixture { workspace, _, sender, _ in
      var old = WorkspaceData()
      old.version = 1
      old.notes = [QuickNote(text: "legacy", createdAt: .now, updatedAt: .now)]
      old.noteDraft = "legacy draft"
      try JSONEncoder().encode(old).write(to: workspace.fileURL)
      let restored = try WorkspaceFile.read(workspace.fileURL)
      XCTAssertEqual(restored.version, 2)
      XCTAssertEqual(restored.notes.first?.text, "legacy")
      XCTAssertNil(restored.notes.first?.delivery)
      XCTAssertEqual(sender.calls, 0)
      old.notes[0].delivery = CaptureDelivery(destination: .appleNotes, status: .sending)
      try JSONEncoder().encode(old).write(to: workspace.fileURL)
      XCTAssertEqual(try WorkspaceFile.read(workspace.fileURL).notes.first?.delivery?.status, .uncertain)
    }
  }

  @MainActor func testVoiceAndTypedCaptureRouteToSameQueue() async throws {
    try await withFixture { workspace, captures, sender, _ in
      sender.failure = CaptureError.message("test failure")
      let commands = WorkspaceCommands(store: workspace, captures: captures)
      commands.query = "记下 不要暂停计时"
      XCTAssertTrue(commands.submit())
      let noteID = try XCTUnwrap(workspace.data.notes.first?.id)
      await captures.waitForDelivery(noteID)
      commands.receiveSpeech(type: "final", text: "待办 明天买咖啡")
      let taskID = try XCTUnwrap(workspace.data.notes.first?.id)
      await captures.waitForDelivery(taskID)
      XCTAssertEqual(workspace.data.notes.map(\.delivery?.destination), [.microsoftToDo, .appleNotes])
      XCTAssertEqual(workspace.data.notes.map(\.text), ["明天买咖啡", "不要暂停计时"])
      XCTAssertNil(workspace.data.focus)
    }
  }

  func testNotesHTMLPreservesContentWithoutInterpretingMarkupOrScript() {
    let html = AppleNotesClient.html("<script>\"hello\" & 'world'</script>\r\n\n中文\\text")
    XCTAssertEqual(html, "<div>&lt;script&gt;&quot;hello&quot; &amp; &#39;world&#39;&lt;/script&gt;</div><div><br></div><div>中文\\text</div>")
  }
}
