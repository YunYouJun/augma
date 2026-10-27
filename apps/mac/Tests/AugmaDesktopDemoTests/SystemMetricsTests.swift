import XCTest
@testable import AugmaDesktopDemo

final class SystemMetricsTests: XCTestCase {
  func testCPURequiresTwoSamplesAndIncludesNiceWork() throws {
    let before = SystemCPUCounters(user: 100, system: 40, idle: 300, nice: 10)
    let after = SystemCPUCounters(user: 120, system: 50, idle: 360, nice: 20)
    XCTAssertNil(SystemMetricMath.cpuUsage(previous: nil, current: before, interval: 1))
    let usage = try XCTUnwrap(SystemMetricMath.cpuUsage(previous: before, current: after, interval: 1))
    XCTAssertEqual(usage.user, 0.3, accuracy: 0.0001)
    XCTAssertEqual(usage.system, 0.1, accuracy: 0.0001)
    XCTAssertEqual(usage.total, 0.4, accuracy: 0.0001)
    XCTAssertNil(SystemMetricMath.cpuUsage(previous: before, current: before, interval: 1))
  }

  func testCPUTicksSurvive32BitWrapButRejectCounterReset() throws {
    let before = SystemCPUCounters(user: UInt32.max - 9, system: 20, idle: 100, nice: 0)
    let after = SystemCPUCounters(user: 10, system: 40, idle: 160, nice: 0)
    let usage = try XCTUnwrap(SystemMetricMath.cpuUsage(previous: before, current: after, interval: 2))
    XCTAssertEqual(usage.total, 0.4, accuracy: 0.0001)
    let reset = SystemCPUCounters(user: 1, system: 1, idle: 1, nice: 0)
    XCTAssertNil(SystemMetricMath.cpuUsage(previous: after, current: reset, interval: 2))
  }

  func testNetworkUses64BitDifferencesAndDoesNotShowBootTotals() throws {
    let baseline = UInt64(UInt32.max) + 500_000_000
    let before = SystemNetworkCounters(interface: "en0", received: baseline, sent: baseline)
    let after = SystemNetworkCounters(interface: "en0", received: baseline + 8_000_000, sent: baseline + 2_000_000)
    XCTAssertNil(SystemMetricMath.networkUsage(previous: nil, current: before, interval: 2))
    let rate = try XCTUnwrap(SystemMetricMath.networkUsage(previous: before, current: after, interval: 2))
    XCTAssertEqual(rate.receivedPerSecond, 4_000_000)
    XCTAssertEqual(rate.sentPerSecond, 1_000_000)
  }

  func testNetworkRejectsInterfaceChangesCounterRollbackAndMissingReads() {
    let before = SystemNetworkCounters(interface: "en0", received: 100_000, sent: 50_000)
    let switched = SystemNetworkCounters(interface: "en5", received: 900_000, sent: 500_000)
    let reset = SystemNetworkCounters(interface: "en0", received: 10, sent: 20)
    XCTAssertNil(SystemMetricMath.networkUsage(previous: before, current: switched, interval: 1))
    XCTAssertNil(SystemMetricMath.networkUsage(previous: before, current: reset, interval: 1))
    XCTAssertNil(SystemMetricMath.networkUsage(previous: before, current: nil, interval: 1))
  }

  func testSleepAndInvalidIntervalsNeverProduceRates() {
    let before = SystemNetworkCounters(interface: "en0", received: 100, sent: 100)
    let after = SystemNetworkCounters(interface: "en0", received: 200, sent: 300)
    let cpuBefore = SystemCPUCounters(user: 100, system: 100, idle: 100, nice: 0)
    let cpuAfter = SystemCPUCounters(user: 200, system: 150, idle: 150, nice: 0)
    for interval: TimeInterval in [0, -1, .infinity, .nan, SystemMetricMath.maximumSampleInterval + 1] {
      XCTAssertNil(SystemMetricMath.networkUsage(previous: before, current: after, interval: interval))
      XCTAssertNil(SystemMetricMath.cpuUsage(previous: cpuBefore, current: cpuAfter, interval: interval))
    }
  }

