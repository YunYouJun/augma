import AppKit
import Combine
import Foundation

@MainActor
final class SystemCleanupStore: ObservableObject {
  let homebrew: HomebrewCleanupStore
  let simulator: SimulatorCleanupStore
  enum Phase { case idle, scanning, cleaning, analyzing }
  @Published private(set) var phase: Phase = .idle
  @Published private(set) var scan: CleanupScan?
  @Published var selection: Set<UUID> = []
  @Published private(set) var feedback = ""
  @Published private(set) var advice: CleanupAdvice?
  @Published private(set) var advisedApplications: [String: ApplicationMemoryUsage] = [:]
  private let scanner: SystemCleanupScanner
  private let completion: NativeAssistantStore.Completion?
  private let runtimeOwner = UUID()
  private var request: Task<Void, Never>?
  private var generation = 0

  init(scanner: SystemCleanupScanner = SystemCleanupScanner(),
       homebrew: HomebrewCleanupStore = HomebrewCleanupStore(),
       simulator: SimulatorCleanupStore = SimulatorCleanupStore(),
       completion: NativeAssistantStore.Completion? = nil) {
    self.scanner = scanner
    self.homebrew = homebrew
    self.simulator = simulator
    self.completion = completion
    simulator.canStartOperation = { [weak self] in
      guard let self else { return false }
      return self.phase == .idle && !self.homebrew.isBusy
    }
  }

  var isBusy: Bool { phase != .idle || simulator.isBusy }
  var isCleaning: Bool { phase == .cleaning || homebrew.phase == .cleaning || simulator.isCleaning }
  var selectedCandidates: [CleanupCandidate] { (scan?.candidates ?? []).filter { selection.contains($0.id) } }
  var selectedBytes: UInt64 { selectedCandidates.reduce(0) { $0 + $1.bytes } }

  func startScan() {
    guard !isBusy, !homebrew.isBusy else { return }
    phase = .scanning
    scan = nil
    selection = []
    clearAdvice()
    feedback = ""
    let token = generation
    request = Task { [weak self, scanner] in
      do {
        let result = try await scanner.scan()
        guard let self, self.generation == token, !Task.isCancelled else { return }
        self.scan = result
        self.phase = .idle
      } catch {
        guard let self, self.generation == token else { return }
        self.feedback = error.localizedDescription
        self.phase = .idle
      }
    }
  }

  func moveToTrash(ids: Set<UUID>) {
    guard !isBusy, !homebrew.isBusy, !ids.isEmpty else { return }
    phase = .cleaning
    clearAdvice()
    request = Task { [weak self, scanner] in
      let result = await scanner.moveToTrash(ids: ids)
      guard let self else { return }
      self.scan?.candidates.removeAll { result.moved.contains($0.id) }
      self.selection = []
      self.feedback = String(format: String(localized: "已移入废纸篓 %lld 项，跳过 %lld 项。"),
                             result.moved.count, result.failures.count)
      if !result.failures.isEmpty { self.feedback += "\n" + result.failures.joined(separator: "\n") }
      self.phase = .idle
    }
  }

  func analyze(snapshot: SystemSnapshot, locale: String = Locale.current.identifier, apiKey: String = "",
               homebrew: HomebrewCleanupPreview? = nil) {
    guard !isBusy, !self.homebrew.isBusy, let scan else { return }
    clearAdvice()
    feedback = ""
    let apps = Array((snapshot.applicationMemory?.applications ?? []).prefix(10))
    let mapping = Dictionary(uniqueKeysWithValues: apps.enumerated().map { ("app\($0.offset + 1)", $0.element) })
    phase = .analyzing
    let token = generation
    request = Task { [weak self, completion] in
      do {
        let messages = try CleanupAdvice.messages(scan: scan, snapshot: snapshot, locale: locale, homebrew: homebrew)
        let content: String
        if let completion { content = try await completion(messages, apiKey) }
        else {
          guard let self else { return }
          content = try await NativeAssistantRuntime.shared.complete(messages: messages, owner: self.runtimeOwner)
          guard self.generation == token, !Task.isCancelled else { return }
          NativeAssistantRuntime.shared.cancel(owner: self.runtimeOwner)
        }
        let result = try CleanupAdvice.parse(content, scan: scan, applicationIDs: Set(mapping.keys))
        guard let self, self.generation == token, !Task.isCancelled else { return }
        self.advice = result
        self.advisedApplications = mapping
        self.phase = .idle
      } catch {
        guard let self, self.generation == token else { return }
        self.feedback = String(localized: "AI 建议暂不可用，请检查网络、密钥或稍后重试。")
        self.phase = .idle
      }
    }
  }

  func cancel() {
    guard !isCleaning else { return }
    homebrew.cancelPreview()
    simulator.cancelReadOnly()
    generation += 1
    if phase == .analyzing, completion == nil { NativeAssistantRuntime.shared.cancel(owner: runtimeOwner) }
    request?.cancel()
    request = nil
    phase = .idle
  }

  private func clearAdvice() { advice = nil; advisedApplications = [:] }

  deinit { request?.cancel() }
}
