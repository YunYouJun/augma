import AppKit
import XCTest
@testable import AugmaDesktopDemo

final class VoiceShortcutTests: XCTestCase {
  func testDefaultIsOptionCommandV() {
    XCTAssertEqual(VoiceShortcut.chord(keyEquivalent: "v", modifiers: [.command, .option]), VoiceShortcut.defaultChord)
    XCTAssertEqual(VoiceShortcut.defaultChord, "Alt+Meta+v")
  }

  func testOrdersModifiersLikeThePage() {
    XCTAssertEqual(VoiceShortcut.chord(keyEquivalent: "k", modifiers: [.command, .shift, .option, .control]), "Ctrl+Alt+Shift+Meta+k")
  }

  func testUppercaseKeyEquivalentMeansShift() {
    XCTAssertEqual(VoiceShortcut.chord(keyEquivalent: "V", modifiers: [.command]), "Shift+Meta+v")
  }

  func testKeepsSymbolsAndNamesSpecialKeys() {
    XCTAssertEqual(VoiceShortcut.chord(keyEquivalent: "/", modifiers: [.command, .shift]), "Shift+Meta+/")
    XCTAssertEqual(VoiceShortcut.chord(keyEquivalent: " ", modifiers: [.control, .option]), "Ctrl+Alt+Space")
    XCTAssertEqual(VoiceShortcut.chord(keyEquivalent: String(UnicodeScalar(NSF5FunctionKey)!), modifiers: [.command]), "Meta+F5")
    XCTAssertEqual(VoiceShortcut.chord(keyEquivalent: String(UnicodeScalar(NSUpArrowFunctionKey)!), modifiers: [.command, .option]), "Alt+Meta+ArrowUp")
  }

  func testNoKeyOrAnUnnamedKeyHasNoChord() {
    XCTAssertNil(VoiceShortcut.chord(keyEquivalent: "", modifiers: [.command]))
    // App Shortcuts set to "\0" disable a menu key, which AppKit reports as a NUL key equivalent.
    XCTAssertNil(VoiceShortcut.chord(keyEquivalent: "\0", modifiers: []))
    XCTAssertNil(VoiceShortcut.chord(keyEquivalent: "é", modifiers: [.command]))
  }
}
