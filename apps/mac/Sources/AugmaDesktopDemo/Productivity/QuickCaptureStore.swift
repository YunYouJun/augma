import AppKit
import Combine

@MainActor
final class QuickCaptureStore: ObservableObject {
  @Published private(set) var active: Set<UUID> = []
  @Published private(set) var receipt: CaptureReceipt?
  @Published private(set) var message: String?
  let microsoft: MicrosoftToDoStore
  private let workspace: WorkspaceStore
  private let sender: any CaptureSending
  private var tasks: [UUID: Task<Void, Never>] = [:]

  init(workspace: WorkspaceStore, microsoft: MicrosoftToDoStore = MicrosoftToDoStore(), sender: (any CaptureSending)? = nil) {
    self.workspace = workspace
    self.microsoft = microsoft
    self.sender = sender ?? NativeCaptureSender(microsoft: microsoft)
    // A previous process may have exited after the server accepted a write.
    for note in workspace.data.notes where note.delivery?.status == .sending {
      var delivery = note.delivery!
      delivery.status = .uncertain
      delivery.error = CaptureError.uncertain.localizedDescription
      workspace.setDelivery(delivery, for: note.id)
    }
  }

  @discardableResult
  func submit(_ text: String, destination: CaptureDestination? = nil, clearDraft: Bool = false) -> Bool {
    let target = destination ?? workspace.data.captureDestination ?? .appleNotes
    guard let id = workspace.enqueueCapture(text, destination: target,
                                          clearDraft: clearDraft) else { return false }
    workspace.setDelivery(initialDelivery(target), for: id)
    send(id)
    return true
  }

  func send(_ id: UUID, confirmedAbsent: Bool = false, destination: CaptureDestination? = nil) {
    guard workspace.writable, !active.contains(id), let note = workspace.data.notes.first(where: { $0.id == id }) else { return }
    guard note.delivery?.status != .uncertain || confirmedAbsent else { return }
    var delivery = note.delivery ?? initialDelivery(destination ?? workspace.data.captureDestination ?? .appleNotes)
    delivery.status = .sending
    delivery.error = nil
    workspace.setDelivery(delivery, for: id)
    active.insert(id)
    receipt = nil
    message = String(localized: "正在发送，内容已加入本地待发送列表。")
    tasks[id] = Task { await deliver(id) }
  }

  func waitForDelivery(_ id: UUID) async { await tasks[id]?.value }

  func retargetAndSend(_ id: UUID, destination: CaptureDestination) {
    guard !active.contains(id), let note = workspace.data.notes.first(where: { $0.id == id }),
          note.delivery?.status != .uncertain else { return }
    workspace.setDelivery(initialDelivery(destination), for: id)
    send(id)
  }

  private func initialDelivery(_ destination: CaptureDestination) -> CaptureDelivery {
    destination == .microsoftToDo ? microsoft.deliveryTarget() : CaptureDelivery(destination: destination)
  }

  private func deliver(_ id: UUID) async {
    defer { active.remove(id); tasks[id] = nil }
    do {
      guard await workspace.flush() else {
        throw CaptureError.message(String(localized: "本地保存失败，尚未发送。请先重试保存或导出内容。"))
      }
      guard var note = workspace.data.notes.first(where: { $0.id == id }), let delivery = note.delivery else { return }
      note.delivery = try await sender.prepare(delivery)
      workspace.setDelivery(note.delivery!, for: id)
      // Bind the target account/list durably before a remote write.
      guard await workspace.flush() else {
        throw CaptureError.message(String(localized: "本地保存失败，尚未发送。请先重试保存或导出内容。"))
      }
      let result = try await sender.send(note)
      workspace.finishDelivery(id)
      let saved = await workspace.flush()
      receipt = result
      message = saved
        ? String(format: String(localized: "已保存到 %@。"), result.destination.title)
        : String(localized: "目标应用已接收，但本地状态保存失败。请重试保存，不要重复发送。")
    } catch {
      guard var delivery = workspace.data.notes.first(where: { $0.id == id })?.delivery else { return }
      if case CaptureError.uncertain = error { delivery.status = .uncertain }
      else { delivery.status = .failed }
      delivery.error = error.localizedDescription
      workspace.setDelivery(delivery, for: id)
      _ = await workspace.flush()
      receipt = nil
      message = error.localizedDescription
    }
  }

  func openDestination(_ destination: CaptureDestination) {
    if destination == .appleNotes {
      if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Notes") {
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
      }
    } else {
      NSWorkspace.shared.open(URL(string: "https://to-do.office.com/tasks/")!)
    }
  }
}

@MainActor
private final class NativeCaptureSender: CaptureSending {
  let microsoft: MicrosoftToDoStore
  init(microsoft: MicrosoftToDoStore) { self.microsoft = microsoft }

  func prepare(_ delivery: CaptureDelivery) async throws -> CaptureDelivery {
    if delivery.destination == .microsoftToDo {
      do { return try await microsoft.prepare(delivery) }
      catch { throw CaptureError.message(MicrosoftToDoStore.message(for: error)) }
    } else {
      try await AppleNotesClient().prepare()
    }
    return delivery
  }

  func send(_ note: QuickNote) async throws -> CaptureReceipt {
    if note.delivery?.destination == .microsoftToDo { return try await microsoft.createTask(note) }
    return try await AppleNotesClient().create(text: note.text)
  }
}
