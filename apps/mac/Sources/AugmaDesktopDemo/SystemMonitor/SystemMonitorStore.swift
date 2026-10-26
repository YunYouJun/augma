import AppKit
import Combine
import Foundation

struct SystemSamplingOptions: Sendable {
  var includeDisks: Bool
  var includeApplications = false
  var includeSensors = false
}

enum SystemMonitorDemand { case summary, expanded }

protocol SystemMetricsSampling: Sendable {
  func sample(options: SystemSamplingOptions) async -> SystemSnapshot
  func resetBaseline() async
  func suspend() async
}

extension SystemMetricsReader: SystemMetricsSampling {}

/// One sampler serves every window, menu popup and HUD. No timer runs without a visible consumer.
@MainActor
final class SystemMonitorStore: ObservableObject {
  @Published private(set) var snapshot = SystemSnapshot()
  @Published private(set) var isSampling = false
  @Published private(set) var networkHistory = NetworkHistory()
  @Published var enabled: Bool {
    didSet { defaults.set(enabled, forKey: Self.enabledKey); restartSampling() }
  }
  @Published var applicationMemoryEnabled: Bool {
    didSet { defaults.set(applicationMemoryEnabled, forKey: Self.applicationsKey); restartSampling() }
  }
  @Published var sensorsEnabled: Bool {
    didSet { defaults.set(sensorsEnabled, forKey: Self.sensorsKey); restartSampling() }
  }
  @Published var networkHistoryEnabled: Bool {
    didSet { defaults.set(networkHistoryEnabled, forKey: Self.historyKey); restartSampling() }
  }
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
      guard [0.0, 1.0, 2.0, 5.0, 10.0].contains(sampleInterval) else { sampleInterval = 2; return }
      defaults.set(sampleInterval, forKey: Self.intervalKey)
      restartSampling()
    }
  }
  var onHUDPinnedChanged: ((Bool) -> Void)?

  static let hudKey = "systemMonitorHUDPinned"
  static let menuKey = "systemMonitorMenuSummary"
  static let intervalKey = "systemMonitorSampleInterval"
  static let enabledKey = "systemMonitorEnabled"
  static let applicationsKey = "systemMonitorApplications"
  static let sensorsKey = "systemMonitorSensors"
  static let historyKey = "systemMonitorNetworkHistory"
  private let defaults: UserDefaults
  private let reader: any SystemMetricsSampling
  private var consumers: [String: SystemMonitorDemand] = [:]
  private var pollingTask: Task<Void, Never>?
  private var releaseTask: Task<Void, Never>?
  private var lifecycle: [AnyCancellable] = []
  private var generation = 0
  private var sleeping = false
  private var needsBaselineReset = true
  private var lastDiskSample: ContinuousClock.Instant?

  init(reader: any SystemMetricsSampling = SystemMetricsReader(), defaults: UserDefaults = .standard,
       observeLifecycle: Bool = true) {
    self.reader = reader
    self.defaults = defaults
    enabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
    applicationMemoryEnabled = defaults.object(forKey: Self.applicationsKey) as? Bool ?? true
    sensorsEnabled = defaults.bool(forKey: Self.sensorsKey)
    networkHistoryEnabled = defaults.bool(forKey: Self.historyKey)
    hudPinned = defaults.bool(forKey: Self.hudKey)
    menuBarSummaryEnabled = defaults.object(forKey: Self.menuKey) as? Bool ?? true
    let interval = defaults.double(forKey: Self.intervalKey)
    sampleInterval = defaults.object(forKey: Self.intervalKey) != nil && [0.0, 1.0, 2.0, 5.0, 10.0].contains(interval) ? interval : 2
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

  private var expanded: Bool { consumers.values.contains { $0 == .expanded } }

  func startObserving(_ id: String, demand: SystemMonitorDemand = .summary) {
    guard consumers[id] != demand else { return }
    let wasExpanded = expanded
    consumers[id] = demand
    if wasExpanded != expanded { restartSampling() }
    else { startIfNeeded() }
  }

  func stopObserving(_ id: String) {
    let wasExpanded = expanded
    guard consumers.removeValue(forKey: id) != nil else { return }
    if consumers.isEmpty { stopPolling() }
    else if wasExpanded && !expanded {
      // Closing the menu/detail must not reset the HUD's CPU/network baseline.
      snapshot.applicationMemory = nil
      snapshot.sensors = nil
      networkHistory.clear()
    }
  }

  func refresh(forceDisks: Bool = true) async {
    guard enabled, !isSampling, !sleeping else { return }
    let currentGeneration = generation
    isSampling = true
    defer { isSampling = false }
    await releaseTask?.value
    guard !Task.isCancelled, currentGeneration == generation, !sleeping, enabled else { return }
    if needsBaselineReset {
      needsBaselineReset = false
      await reader.resetBaseline()
    }
    guard !Task.isCancelled, currentGeneration == generation, !sleeping else { return }
    let includeDisks = forceDisks || (lastDiskSample.map { $0.duration(to: .now) >= .seconds(30) } ?? true)
    var next = await reader.sample(options: SystemSamplingOptions(
      includeDisks: includeDisks, includeApplications: applicationMemoryEnabled && expanded,
      includeSensors: sensorsEnabled && expanded
    ))
    guard !Task.isCancelled, currentGeneration == generation, !sleeping else { return }
    if !expanded || !applicationMemoryEnabled { next.applicationMemory = nil }
    if !expanded || !sensorsEnabled { next.sensors = nil }
    snapshot = next
    if networkHistoryEnabled && expanded { networkHistory.append(next.network, at: next.sampledAt) }
    if includeDisks { lastDiskSample = .now }
  }

  func setSleeping(_ value: Bool) {
    sleeping = value
    if value { stopPolling() }
    else { startIfNeeded() }
  }

  private func startIfNeeded() {
    guard enabled, !sleeping, !consumers.isEmpty, pollingTask == nil else { return }
    let loopGeneration = generation
    pollingTask = Task { [weak self] in
      while !Task.isCancelled {
        // A cancelled, in-flight read finishes before a newly configured loop samples.
        if self?.isSampling == true {
          try? await Task.sleep(for: .milliseconds(10))
          continue
        }
        await self?.refresh(forceDisks: false)
        let interval = self?.sampleInterval ?? 2
        if interval == 0 { break }
        do { try await Task.sleep(for: .seconds(interval)) }
        catch { return }
      }
      if self?.generation == loopGeneration { self?.pollingTask = nil }
    }
  }

  private func stopPolling() {
    pollingTask?.cancel()
    pollingTask = nil
    generation += 1
    needsBaselineReset = true
    lastDiskSample = nil
    snapshot = SystemSnapshot()
    networkHistory.clear()
    let previousRelease = releaseTask
    let reader = reader
    releaseTask = Task { await previousRelease?.value; await reader.suspend() }
  }

  private func restartSampling() { stopPolling(); startIfNeeded() }

  deinit { pollingTask?.cancel() }
}
