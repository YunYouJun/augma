import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class NativeUtilityStoreTests: XCTestCase {
  func testNotificationsAreNewestFirstAndBoundedWithoutReplacingIDs() {
    let date = Date(timeIntervalSince1970: 10_000)
    let notices = NativeNotificationStore(capacity: 2, now: { date })
    notices.post(title: "first", detail: "one")
    let firstID = notices.notices[0].id
    notices.post(title: "second", detail: "two", symbol: "viewfinder")
    let secondID = notices.notices[0].id
    XCTAssertEqual(notices.notices.map(\.title), ["second", "first"])
    XCTAssertNotEqual(firstID, secondID)
    XCTAssertEqual(notices.notices[0].date, date)
    XCTAssertEqual(notices.notices[0].symbol, "viewfinder")
    notices.post(title: "third", detail: "three")
    XCTAssertEqual(notices.notices.map(\.title), ["third", "second"])
    XCTAssertEqual(notices.notices.last?.id, secondID)
    XCTAssertEqual(notices.unreadCount, 2)
  }

  func testReadingAndClearingNoticesDoNotAffectLaterActivity() {
    let notices = NativeNotificationStore()
    notices.post(title: "scan", detail: "complete")
    notices.markAllRead()
    XCTAssertEqual(notices.unreadCount, 0)
    XCTAssertEqual(notices.notices.count, 1)
    notices.post(title: "route", detail: "start")
    XCTAssertEqual(notices.unreadCount, 1)
    XCTAssertTrue(notices.notices[1].read)
    notices.clear()
    XCTAssertTrue(notices.notices.isEmpty)
    XCTAssertEqual(notices.unreadCount, 0)
    notices.post(title: "reconnect", detail: "ready")
    XCTAssertEqual(notices.notices.count, 1)
    XCTAssertEqual(notices.unreadCount, 1)
  }

  func testInvalidCapacityKeepsAtLeastTheLatestNotification() {
    let notices = NativeNotificationStore(capacity: -1)
    notices.post(title: "first", detail: "")
    notices.post(title: "last", detail: "")
    XCTAssertEqual(notices.notices.map(\.title), ["last"])
  }

  func testDeviceStartsConnectedWithoutTimersOrNotificationSideEffects() {
    let notices = NativeNotificationStore()
    let device = NativeDeviceStore(notifications: notices, autoTick: false)
    XCTAssertTrue(device.online)
    device.connect()
    device.refreshConnection()
    XCTAssertEqual(device.connection, .connected)
    XCTAssertTrue(notices.notices.isEmpty)
  }

  func testStandbyStopsNativeServicesOnceAndReconnectsOnlyExplicitly() {
    let clock = DeviceTestClock()
    let notices = NativeNotificationStore()
    let device = NativeDeviceStore(notifications: notices, uptime: { clock.time }, autoTick: false)
    var suspensions = 0
    device.onSuspend = { suspensions += 1 }
    device.sleep()
    device.sleep()
    XCTAssertEqual(device.connection, .sleeping)
    XCTAssertFalse(device.online)
    XCTAssertEqual(suspensions, 1)
    XCTAssertEqual(notices.notices.count, 1)
    clock.time += 10
    device.refreshConnection()
    XCTAssertEqual(device.connection, .sleeping)
    device.connect()
    XCTAssertEqual(device.connection, .connecting)
    XCTAssertFalse(device.online)
    clock.time += 0.5
    device.refreshConnection()
    XCTAssertEqual(device.connection, .connecting)
    device.connect()
    clock.time += 0.5
    device.refreshConnection()
    XCTAssertTrue(device.online)
    XCTAssertEqual(suspensions, 1)
    XCTAssertEqual(notices.notices.count, 2)
    device.refreshConnection()
    XCTAssertEqual(notices.notices.count, 2)
  }

  func testCancelledConnectionCannotCompleteOrReuseItsOldDeadline() {
    let clock = DeviceTestClock()
    let notices = NativeNotificationStore()
    let device = NativeDeviceStore(notifications: notices, uptime: { clock.time }, autoTick: false)
    device.disconnect()
    device.connect()
    clock.time += 0.7
    device.sleep()
    clock.time += 5
    device.refreshConnection()
    XCTAssertEqual(device.connection, .sleeping)
    XCTAssertEqual(notices.notices.count, 2)
    device.connect()
    device.refreshConnection()
    XCTAssertEqual(device.connection, .connecting)
    clock.time += 1
    device.refreshConnection()
    XCTAssertEqual(device.connection, .connected)
    XCTAssertEqual(notices.notices.count, 3)
  }

  func testConnectionRejectsNonfiniteClockAndDoesNotFinishAfterClockMovesBack() {
    let clock = DeviceTestClock()
    let device = NativeDeviceStore(notifications: NativeNotificationStore(), uptime: { clock.time }, autoTick: false)
    device.disconnect()
    clock.time = .nan
    device.connect()
    XCTAssertEqual(device.connection, .disconnected)
    clock.time = 1_000
    device.connect()
    for invalid in [Double.infinity, -.infinity, .nan, 999] {
      clock.time = invalid
      device.refreshConnection()
      XCTAssertEqual(device.connection, .connecting)
    }
    clock.time = 1_001
    device.refreshConnection()
    XCTAssertTrue(device.online)
  }

  func testShutdownRejectsPendingAndNewConnectionWork() {
    let clock = DeviceTestClock()
    let notices = NativeNotificationStore()
    let device = NativeDeviceStore(notifications: notices, uptime: { clock.time }, autoTick: false)
    var suspensions = 0
    device.onSuspend = { suspensions += 1 }
    device.disconnect()
    device.connect()
    device.shutdown()
    clock.time += 10
    device.refreshConnection()
    device.connect()
    device.sleep()
    device.disconnect()
    XCTAssertFalse(device.online)
    XCTAssertEqual(notices.notices.count, 1)
    XCTAssertEqual(suspensions, 1)
    XCTAssertNil(device.onSuspend)
  }
}

@MainActor
private final class DeviceTestClock {
  var time: TimeInterval = 1_000
}
