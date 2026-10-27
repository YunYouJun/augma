import AppKit
import Combine
import Foundation

@MainActor
final class ApplicationMarketStore: ObservableObject {
  enum Phase { case idle, checking, installing, scanning, analyzing, cleaning }
  @Published private(set) var phase: Phase = .idle
  @Published private(set) var installation: MoleInstallation?
  @Published private(set) var plan: DiskCleanupPlan?
  @Published private(set) var feedback = ""
  @Published private(set) var error = ""
  @Published var draft = String(localized: "帮我尽量腾出 20 GB，保留模型和最近项目。")
  @Published var scope: URL
  @Published var selection: Set<UUID> = []
  private let mole: any MoleToolProviding
  private let scanner: SystemCleanupScanner
  private let completion: NativeAssistantStore.Completion?
  private let runtimeOwner = UUID()
  private var request: Task<Void, Never>?
  private var generation = 0
  private var observers: Set<UUID> = []
  private var visible: Bool { !observers.isEmpty }
  private var pendingGoal: DiskCleanupGoal?
  var isBusy: Bool { phase != .idle }
  var isMutating: Bool { phase == .installing || phase == .cleaning }
  var selectedCandidates: [CleanupCandidate] { plan?.candidates.filter { selection.contains($0.id) } ?? [] }

  init(mole: any MoleToolProviding = MoleToolClient(), scanner: SystemCleanupScanner = SystemCleanupScanner(),
       scope: URL = FileManager.default.homeDirectoryForCurrentUser,
       completion: NativeAssistantStore.Completion? = nil) {
    self.mole = mole; self.scanner = scanner; self.scope = scope; self.completion = completion
  }

  func activate(_ observer: UUID) {
    observers.insert(observer)
    if installation == nil { refresh() }
    else if pendingGoal != nil { beginPlan() }
  }

  func deactivate(_ observer: UUID) {
    observers.remove(observer)
    if !visible && !isMutating { cancel() }
  }

  func refresh() {
    guard !isBusy else { return }
    phase = .checking; error = ""
    let token = generation
    request = Task { [weak self, mole] in
      do {
        let result = try await mole.inspect()
        guard let self, self.generation == token, !Task.isCancelled else { return }
        self.installation = result; self.phase = .idle
        if self.pendingGoal != nil && self.visible { self.beginPlan() }
      } catch { self?.fail(error, token: token) }
    }
  }

  func changeScope(_ url: URL) {
    guard !isBusy else { return }
    scope = url.standardizedFileURL.resolvingSymlinksInPath()
    plan = nil; selection = []; pendingGoal = nil; feedback = ""; error = ""
  }

  func showInvalidRequest() {
    error = String(localized: "请输入清理磁盘的目标，例如：帮我尽量腾出 20 GB，保留模型和最近项目。")
  }

  func installMole() {
    guard !isBusy else { return }
    phase = .installing; error = ""
    feedback = String(localized: "正在通过 Homebrew 安装 Mole CLI，可能需要几分钟。安装不会执行清理。")
    let token = generation
    request = Task { [weak self, mole] in
      do {
        let result = try await mole.install()
        guard let self, self.generation == token else { return }
        self.installation = result; self.phase = .idle
        self.feedback = String(localized: "Mole CLI 已安装，可以生成清理计划。")
        if self.pendingGoal != nil && self.visible { self.beginPlan() }
      } catch { self?.fail(error, token: token) }
    }
  }

  @discardableResult func requestCleanup(_ text: String) -> Bool {
    guard let goal = DiskCleanupGoal.parse(text), !isMutating else { return false }
    if isBusy { cancel() }
    draft = text; pendingGoal = goal; plan = nil; selection = []; error = ""; feedback = ""
    if visible { beginPlan() }
    return true
  }

