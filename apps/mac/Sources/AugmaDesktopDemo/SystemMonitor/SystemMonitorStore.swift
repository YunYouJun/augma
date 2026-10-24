import AppKit
import Combine
import Foundation

protocol SystemMetricsSampling: Sendable {
  func sample(includeDisks: Bool) async -> SystemSnapshot
  func resetBaseline() async
}

extension SystemMetricsReader: SystemMetricsSampling {}

/// One sampler serves every window, menu popup and HUD. No timer runs without a visible consumer.
@MainActor
final class SystemMonitorStore: ObservableObject {
  @Published private(set) var snapshot = SystemSnapshot()
  @Published private(set) var isSampling = false
  @Published var hudPinned: Bool {
    didSet {
      defaults.set(hudPinned, forKey: Self.hudKey)
      if oldValue != hudPinned { onHUDPinnedChanged?(hudPinned) }
    }
  }
  @Published var menuBarSummaryEnabled: Bool {
    didSet { defaults.set(menuBarSummaryEnabled, forKey: Self.menuKey) }
  }
  @Published var sampleInterval: TimeInterval {
    didSet {
      if ![1.0, 2.0, 5.0].contains(sampleInterval) { sampleInterval = 2 }
      defaults.set(sampleInterval, forKey: Self.intervalKey)
    }
  }
  var onHUDPinnedChanged: ((Bool) -> Void)?

  static let hudKey = "systemMonitorHUDPinned"
  static let menuKey = "systemMonitorMenuSummary"
  static let intervalKey = "systemMonitorSampleInterval"
  private let defaults: UserDefaults
  private let reader: any SystemMetricsSampling
  private var consumers: Set<String> = []
  private var pollingTask: Task<Void, Never>?
  private var lifecycle: [AnyCancellable] = []
  private var generation = 0
  private var sleeping = false
  private var needsBaselineReset = true
  private var lastDiskSample: ContinuousClock.Instant?

  init(reader: any SystemMetricsSampling = SystemMetricsReader(), defaults: UserDefaults = .standard,
       observeLifecycle: Bool = true) {
    self.reader = reader
    self.defaults = defaults
    hudPinned = defaults.bool(forKey: Self.hudKey)
    menuBarSummaryEnabled = defaults.object(forKey: Self.menuKey) as? Bool ?? true
    let interval = defaults.double(forKey: Self.intervalKey)
    sampleInterval = [1.0, 2.0, 5.0].contains(interval) ? interval : 2
    if observeLifecycle {
      NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)
        .merge(with: NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidSleepNotification))
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in self?.setSleeping(true) }.store(in: &lifecycle)
      NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
        .merge(with: NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidWakeNotification))
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in self?.setSleeping(false) }.store(in: &lifecycle)
      NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didMountNotification)
        .merge(with: NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didUnmountNotification))
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in self?.lastDiskSample = nil }.store(in: &lifecycle)
    }
  }

  func startObserving(_ id: String) {
    consumers.insert(id)
    startIfNeeded()
  }

  func stopObserving(_ id: String) {
    consumers.remove(id)
    if consumers.isEmpty { stopPolling() }
  }

  func refresh(forceDisks: Bool = true) async {
    guard !isSampling, !sleeping else { return }
    let currentGeneration = generation
    isSampling = true
    defer { isSampling = false }
    if needsBaselineReset {
      needsBaselineReset = false
      await reader.resetBaseline()
    }
    guard !Task.isCancelled, currentGeneration == generation, !sleeping else { return }
    let includeDisks = forceDisks || (lastDiskSample.map { $0.duration(to: .now) >= .seconds(30) } ?? true)
    let next = await reader.sample(includeDisks: includeDisks)
    guard !Task.isCancelled, currentGeneration == generation, !sleeping else { return }
    snapshot = next
    if includeDisks { lastDiskSample = .now }
  }

  func setSleeping(_ value: Bool) {
    sleeping = value
    if value { stopPolling() }
    else { startIfNeeded() }
  }

  private func startIfNeeded() {
    guard !sleeping, !consumers.isEmpty, pollingTask == nil else { return }
    pollingTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.refresh(forceDisks: false)
        let interval = self?.sampleInterval ?? 2
        do { try await Task.sleep(for: .seconds(interval)) }
        catch { return }
      }
    }
  }

  private func stopPolling() {
    pollingTask?.cancel()
    pollingTask = nil
    generation += 1
    needsBaselineReset = true
  }

  deinit { pollingTask?.cancel() }
}
