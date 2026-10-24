import XCTest
@testable import AugmaDesktopDemo

final class SystemMonitorStoreTests: XCTestCase {
  private func preferences() -> (UserDefaults, String) {
    let name = "augma-monitor-tests-" + UUID().uuidString
    return (UserDefaults(suiteName: name)!, name)
  }

  @MainActor func testManualRefreshSharesSamplerAndCachesDiskReads() async {
    let (defaults, name) = preferences()
    defer { defaults.removePersistentDomain(forName: name) }
    let reader = RecordingSystemSampler()
    let store = SystemMonitorStore(reader: reader, defaults: defaults, observeLifecycle: false)
    let initial = await reader.counts()
    XCTAssertEqual(initial.samples, 0)
    await store.refresh(forceDisks: false)
    await store.refresh(forceDisks: false)
    let counts = await reader.counts()
    XCTAssertEqual(counts.samples, 2)
    XCTAssertEqual(counts.resets, 1)
    let diskReads = await reader.diskReads
    XCTAssertEqual(diskReads, [true, false])
    XCTAssertNotNil(store.snapshot.memory)
    XCTAssertFalse(store.isSampling)
  }

  @MainActor func testConsumersShareOneLoopAndFinalCloseResetsBaseline() async throws {
    let (defaults, name) = preferences()
    defer { defaults.removePersistentDomain(forName: name) }
    let reader = RecordingSystemSampler()
    let store = SystemMonitorStore(reader: reader, defaults: defaults, observeLifecycle: false)
    defer { store.stopObserving("detail"); store.stopObserving("menu"); store.stopObserving("hud") }
    store.startObserving("detail")
    try await waitForSample(reader, count: 1)
    store.startObserving("menu")
    store.startObserving("menu")
    store.stopObserving("detail")
    await store.refresh()
    let sharedCounts = await reader.counts()
    XCTAssertEqual(sharedCounts.resets, 1, "Closing one of two consumers must not stop the shared sampler")
    store.stopObserving("menu")
    store.startObserving("hud")
    try await waitForSample(reader, count: sharedCounts.samples + 1)
    let resumedCounts = await reader.counts()
    XCTAssertEqual(resumedCounts.resets, 2)
  }

  @MainActor func testSleepRejectsAnInFlightSampleAndResetsOnWake() async throws {
    let (defaults, name) = preferences()
    defer { defaults.removePersistentDomain(forName: name) }
    let reader = RecordingSystemSampler(suspended: true)
    let store = SystemMonitorStore(reader: reader, defaults: defaults, observeLifecycle: false)
    let task = Task { await store.refresh() }
    try await waitForSample(reader, count: 1)
    store.setSleeping(true)
    await reader.release()
    await task.value
    XCTAssertNil(store.snapshot.memory, "A sample completed after sleep must not publish stale rates")
    await store.refresh()
    let sleepingCounts = await reader.counts()
    XCTAssertEqual(sleepingCounts.samples, 1)
    store.setSleeping(false)
    await store.refresh()
    let awakeCounts = await reader.counts()
    XCTAssertEqual(awakeCounts.resets, 2)
    XCTAssertNotNil(store.snapshot.memory)
  }

  @MainActor func testPreferencesPersistAndNativeRoutesDoNotRequireSimulator() {
    let (defaults, name) = preferences()
    defer { defaults.removePersistentDomain(forName: name) }
    let first = SystemMonitorStore(defaults: defaults, observeLifecycle: false)
    first.hudPinned = true
    first.menuBarSummaryEnabled = false
    first.sampleInterval = 5
    let next = SystemMonitorStore(defaults: defaults, observeLifecycle: false)
    XCTAssertTrue(next.hudPinned)
    XCTAssertFalse(next.menuBarSummaryEnabled)
    XCTAssertEqual(next.sampleInterval, 5)
    XCTAssertEqual(WorkspaceCommand.parse("查看网速"), .open(.monitor))
    XCTAssertEqual(WorkspaceCommand.parse("打开天气"), .open(.weather))
  }

  @MainActor private func waitForSample(_ reader: RecordingSystemSampler, count: Int) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while await reader.counts().samples < count, ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(2))
    }
    let counts = await reader.counts()
    XCTAssertGreaterThanOrEqual(counts.samples, count)
  }
}

private actor RecordingSystemSampler: SystemMetricsSampling {
  private var samples = 0
  private var resets = 0
  private var suspended: Bool
  private var continuation: CheckedContinuation<Void, Never>?
  private(set) var diskReads: [Bool] = []

  init(suspended: Bool = false) { self.suspended = suspended }
  func counts() -> (samples: Int, resets: Int) { (samples, resets) }
  func resetBaseline() { resets += 1 }
  func sample(includeDisks: Bool) async -> SystemSnapshot {
    samples += 1
    diskReads.append(includeDisks)
    if suspended { await withCheckedContinuation { continuation = $0 } }
    return SystemSnapshot(memory: MemoryUsage(total: 1024, used: 512, compressed: 64, swapUsed: 0, pressure: .normal))
  }
  func release() {
    suspended = false
    continuation?.resume()
    continuation = nil
  }
}
