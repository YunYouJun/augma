import AppKit
import Combine

@MainActor
final class WorkspaceStore: ObservableObject {
  @Published private(set) var data: WorkspaceData
  @Published private(set) var saveError: String?
  @Published private(set) var saving = false
  @Published private(set) var canUndo = false
  let notifications: FocusNotifications
  let fileURL: URL
  private let file: WorkspaceFile
  private let automaticTimers: Bool
  private var revision = 0
  private var savedRevision = 0
  private var unreadable = false
  private var saveTask: Task<Void, Never>?
  private var completionTask: Task<Void, Never>?
  private var observers: [AnyCancellable] = []
  private var undo: UndoAction?
  private enum UndoAction { case removeNote(UUID), restoreNote(QuickNote), focus(FocusSession?) }

  init(url: URL = WorkspaceFile.defaultURL, notifications: FocusNotifications = FocusNotifications(), observeLifecycle: Bool = true) {
    fileURL = url
    file = WorkspaceFile(url: url)
    automaticTimers = observeLifecycle
    self.notifications = notifications
    do { data = try WorkspaceFile.read(url) }
    catch {
      data = WorkspaceData()
      unreadable = true
      saveError = String(localized: "无法读取本地数据。原文件未覆盖，可尝试恢复备份。")
    }
    reconcile()
    scheduleCompletion()
    notifications.sync(data.focus)
    if observeLifecycle {
      NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
        .merge(with: NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
        .merge(with: NotificationCenter.default.publisher(for: .NSSystemClockDidChange))
        .sink { [weak self] _ in self?.refreshClock() }.store(in: &observers)
    }
  }

  var writable: Bool { !unreadable }

  func selectCaptureDestination(_ destination: CaptureDestination) {
    guard writable else { return }
    data.captureDestination = destination
    persist()
  }

  @discardableResult
  func enqueueCapture(_ text: String, destination: CaptureDestination, clearDraft: Bool = false) -> UUID? {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard writable, !value.isEmpty, value.count <= 20_000 else { return nil }
    let note = QuickNote(text: value, createdAt: .now, updatedAt: .now,
                         delivery: CaptureDelivery(destination: destination))
    data.notes.insert(note, at: 0)
    if clearDraft, data.noteDraft == text { data.noteDraft = "" }
    // Sending creates an external record; the local undo stack must not imply it can undo that.
    undo = nil
    canUndo = false
    persist()
    return note.id
  }

  func setDelivery(_ delivery: CaptureDelivery, for id: UUID) {
    guard writable, let index = data.notes.firstIndex(where: { $0.id == id }) else { return }
    data.notes[index].delivery = delivery
    undo = nil
    canUndo = false
    persist()
  }

  func finishDelivery(_ id: UUID) {
    guard writable else { return }
    data.notes.removeAll { $0.id == id }
    undo = nil
    canUndo = false
    persist()
  }

  func updateDraft(_ text: String) {
    guard writable else { return }
    data.noteDraft = String(text.prefix(20_000))
    persist(debounce: true)
  }

  @discardableResult
  func addNote(_ text: String, clearDraft: Bool = false, at now: Date = .now) -> Bool {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard writable, !value.isEmpty, value.count <= 20_000 else { return false }
    let note = QuickNote(text: value, createdAt: now, updatedAt: now)
    data.notes.insert(note, at: 0)
    if clearDraft { data.noteDraft = "" }
    setUndo(.removeNote(note.id))
    persist()
    return true
  }

  @discardableResult
  func editNote(_ id: UUID, text: String, expected: String, at now: Date = .now) -> Bool {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard writable, !value.isEmpty, value.count <= 20_000,
          let index = data.notes.firstIndex(where: { $0.id == id }), data.notes[index].text == expected,
          data.notes[index].delivery?.status != .sending,
          data.notes[index].delivery?.status != .uncertain else { return false }
    setUndo(.restoreNote(data.notes[index]))
    data.notes[index].text = value
    data.notes[index].updatedAt = now
    persist()
    return true
  }

  func deleteNote(_ id: UUID) {
    guard writable, let note = data.notes.first(where: { $0.id == id }), note.delivery?.status != .sending else { return }
    data.notes.removeAll { $0.id == id }
    setUndo(.restoreNote(note))
    persist()
  }

  @discardableResult
  func startFocus(seconds: TimeInterval, at now: Date = .now) -> Bool {
    reconcile(at: now)
    guard writable, seconds.isFinite, (5...86_400).contains(seconds),
          data.focus == nil || data.focus?.status == .completed else { return false }
    setUndo(.focus(data.focus))
    data.focus = FocusSession(startedAt: now, duration: seconds, remaining: seconds,
                              deadline: now.addingTimeInterval(seconds), status: .running)
    focusChanged()
    return true
  }

  @discardableResult
  func pauseFocus(at now: Date = .now) -> Bool {
    reconcile(at: now)
    guard writable, var session = data.focus, session.status == .running else { return false }
    setUndo(.focus(session))
    session.remaining = session.secondsRemaining(at: now)
    session.deadline = nil
    session.status = .paused
    data.focus = session
    focusChanged()
    return true
  }

  @discardableResult
  func resumeFocus(at now: Date = .now) -> Bool {
    guard writable, var session = data.focus, session.status == .paused else { return false }
    setUndo(.focus(session))
    session.deadline = now.addingTimeInterval(session.remaining)
    session.status = .running
    data.focus = session
    focusChanged()
    return true
  }

  @discardableResult
  func extendFocus(seconds: TimeInterval = 300, at now: Date = .now) -> Bool {
    reconcile(at: now)
    guard writable, seconds.isFinite, seconds > 0, var session = data.focus,
          session.status != .completed, session.duration + seconds <= 86_400 else { return false }
    setUndo(.focus(session))
    session.duration += seconds
    session.remaining += seconds
    if let deadline = session.deadline { session.deadline = deadline.addingTimeInterval(seconds) }
    data.focus = session
    focusChanged()
    return true
  }

  @discardableResult
  func cancelFocus() -> Bool {
    guard writable, let session = data.focus else { return false }
    setUndo(.focus(session))
    data.focus = nil
    focusChanged()
    return true
  }

  func reconcile(at now: Date = .now) {
    guard writable, var session = data.focus, session.status == .running,
          let deadline = session.deadline, deadline <= now else { return }
    session.status = .completed
    session.remaining = 0
    data.focus = session
    if !data.completions.contains(where: { $0.id == session.id }) {
      data.completions.insert(FocusCompletion(id: session.id, duration: session.duration, completedAt: deadline), at: 0)
    }
    if case .focus = undo { undo = nil; canUndo = false }
    completionTask?.cancel()
    persist()
    // The system already owns the scheduled notification. Do not cancel it at its deadline.
  }

  func refreshClock(at now: Date = .now) {
    reconcile(at: now)
    scheduleCompletion()
    if data.focus?.status == .running { notifications.sync(data.focus) }
  }

  func undoLastAction() {
    guard writable, let undo else { return }
    switch undo {
    case .removeNote(let id): data.notes.removeAll { $0.id == id }
    case .restoreNote(let note):
      data.notes.removeAll { $0.id == note.id }
      data.notes.append(note)
      data.notes.sort { $0.createdAt > $1.createdAt }
    case .focus(let session): data.focus = session
    }
    self.undo = nil
    canUndo = false
    reconcile()
    focusChanged()
  }

  func rememberAction(_ id: String) {
    guard writable else { return }
    data.recentActions.removeAll { $0 == id }
    data.recentActions.insert(id, at: 0)
    data.recentActions = Array(data.recentActions.prefix(8))
    persist()
  }

  func retrySave() { if writable { persist() } }

  func restoreBackup() async {
    await saveTask?.value
    do {
      data = try await file.restoreBackup()
      unreadable = false
      saveError = nil
      undo = nil
      canUndo = false
      reconcile()
      focusChanged()
    } catch { saveError = String(localized: "备份恢复失败，原文件仍然保留。") }
  }

  func flush() async -> Bool {
    if saving { persist() }
    await saveTask?.value
    return savedRevision == revision
  }

  private func setUndo(_ action: UndoAction) { undo = action; canUndo = true }

  private func focusChanged() {
    persist()
    scheduleCompletion()
    notifications.sync(data.focus)
  }

  private func scheduleCompletion() {
    completionTask?.cancel()
    guard automaticTimers else { return }
    guard let session = data.focus, session.status == .running, let deadline = session.deadline else { return }
    completionTask = Task { [weak self] in
      do { try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow))) } catch { return }
      self?.reconcile()
      // A clock change can move the wall-clock deadline while this task is asleep.
      if self?.data.focus?.status == .running { self?.scheduleCompletion() }
    }
  }

  private func persist(debounce: Bool = false) {
    guard writable else { return }
    revision += 1
    let revision = revision
    let value = data
    saving = true
    saveTask?.cancel()
    saveTask = Task { [weak self, file] in
      if debounce { do { try await Task.sleep(for: .milliseconds(300)) } catch { return } }
      do {
        try await file.save(value, revision: revision)
        guard let self else { return }
        self.savedRevision = max(self.savedRevision, revision)
        if revision == self.revision { self.saving = false; self.saveError = nil }
      } catch {
        guard let self, revision == self.revision else { return }
        self.saving = false
        self.saveError = String(localized: "保存失败。更改仍在内存中，请重试或导出记录。")
      }
    }
  }
}