  private func beginPlan() {
    guard !isBusy, let goal = pendingGoal else { return }
    guard installation?.supported == true else {
      feedback = installation?.version == nil ? String(localized: "先安装 Mole CLI，安装完成后可继续本次分析。")
        : String(localized: "Mole 版本尚未适配，请保留当前版本并查看诊断。")
      return
    }
    pendingGoal = nil; phase = .scanning; error = ""; feedback = ""; plan = nil; selection = []
    let token = generation, scope = scope
    request = Task { [weak self, mole, scanner] in
      do {
        let report: MoleDiskReport
        var warning = ""
        do { report = try await mole.analyze(scope: scope) }
        catch {
          try Task.checkCancellation()
          report = .init(entries: [], incomplete: true, measuredBytes: nil)
          warning = String(localized: "Mole 占用分析暂不可用，已回退到本地候选计划。可缩小目录后重新扫描。") + "\n" + error.localizedDescription
        }
        try Task.checkCancellation()
        let scan = try await scanner.scan()
        guard let self, self.generation == token, !Task.isCancelled else { return }
        self.plan = DiskCleanupPlan.build(goal: goal, scope: scope, scan: scan, occupancy: report)
        self.feedback = warning
        self.phase = .idle
      } catch { self?.fail(error, token: token) }
    }
  }

  func analyzeWithAI(apiKey: String = "") {
    guard !isBusy, let plan else { return }
    phase = .analyzing; error = ""
    let token = generation
    request = Task { [weak self, completion] in
      do {
        let messages = try DiskCleanupPlanning.messages(plan)
        let result: String
        if let completion { result = try await completion(messages, apiKey) }
        else {
          guard let self else { return }
          result = try await NativeAssistantRuntime.shared.complete(messages: messages, owner: self.runtimeOwner)
          NativeAssistantRuntime.shared.cancel(owner: self.runtimeOwner)
        }
        let optimized = try DiskCleanupPlanning.apply(result, to: plan)
        guard let self, self.generation == token, !Task.isCancelled else { return }
        self.plan = optimized; self.selection = []; self.phase = .idle
      } catch { self?.fail(error, token: token) }
    }
  }

  func moveToTrash(planID: UUID, ids: Set<UUID>) {
    guard !isBusy, let plan, plan.acceptsApproval(planID: planID, ids: ids, scope: scope) else {
      error = String(localized: "计划已变化或过期，请重新扫描并确认。")
      return
    }
    phase = .cleaning; error = ""
    request = Task { [weak self, scanner] in
      let before = Self.availableSpace(at: plan.scope)
      let result = await scanner.moveToTrash(ids: ids)
      let after = Self.availableSpace(at: plan.scope)
      guard let self else { return }
      self.plan = nil; self.selection = []; self.phase = .idle
      self.feedback = String(format: String(localized: "已移入废纸篓 %lld 项，跳过 %lld 项。确认后清空废纸篓才会释放空间。"),
                             result.moved.count, result.failures.count)
      if let before, let after {
        self.feedback += "\n" + String(format: String(localized: "磁盘可用空间：操作前 %@，操作后 %@。读数也受其他应用影响。"),
          SystemMetricFormat.bytes(before, style: .file), SystemMetricFormat.bytes(after, style: .file))
      }
      if !result.failures.isEmpty { self.error = result.failures.joined(separator: "\n") }
    }
  }

  func cancel() {
    guard !isMutating else { return }
    if phase == .analyzing && completion == nil { NativeAssistantRuntime.shared.cancel(owner: runtimeOwner) }
    generation += 1; request?.cancel(); request = nil; phase = .idle; pendingGoal = nil
  }

  private func fail(_ failure: Error, token: Int) {
    guard generation == token else { return }
    phase = .idle; feedback = ""; error = failure.localizedDescription
  }

  private static func availableSpace(at url: URL) -> UInt64? {
    (try? FileManager.default.attributesOfFileSystem(forPath: url.path)[.systemFreeSize] as? NSNumber)?.uint64Value
  }

  deinit { request?.cancel() }
}
