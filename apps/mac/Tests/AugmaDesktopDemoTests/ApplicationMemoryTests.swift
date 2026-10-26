import XCTest
@testable import AugmaDesktopDemo

final class ApplicationMemoryTests: XCTestCase {
  private let browser = ApplicationMemoryIdentity(processIdentifier: 10, name: "Browser", bundlePath: "/Applications/Browser.app")
  private let terminal = ApplicationMemoryIdentity(processIdentifier: 20, name: "Terminal", bundlePath: "/Applications/Terminal.app")

  private func process(_ pid: Int32, parent: Int32 = 1, path: String? = nil, bytes: UInt64? = 100,
                       startedAt: UInt64 = 10) -> ApplicationMemoryProcess {
    ApplicationMemoryProcess(pid: pid, parentPID: parent, startedAt: startedAt,
                             executablePath: path, physicalFootprint: bytes)
  }

  func testNestedAndReparentedHelpersJoinTheirOutermostApplication() throws {
    let snapshot = ApplicationMemoryAggregation.aggregate(applications: [browser], processes: [
      process(10, path: "/Applications/Browser.app/Contents/MacOS/Browser", bytes: 300),
      process(11, parent: 10, path: "/Applications/Browser.app/Contents/Frameworks/Helper.app/Contents/MacOS/Helper", bytes: 500),
      process(12, path: "/Applications/Browser.app/Contents/XPCServices/Network.xpc/Contents/MacOS/Network", bytes: 200),
    ])
    let row = try XCTUnwrap(snapshot.applications.first)
    XCTAssertEqual(snapshot.applications.count, 1)
    XCTAssertEqual(row.id, browser.bundlePath)
    XCTAssertEqual(row.physicalFootprint, 1_000)
    XCTAssertEqual(row.processCount, 3)
  }

  func testExternalSidecarAndGrandchildrenFollowTheirLiveAppAncestor() throws {
    let snapshot = ApplicationMemoryAggregation.aggregate(applications: [browser], processes: [
      process(10, path: browser.bundlePath + "/Contents/MacOS/Browser"),
      process(11, parent: 10, path: "/opt/homebrew/bin/node", bytes: 200),
      process(12, parent: 11, path: "/usr/bin/git", bytes: 300),
    ])
    XCTAssertEqual(snapshot.applications.first?.physicalFootprint, 600)
    XCTAssertEqual(snapshot.applications.first?.processCount, 3)
  }

  func testIndependentAppIsNotChargedToItsLauncherAndToolPathsDoNotOverrideAncestry() {
    let snapshot = ApplicationMemoryAggregation.aggregate(applications: [browser, terminal], processes: [
      process(20, path: terminal.bundlePath + "/Contents/MacOS/Terminal", bytes: 100),
      process(10, parent: 20, path: browser.bundlePath + "/Contents/MacOS/Browser", bytes: 200),
      process(30, parent: 20, path: browser.bundlePath + "/Contents/Tools/tool", bytes: 400),
    ])
    XCTAssertEqual(snapshot.applications.map(\.application.name), ["Terminal", "Browser"])
    XCTAssertEqual(snapshot.applications.map(\.physicalFootprint), [500, 200])
  }

  func testSharedServicesAndUnrelatedAppsAreNotGuessedFromTheirNames() {
    let snapshot = ApplicationMemoryAggregation.aggregate(applications: [browser], processes: [
      process(10, path: browser.bundlePath + "/Contents/MacOS/Browser"),
      process(11, path: "/System/Library/Frameworks/WebKit.framework/XPCServices/WebContent.xpc/Contents/MacOS/WebContent", bytes: 9_000),
      process(12, path: "/Applications/Browser Beta.app/Contents/MacOS/Browser", bytes: 8_000),
      process(13, path: "/Applications/Browser.app.bak/Contents/MacOS/Browser", bytes: 7_000),
    ])
    XCTAssertEqual(snapshot.applications.first?.physicalFootprint, 100)
    XCTAssertEqual(snapshot.applications.first?.processCount, 1)
  }

  func testUnreadableParentsKeepTheirChildrenAndAreReportedAsPartial() throws {
    let snapshot = ApplicationMemoryAggregation.aggregate(applications: [browser], processes: [
      process(10, path: browser.bundlePath + "/Contents/MacOS/Browser", bytes: nil),
      process(11, parent: 10, path: "/opt/homebrew/bin/node", bytes: 250),
    ])
    let row = try XCTUnwrap(snapshot.applications.first)
    XCTAssertEqual(row.physicalFootprint, 250)
    XCTAssertEqual(row.processCount, 2)
    XCTAssertEqual(row.measuredProcessCount, 1)
    XCTAssertEqual(row.unreadableProcessCount, 1)
  }

