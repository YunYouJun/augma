import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class ApplicationManagementShortcutTests: XCTestCase {
  func testHandoffContainsOnlyVersionAndBundleIdentity() throws {
    for scheme in ["craft-hub", "craft-hub-native"] {
      let url = try XCTUnwrap(ApplicationManagementShortcut.navigationURL(bundleID: "com.example.Editor", scheme: scheme))
      let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
      XCTAssertEqual(parts.scheme, scheme)
      XCTAssertEqual(parts.host, "software")
      XCTAssertEqual(parts.queryItems, [URLQueryItem(name: "v", value: "1"), URLQueryItem(name: "bundleId", value: "com.example.Editor")])
      XCTAssertTrue(parts.path.isEmpty)
    }
  }

  func testPathsCommandsAndExtraQueryParametersCannotEnterTheLink() {
    for value in ["", "../Editor.app", "com.example.app&delete=true", "com.example.app\n", "$(command)", "single", String(repeating: "a", count: 256) + ".app"] {
      XCTAssertNil(ApplicationManagementShortcut.navigationURL(bundleID: value, scheme: "craft-hub"), value)
    }
    XCTAssertNil(ApplicationManagementShortcut.navigationURL(bundleID: "com.example.app", scheme: "https"))
  }
}
