import AppKit
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class NativeCommandInputRoutingTests: XCTestCase {
  func testCandidateNavigationDoesNotMoveCommandSelectionDuringMarkedText() {
    _ = NSApplication.shared
    let editor = NSTextView()
    editor.setMarkedText("ni hao", selectedRange: NSRange(location: 6, length: 0),
                         replacementRange: NSRange(location: NSNotFound, length: 0))
    XCTAssertTrue(editor.hasMarkedText())
    var selectionMoves = 0
    let handled = NativeCommandInputRouting.navigate(editor: editor) { selectionMoves += 1 }
    XCTAssertFalse(handled, "The arrow must continue to the system input method")
    XCTAssertEqual(selectionMoves, 0)
    editor.unmarkText()
    XCTAssertFalse(editor.hasMarkedText())
    XCTAssertTrue(NativeCommandInputRouting.navigate(editor: editor) { selectionMoves += 1 })
    XCTAssertEqual(selectionMoves, 1, "Committed text restores command navigation")
    XCTAssertTrue(NativeCommandInputRouting.navigate(editor: nil) { selectionMoves += 1 })
    XCTAssertEqual(selectionMoves, 2)
  }
}