  func testDefaultPhysicalInterfaceWinsAndVPNIsNeverSummed() {
    let wifi = SystemNetworkCounters(interface: "en0", received: 1_000, sent: 1_000)
    let ethernet = SystemNetworkCounters(interface: "en5", received: 100_000, sent: 100_000)
    let vpn = SystemNetworkCounters(interface: "utun4", received: 900_000, sent: 900_000)
    let all = [vpn, ethernet, wifi]
    XCTAssertEqual(SystemMetricMath.selectNetworkInterface(all, primary: "en0", previous: "en5")?.interface, "en0")
    XCTAssertEqual(SystemMetricMath.selectNetworkInterface(all, primary: "utun4", previous: "en0")?.interface, "en0")
    XCTAssertEqual(SystemMetricMath.selectNetworkInterface(all, primary: "utun4", previous: nil)?.interface, "en0")
    XCTAssertNil(SystemMetricMath.selectNetworkInterface([vpn], primary: "utun4", previous: nil))
    for name in ["lo0", "awdl0", "llw0", "bridge0", "utun0", "vmenet0", "en", "enx"] {
      XCTAssertFalse(SystemMetricMath.isPhysicalInterface(name))
    }
  }

  func testFallbackDoesNotChooseAnInterfaceForItsHistoricalTraffic() {
    let wifi = SystemNetworkCounters(interface: "en0", received: 1_000, sent: 1_000)
    let ethernet = SystemNetworkCounters(interface: "en5", received: 900_000_000, sent: 900_000_000)
    XCTAssertEqual(SystemMetricMath.selectNetworkInterface([ethernet, wifi], primary: nil, previous: nil)?.interface, "en0")
  }

  func testMemoryExcludesPurgeableCacheAndCountsCompressedStoreOnce() throws {
    let memory = try XCTUnwrap(SystemMetricMath.memoryUsage(
      total: 1_000 * 4_096, pageSize: 4_096, anonymousPages: 300, purgeablePages: 100,
      wiredPages: 100, compressedPages: 50, swapUsed: 80_000, pressure: .warning
    ))
    XCTAssertEqual(memory.used, 350 * 4_096)
    XCTAssertEqual(memory.compressed, 50 * 4_096)
    XCTAssertEqual(memory.swapUsed, 80_000)
    XCTAssertEqual(memory.pressure, .warning)
  }

  func testMemoryBoundsInconsistentKernelSnapshotsAndRejectsOverflow() throws {
    let bounded = try XCTUnwrap(SystemMetricMath.memoryUsage(
      total: 1_000, pageSize: 100, anonymousPages: 10, purgeablePages: 20,
      wiredPages: 4, compressedPages: 8, swapUsed: 0, pressure: .unknown
    ))
    XCTAssertEqual(bounded.used, 1_000)
    XCTAssertEqual(bounded.compressed, 800)
    XCTAssertNil(SystemMetricMath.memoryUsage(
      total: 1_000, pageSize: 4_096, anonymousPages: UInt64.max, purgeablePages: 0,
      wiredPages: 0, compressedPages: 0, swapUsed: 0, pressure: .unknown
    ))
    XCTAssertNil(SystemMetricMath.memoryUsage(
      total: 0, pageSize: 4_096, anonymousPages: 0, purgeablePages: 0,
      wiredPages: 0, compressedPages: 0, swapUsed: 0, pressure: .unknown
    ))
  }

  func testInvalidBatteryCapacityIsUnavailableAndUnknownTimeIsNotZero() throws {
    XCTAssertNil(SystemMetricMath.batteryStatus(current: 10, maximum: 0, isCharging: false, isPluggedIn: false, minutesRemaining: nil))
    XCTAssertNil(SystemMetricMath.batteryStatus(current: .nan, maximum: 100, isCharging: false, isPluggedIn: false, minutesRemaining: nil))
    let charging = try XCTUnwrap(SystemMetricMath.batteryStatus(
      current: 55, maximum: 100, isCharging: true, isPluggedIn: true, minutesRemaining: -1
    ))
    XCTAssertEqual(charging.level, 0.55, accuracy: 0.0001)
    XCTAssertTrue(charging.isCharging)
    XCTAssertTrue(charging.isPluggedIn)
    XCTAssertNil(charging.minutesRemaining)
    XCTAssertEqual(DiskUsage(id: "disk", name: "Volume", total: 100, available: 120).used, 0)
  }
}
