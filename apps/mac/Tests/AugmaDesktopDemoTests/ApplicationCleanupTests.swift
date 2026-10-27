import XCTest
@testable import AugmaDesktopDemo

final class ApplicationCleanupTests: XCTestCase {
  func testQuitIdentityRejectsPIDReuseDifferentBundlesAndTheHostApp() {
    let date = Date(timeIntervalSince1970: 1_000)
    let identity = ApplicationMemoryIdentity(processIdentifier: 42, name: "App", bundlePath: "/Applications/App.app", launchedAt: date)
    XCTAssertTrue(ApplicationCleanup.matches(identity, pid: 42, bundlePath: identity.bundlePath, launchedAt: date, ownPID: 1))
    XCTAssertFalse(ApplicationCleanup.matches(identity, pid: 43, bundlePath: identity.bundlePath, launchedAt: date, ownPID: 1))
    XCTAssertFalse(ApplicationCleanup.matches(identity, pid: 42, bundlePath: identity.bundlePath, launchedAt: date.addingTimeInterval(1), ownPID: 1))
    XCTAssertFalse(ApplicationCleanup.matches(identity, pid: 42, bundlePath: "/Applications/Other.app", launchedAt: date, ownPID: 1))
    XCTAssertFalse(ApplicationCleanup.matches(identity, pid: 42, bundlePath: identity.bundlePath, launchedAt: date, ownPID: 42))
  }

  func testUnknownLaunchDateNeverAuthorizesQuittingAnApplication() {
    let identity = ApplicationMemoryIdentity(processIdentifier: 42, name: "App", bundlePath: "/Applications/App.app")
    XCTAssertFalse(ApplicationCleanup.matches(identity, pid: 42, bundlePath: identity.bundlePath, launchedAt: nil, ownPID: 1))
    XCTAssertFalse(ApplicationCleanup.matches(identity, pid: 42, bundlePath: identity.bundlePath, launchedAt: .now, ownPID: 1))
  }
}
