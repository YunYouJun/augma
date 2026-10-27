import Combine
import Foundation

@MainActor
final class SimulatorCleanupStore: ObservableObject {
  enum Phase { case idle, scanning, analyzing, cleaning }
  @Published private(set) var phase: Phase = .idle
  @Published private(set) var scan: SimulatorCleanupScan?
  @Published private(set) var receipt: SimulatorCleanupReceipt?
  @Published private(set) var advice: SimulatorCleanupAdvice?
  @Published private(set) var error: String?
  @Published var selection: Set<String> = []

  var canStartOperation: @MainActor () -> Bool = { true }
  private let client: any SimulatorCleanupProviding
  private let completion: NativeAssistantStore.Completion?
  private let runtimeOwner = UUID()
  private var request: Task<Void, Never>?
  private var generation = 0

  init(client: any SimulatorCleanupProviding = SimulatorCleanupClient(),
       completion: NativeAssistantStore.Completion? = nil) {
    self.client = client
    self.completion = completion
  }

  var isBusy: Bool { phase != .idle }
  var isCleaning: Bool { phase == .cleaning }
  var selectedItems: [SimulatorCleanupItem] {
    (scan?.items ?? []).filter { $0.canDelete && selection.contains($0.id) }
  }
  var selectedBytes: UInt64 {
    selectedItems.reduce(0) { total, item in
      let (sum, overflow) = total.addingReportingOverflow(item.bytes ?? 0)
      return overflow ? .max : sum
    }
  }

  func startScan() {
    guard !isBusy, canStartOperation() else { return }
    generation += 1
    let token = generation
    phase = .scanning
    scan = nil; receipt = nil; advice = nil; error = nil; selection = []
    request = Task { [weak self, client] in
      do {
        let result = try await client.scan()
        guard let self, self.generation == token, !Task.isCancelled else { return }
        self.scan = result
        self.phase = .idle
        self.request = nil
      } catch {
        guard let self, self.generation == token, !Task.isCancelled else { return }
        self.error = error.localizedDescription
        self.phase = .idle
        self.request = nil
      }
    }
  }

  func analyze(locale: String = Locale.current.identifier, apiKey: String = "") {
    guard !isBusy, canStartOperation(), let scan else { return }
    generation += 1
    let token = generation
    phase = .analyzing
    advice = nil; error = nil
    request = Task { [weak self, completion, runtimeOwner] in
      defer {
        if completion == nil, self?.generation == token { NativeAssistantRuntime.shared.cancel(owner: runtimeOwner) }
      }
      do {
        let messages = try SimulatorCleanupAdvice.messages(scan: scan, locale: locale)
        let content: String
        if let completion { content = try await completion(messages, apiKey) }
        else { content = try await NativeAssistantRuntime.shared.complete(messages: messages, owner: runtimeOwner) }
        try Task.checkCancellation()
        let result = try SimulatorCleanupAdvice.parse(content, scan: scan)
        guard let self, self.generation == token, self.scan?.id == scan.id else { return }
        self.advice = result
        self.phase = .idle
        self.request = nil
      } catch {
        guard let self, self.generation == token, !Task.isCancelled else { return }
        self.error = String(localized: "AI 建议暂不可用；仍可手动查看和选择模拟器项目。")
        self.phase = .idle
        self.request = nil
      }
    }
  }

  func delete(scanID: UUID, ids: Set<String>, runtimeScopeAcknowledged: Bool = false) {
    guard !isBusy, canStartOperation() else { return }
    guard let scan, scan.id == scanID, !ids.isEmpty,
          ids.isSubset(of: Set(scan.items.filter(\.canDelete).map(\.id))) else {
      error = String(localized: "模拟器扫描已变化，请重新扫描并核对所选项目。")
      return
    }
    generation += 1
    phase = .cleaning
    error = nil; advice = nil; receipt = nil
    // Retain the owner until a confirmed operation has produced its receipt.
    // Leaving a panel may cancel reads, but must not interrupt deletion midway.
    request = Task { [self, client] in
      do {
        receipt = try await client.delete(scanID: scanID, ids: ids,
                                          runtimeScopeAcknowledged: runtimeScopeAcknowledged)
      } catch {
        self.error = String(localized: "模拟器清理未完成；部分项目可能已移除，请重新扫描核对。")
          + "\n" + error.localizedDescription
      }
      self.scan = nil
      selection = []
      phase = .idle
      request = nil
    }
  }

  func cancelReadOnly() {
    guard !isCleaning else { return }
    generation += 1
    if phase == .analyzing, completion == nil { NativeAssistantRuntime.shared.cancel(owner: runtimeOwner) }
    request?.cancel()
    request = nil
    phase = .idle
  }

  deinit { request?.cancel() }
}