  func testReusedParentPIDAndCyclesDoNotAssociateUnrelatedProcesses() {
    let snapshot = ApplicationMemoryAggregation.aggregate(applications: [browser], processes: [
      process(10, path: browser.bundlePath + "/Contents/MacOS/Browser", startedAt: 20),
      process(11, parent: 10, path: "/opt/homebrew/bin/node", bytes: 9_000, startedAt: 10),
      process(12, parent: 13, bytes: 8_000),
      process(13, parent: 12, bytes: 7_000),
    ])
    XCTAssertEqual(snapshot.applications.first?.physicalFootprint, 100)
    XCTAssertEqual(snapshot.applications.first?.processCount, 1)
  }

  func testDuplicatePIDsAndMultipleInstancesOfSameAppAreCountedOncePerProcess() {
    var secondInstance = browser
    secondInstance.processIdentifier = 14
    let first = process(10, path: browser.bundlePath + "/Contents/MacOS/Browser")
    let snapshot = ApplicationMemoryAggregation.aggregate(applications: [browser, secondInstance], processes: [
      first, first, process(14, path: browser.bundlePath + "/Contents/MacOS/Browser", bytes: 200),
    ])
    XCTAssertEqual(snapshot.applications.count, 1)
    XCTAssertEqual(snapshot.applications.first?.physicalFootprint, 300)
    XCTAssertEqual(snapshot.applications.first?.processCount, 2)
  }

  func testDescendingRankingTopThreeStableTiesAndUnavailableRows() {
    let apps = (1...5).map { ApplicationMemoryIdentity(processIdentifier: Int32($0), name: "App", bundlePath: "/Apps/\($0).app") }
    let records = apps.enumerated().map { index, app in
      process(app.processIdentifier, path: app.bundlePath + "/Contents/MacOS/App", bytes: index == 4 ? nil : UInt64(index / 2 + 1) * 100)
    }
    let snapshot = ApplicationMemoryAggregation.aggregate(applications: apps, processes: records)
    XCTAssertEqual(snapshot.applications.map(\.id), ["/Apps/3.app", "/Apps/4.app", "/Apps/1.app", "/Apps/2.app", "/Apps/5.app"])
    XCTAssertEqual(snapshot.topApplications.count, 3)
    XCTAssertEqual(snapshot.topApplications.map(\.physicalFootprint), [200, 200, 100])
    XCTAssertEqual(snapshot.applications.last?.measuredProcessCount, 0)
  }

  func testOverflowIsPartialAndEmptySnapshotClearsPreviousRanking() {
    let snapshot = ApplicationMemoryAggregation.aggregate(applications: [browser], processes: [
      process(10, path: browser.bundlePath + "/Contents/MacOS/Browser", bytes: .max),
      process(11, parent: 10, bytes: 1),
    ])
    XCTAssertEqual(snapshot.applications.first?.physicalFootprint, .max)
    XCTAssertEqual(snapshot.applications.first?.unreadableProcessCount, 1)
    XCTAssertTrue(ApplicationMemoryAggregation.aggregate(applications: [browser], processes: []).applications.isEmpty)
  }

  func testLiveReaderReportsApplicationsWithoutElevatedPrivileges() async throws {
    guard ProcessInfo.processInfo.environment["AUGMA_TEST_LIVE_METRICS"] == "1" else {
      throw XCTSkip("Opt in to sampling the current desktop with AUGMA_TEST_LIVE_METRICS=1")
    }
    let start = ContinuousClock.now
    let sampled = await ApplicationMemoryReader.sample()
    let snapshot = try XCTUnwrap(sampled)
    XCTAssertFalse(snapshot.applications.isEmpty)
    XCTAssertTrue(snapshot.applications.allSatisfy { $0.processCount > 0 })
    XCTAssertTrue(snapshot.applications.contains { $0.measuredProcessCount > 0 && $0.physicalFootprint > 0 })
    print("Application memory: \(snapshot.applications.count) apps, \(snapshot.applications.reduce(0) { $0 + $1.processCount }) processes, \(start.duration(to: .now))")
    for row in snapshot.topApplications {
      print("Top app: \(row.application.name), \(row.physicalFootprint) bytes, \(row.processCount) processes, \(row.unreadableProcessCount) unreadable")
    }
  }
}
