import XCTest
@testable import AugmaDesktopDemo

final class OptionalMonitoringTests: XCTestCase {
  func testSMCRequestsOnlyAllowReadOperationsAndHaveTheExpectedPacketLayout() throws {
    let request = try XCTUnwrap(SMCReadCodec.request(key: "TC0D", command: 5, size: 2))
    XCTAssertEqual(request.count, 80)
    XCTAssertEqual(Array(request.prefix(4)), [0x44, 0x30, 0x43, 0x54])
    XCTAssertEqual(request[28], 2)
    XCTAssertEqual(request[42], 5)
    XCTAssertNil(SMCReadCodec.request(key: "F0Ac", command: 6))
    XCTAssertNil(SMCReadCodec.request(key: "abc", command: 9))
    XCTAssertNil(SMCReadCodec.request(key: "F0Ac", command: 5, size: 33))
  }

  func testTemperatureAndFanDecodersHandleNativeFloatAndBigEndianFixedPoint() throws {
    XCTAssertEqual(SMCReadCodec.decode(type: SMCReadCodec.fourCC("sp78")!, bytes: [56, 128]), 56.5)
    XCTAssertEqual(SMCReadCodec.decode(type: SMCReadCodec.fourCC("sp78")!, bytes: [255, 0]), -1)
    XCTAssertEqual(SMCReadCodec.decode(type: SMCReadCodec.fourCC("fpe2")!, bytes: [0x16, 0xD0]), 1460)
    XCTAssertEqual(SMCReadCodec.decode(type: SMCReadCodec.fourCC("flt ")!, bytes: [0, 0, 0x62, 0x42]), 56.5)
    XCTAssertEqual(SMCReadCodec.decode(type: SMCReadCodec.fourCC("ui8 ")!, bytes: [0]), 0, "A stopped fan is a valid zero")
    XCTAssertNil(SMCReadCodec.decode(type: SMCReadCodec.fourCC("flt ")!, bytes: [0, 0, 0x80, 0x7F]))
    XCTAssertNil(SMCReadCodec.decode(type: SMCReadCodec.fourCC("sp78")!, bytes: [0]))
    XCTAssertNil(SMCReadCodec.decode(type: 0, bytes: [0, 0]))
    for invalid in [0.0, 15, 128, .nan, .infinity] { XCTAssertFalse(SMCReadCodec.validTemperature(invalid)) }
    XCTAssertTrue(SMCReadCodec.validTemperature(56.5))
    XCTAssertTrue(SMCReadCodec.cpuKeys(brand: "Unknown future chip").isEmpty)
    XCTAssertTrue(SMCReadCodec.cpuKeys(brand: "Apple M5 Pro").contains("Tp00"))
    XCTAssertFalse(SMCReadCodec.cpuKeys(brand: "Apple M5 Pro").contains("Te05"))
  }

  func testNetworkHistoryIsBoundedByTimeAndCountAndReleasesItsStorage() {
    var history = NetworkHistory()
    let start = Date(timeIntervalSince1970: 1_000)
    let usage = NetworkUsage(interface: "en0", receivedPerSecond: 10, sentPerSecond: 20)
    for index in 0..<1_000 { history.append(usage, at: start.addingTimeInterval(Double(index) / 10)) }
    XCTAssertEqual(history.points.count, NetworkHistory.capacity)
    history.append(usage, at: start.addingTimeInterval(300))
    XCTAssertEqual(history.points.count, 1)
    history.clear()
    XCTAssertTrue(history.points.isEmpty)
    XCTAssertNil(history.interface)
  }

  func testNetworkHistoryDoesNotBridgeInvalidSamplesInterfaceChangesOrClockChanges() {
    var history = NetworkHistory()
    let start = Date(timeIntervalSince1970: 1_000)
    let usage = NetworkUsage(interface: "en0", receivedPerSecond: 10, sentPerSecond: 20)
    history.append(usage, at: start)
    history.append(usage, at: start.addingTimeInterval(1))
    history.append(NetworkUsage(interface: "en1", receivedPerSecond: 30, sentPerSecond: 40), at: start.addingTimeInterval(2))
    XCTAssertEqual(history.points.count, 1)
    XCTAssertEqual(history.interface, "en1")
    history.append(usage, at: start)
    XCTAssertEqual(history.points.count, 1)
    history.append(nil, at: start.addingTimeInterval(3))
    XCTAssertTrue(history.points.isEmpty)
    history.append(NetworkUsage(interface: "en0", receivedPerSecond: .nan, sentPerSecond: 40), at: start)
    XCTAssertTrue(history.points.isEmpty)
  }

  func testLiveHardwareSensorsReadWithoutPrivilegedHelper() throws {
    guard ProcessInfo.processInfo.environment["AUGMA_TEST_LIVE_METRICS"] == "1" else {
      throw XCTSkip("Enable live desktop hardware reads with AUGMA_TEST_LIVE_METRICS=1")
    }
    let start = ContinuousClock.now
    guard let reading = HardwareSensorReader.read() else { throw XCTSkip("AppleSMC is not accessible on this machine") }
    print("Hardware sensors: CPU \(String(describing: reading.cpuTemperature)) °C from \(reading.cpuSensorCount) points; fans \(String(describing: reading.fans?.map(\.rpm))); read \(start.duration(to: .now))")
    XCTAssertTrue(reading.cpuTemperature != nil || reading.fans != nil)
    if let temperature = reading.cpuTemperature { XCTAssertTrue(SMCReadCodec.validTemperature(temperature)) }
  }
}
