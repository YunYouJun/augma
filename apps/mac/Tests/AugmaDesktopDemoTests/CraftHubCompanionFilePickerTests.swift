import AppKit
import UniformTypeIdentifiers
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class CraftHubCompanionFilePickerTests: XCTestCase {
  func testChoosingApplicationReturnsBeforeUserSelectionAndStartsInApplications() {
    let panel = DeferredOpenPanel()
    let picker = CraftHubCompanionFilePicker(makePanel: { panel }, activate: {})
    var selected: URL?
    picker.present(.application) { selected = $0 }

    XCTAssertNil(selected, "The menu action must return while the user is still choosing a file")
    XCTAssertEqual(panel.directoryURL?.path, "/Applications")
    XCTAssertEqual(panel.allowedContentTypes, [.applicationBundle])
    panel.finish(.OK)
    XCTAssertEqual(selected, panel.selectionURL)
  }

  func testRepeatedClicksReuseThePendingWindowAndPreserveTheOriginalSelection() {
    let panel = DeferredOpenPanel()
    var created = 0
    let picker = CraftHubCompanionFilePicker(makePanel: { created += 1; return panel }, activate: {})
    var selected: URL?
    picker.present(.application) { selected = $0 }
    picker.present(.summary) { _ in XCTFail("A second click must not replace the pending request") }

    XCTAssertEqual(created, 1)
    XCTAssertEqual(panel.frontCount, 1)
    panel.finish(.OK)
    XCTAssertEqual(selected, panel.selectionURL)
  }

  func testCancellingKeepsTheSavedConnectionAndAllowsAnotherSelection() {
    let panel = DeferredOpenPanel()
    var created = 0
    let picker = CraftHubCompanionFilePicker(makePanel: { created += 1; return panel }, activate: {})
    let suite = "augma.companion.picker.tests.\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let original = "/tmp/existing-craft-hub-summary.json"
    defaults.set(original, forKey: "craftHub.companion.summaryPath.v1")
    var reads = 0
    let store = CraftHubCompanionStore(defaults: defaults, reader: { _ in
      reads += 1
      throw CompanionError.invalidSummary
    }, filePicker: picker)
    reads = 0

    store.chooseSummary()
    XCTAssertEqual(panel.allowedContentTypes, [.json])
    panel.finish(.cancel)
    XCTAssertEqual(reads, 0)
    XCTAssertEqual(store.summaryPath, original)
    XCTAssertEqual(defaults.string(forKey: "craftHub.companion.summaryPath.v1"), original)
    store.chooseSummary()
    XCTAssertEqual(created, 2)
    panel.finish(.OK)
    XCTAssertEqual(reads, 1)
  }
}

@MainActor
private final class DeferredOpenPanel: NSOpenPanel {
  let selectionURL = URL(fileURLWithPath: "/Applications/Craft Hub.app")
  private(set) var frontCount = 0
  private var completion: ((NSApplication.ModalResponse) -> Void)?

  override var url: URL? { selectionURL }
  override func runModal() -> NSApplication.ModalResponse { .OK }
  override func makeKeyAndOrderFront(_ sender: Any?) { frontCount += 1 }
  override func begin(completionHandler handler: @escaping (NSApplication.ModalResponse) -> Void) {
    completion = handler
  }

  func finish(_ response: NSApplication.ModalResponse) {
    let handler = completion
    completion = nil
    handler?(response)
  }
}
