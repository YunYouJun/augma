import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class CaptureDestinationOpenerTests: XCTestCase {
  func testInstalledToDoOpensNativelyWithoutOpeningABrowser() async throws {
    let app = URL(filePath: "/Applications/Microsoft To Do.app")
    var opened: [URL] = []
    let opener = CaptureDestinationOpener(applicationURL: { bundleID in
      XCTAssertEqual(bundleID, "com.microsoft.to-do-mac")
      return app
    }, openApplication: { opened.append($0) }, openWebsite: { _ in
      XCTFail("An installed app must open natively")
      return false
    })
    let result = try await opener.open(.microsoftToDo)
    XCTAssertEqual(result, .application)
    XCTAssertEqual(opened, [app])
  }

  func testMissingOrFailedNativeToDoFallsBackToTheWebsite() async throws {
    for installed in [false, true] {
      var websites: [URL] = []
      let opener = CaptureDestinationOpener(applicationURL: { _ in installed ? URL(filePath: "/Applications/Microsoft To Do.app") : nil },
        openApplication: { _ in throw URLError(.fileDoesNotExist) }, openWebsite: { websites.append($0); return true })
      let result = try await opener.open(.microsoftToDo)
      XCTAssertEqual(result, .website)
      XCTAssertEqual(websites.map(\.absoluteString), ["https://to-do.office.com/tasks/"])
    }
  }

  func testFailedFallbackAndMissingNotesReportAnError() async {
    let opener = CaptureDestinationOpener(applicationURL: { _ in nil }, openWebsite: { _ in false })
    for destination in CaptureDestination.allCases {
      do {
        _ = try await opener.open(destination)
        XCTFail("Failure must be visible")
      } catch {
        XCTAssertTrue(error is CaptureError)
      }
    }
  }
}
