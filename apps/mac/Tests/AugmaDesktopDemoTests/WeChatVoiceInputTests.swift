import AppKit
import IOKit.hidsystem
import SwiftUI
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class WeChatVoiceInputTests: XCTestCase {
  func testMissingWeChatOrPermissionDoesNotChangeFocusOrSendKeys() async {
    for failure in [WeChatVoiceInput.Failure.weChatNotRunning, .accessibilityRequired] {
      var environment = WeChatVoiceInput.Environment()
      environment.isWeChatRunning = { failure != .weChatNotRunning }
      environment.hasPermission = { failure != .accessibilityRequired }
      environment.sendShortcut = { XCTFail("Must not send keys before prerequisites pass") }
      do {
        try await WeChatVoiceInput(environment: environment).start { XCTFail("Must preserve focus") }
        XCTFail("Expected a prerequisite error")
      } catch { XCTAssertEqual(error as? WeChatVoiceInput.Failure, failure) }
    }
  }

  func testPreparesAnInputAndWaitsForTheOriginalShortcutToBeReleased() async throws {
    let editor = NSTextView()
    var focused: NSTextView?
    var held = true
    var preparations = 0
    var sent = 0
    var environment = readyEnvironment(editor: editor)
    environment.focusedEditor = { focused }
    environment.modifiers = { held ? [.maskControl, .maskAlternate, .maskCommand] : [] }
    environment.wait = { held = false }
    environment.sendShortcut = {
      XCTAssertTrue(focused === editor)
      XCTAssertFalse(held)
      sent += 1
    }
    try await WeChatVoiceInput(environment: environment).start {
      preparations += 1
      focused = editor
    }
    XCTAssertEqual(preparations, 1)
    XCTAssertEqual(sent, 1)
  }

  func testChangingFocusWhileReleasingTheShortcutDoesNotDictateIntoAnotherField() async throws {
    let original = NSTextView()
    let other = NSTextView()
    var focused = original
    var environment = readyEnvironment(editor: original)
    environment.focusedEditor = { focused }
    environment.modifiers = { .maskCommand }
    environment.wait = { focused = other }
    environment.sendShortcut = { XCTFail("Focus changed before dictation started") }
    try await WeChatVoiceInput(environment: environment).start { XCTFail("Already focused") }
  }

  func testMarkedTextIsPreservedWithoutTriggeringWeChat() async {
    let editor = NSTextView()
    editor.setMarkedText("ni hao", selectedRange: NSRange(location: 6, length: 0),
                         replacementRange: NSRange(location: NSNotFound, length: 0))
    var environment = readyEnvironment(editor: editor)
    environment.sendShortcut = { XCTFail("Must not interrupt the input method") }
    do {
      try await WeChatVoiceInput(environment: environment).start {}
      XCTFail("Expected an input-method error")
    } catch { XCTAssertEqual(error as? WeChatVoiceInput.Failure, .composing) }
    XCTAssertTrue(editor.hasMarkedText())
  }

  func testCancellationReleasesTheConfiguredWeChatKey() async {
    for trigger in WeChatVoiceInput.Trigger.allCases {
      var events: [(CGKeyCode, CGEventFlags)] = []
      do {
        try await WeChatVoiceInput.postShortcut(trigger: trigger, post: {
          XCTAssertEqual($0.type, .flagsChanged)
          events.append((CGKeyCode($0.getIntegerValueField(.keyboardEventKeycode)), $0.flags))
        }, wait: { _ in
          throw CancellationError()
        })
        XCTFail("Expected cancellation")
      } catch { XCTAssertTrue(error is CancellationError) }
      XCTAssertEqual(events.map(\.0), trigger == .controlFn ? [59, 63, 63, 59] : [trigger.keyCode, trigger.keyCode])
      XCTAssertEqual(events.last?.1, [])
    }
  }

  func testRightControlIsSentWithoutAddingLeftControlOrFn() async throws {
    var events: [(CGKeyCode, CGEventFlags)] = []
    try await WeChatVoiceInput.postShortcut(trigger: .rightControl, post: {
      events.append((CGKeyCode($0.getIntegerValueField(.keyboardEventKeycode)), $0.flags))
    }, wait: { _ in })
    XCTAssertEqual(events.map(\.0), [62, 62])
    let pressed = try XCTUnwrap(events.first?.1)
    XCTAssertEqual(pressed.rawValue & UInt64(NX_DEVICELCTLKEYMASK), 0)
    XCTAssertNotEqual(pressed.rawValue & UInt64(NX_DEVICERCTLKEYMASK), 0)
    XCTAssertTrue(events.allSatisfy { !$0.1.contains(.maskSecondaryFn) })
    XCTAssertEqual(events.last?.1, [])
  }

  func testConfiguredControlFnTogglePressesAndReleasesBothKeys() async throws {
    var events: [(CGKeyCode, CGEventFlags)] = []
    try await WeChatVoiceInput.postShortcut(trigger: .controlFn, post: {
      events.append((CGKeyCode($0.getIntegerValueField(.keyboardEventKeycode)), $0.flags))
    }, wait: { _ in })
    XCTAssertEqual(events.map(\.0), [59, 63, 63, 59])
    XCTAssertTrue(events[0].1.contains(.maskControl))
    XCTAssertTrue(events[1].1.contains([.maskControl, .maskSecondaryFn]))
    XCTAssertEqual(events.last?.1, [])
  }

  func testRecordingAndReloadingACustomShortcutPreservesItsKeyAndModifiers() throws {
    let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command, .option, .shift],
      timestamp: 0, windowNumber: 0, context: nil, characters: "J", charactersIgnoringModifiers: "J", isARepeat: false, keyCode: 38))
    let recorded = try XCTUnwrap(WeChatVoiceShortcut(event: event))
    XCTAssertEqual(recorded.label, "⌥⇧⌘J")
    XCTAssertEqual(WeChatVoiceShortcut(rawValue: recorded.rawValue), recorded)
    XCTAssertEqual(recorded.keyboardShortcut.key, KeyEquivalent("j"))
    XCTAssertEqual(recorded.keyboardShortcut.modifiers, [.option, .shift, .command])
  }

  func testRecorderRejectsPlainTypingAndInvalidSavedShortcuts() throws {
    let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .shift,
      timestamp: 0, windowNumber: 0, context: nil, characters: "J", charactersIgnoringModifiers: "J", isARepeat: false, keyCode: 38))
    XCTAssertNil(WeChatVoiceShortcut(event: event))
    XCTAssertNil(WeChatVoiceShortcut(rawValue: "0:106"))
    XCTAssertNil(WeChatVoiceShortcut(rawValue: "invalid"))
    XCTAssertEqual(WeChatVoiceShortcut.defaultValue.label, "⌃⌥⌘V")
  }

  func testHoldKeepsWeChatKeyDownUntilReleaseEvenWhileOriginalModifiersAreHeld() async throws {
    let editor = NSTextView()
    var presses = 0
    var releases = 0
    var environment = readyEnvironment(editor: editor)
    environment.modifiers = { [.maskCommand, .maskAlternate, .maskControl] }
    environment.pressHoldKey = { presses += 1; return { releases += 1 } }
    let input = WeChatVoiceInput(environment: environment)
    try await input.beginHold { XCTFail("The existing input must stay focused") }
    XCTAssertEqual(presses, 1)
    XCTAssertEqual(releases, 0, "Recording must continue after key-down handling returns")
    input.endHold()
    input.endHold()
    XCTAssertEqual(releases, 1, "Key-up must release the synthesized key exactly once")
  }

  func testReleaseBeforeInputIsReadyDoesNotStartLateRecording() async throws {
    let editor = NSTextView()
    var environment = readyEnvironment(editor: editor)
    environment.focusedEditor = { nil }
    environment.pressHoldKey = { XCTFail("The shortcut was released before focus was ready"); return {} }
    var input: WeChatVoiceInput!
    environment.wait = { input.endHold() }
    input = WeChatVoiceInput(environment: environment)
    try await input.beginHold {}
  }

  func testHeldFnHasNoAutomaticReleaseTimerOrControlModifier() throws {
    var events: [(CGKeyCode, CGEventFlags)] = []
    let release = try WeChatVoiceInput.pressHeldKey(trigger: .fn, post: {
      events.append((CGKeyCode($0.getIntegerValueField(.keyboardEventKeycode)), $0.flags))
    })
    XCTAssertEqual(events.count, 1)
    XCTAssertEqual(events.first?.0, 63)
    XCTAssertEqual(events.first?.1, .maskSecondaryFn)
    release()
    XCTAssertEqual(events.count, 2)
    XCTAssertEqual(events.last?.1, [])
  }

  func testControlFnHoldSerializesStartAndStopEvenForAQuickRelease() async throws {
    var keys: [CGKeyCode] = []
    let release = try WeChatVoiceInput.pressHeldKey(trigger: .controlFn, post: {
      keys.append(CGKeyCode($0.getIntegerValueField(.keyboardEventKeycode)))
    })
    release()
    try await Task.sleep(for: .milliseconds(500))
    XCTAssertEqual(keys, [59, 63, 63, 59, 59, 63, 63, 59])
  }

  func testHoldShortcutRoutesKeyUpAfterModifiersHaveBeenReleasedAndIgnoresRepeats() throws {
    _ = NSApplication.shared
    let monitor = WeChatVoiceShortcutMonitor()
    var presses = 0
    var releases = 0
    monitor.start(onPress: { presses += 1 }, onRelease: { releases += 1 })
    defer { monitor.stop() }
    let down = try shortcutEvent(.keyDown, modifiers: [.control, .option, .command])
    let repeatDown = try shortcutEvent(.keyDown, modifiers: [.control, .option, .command], repeating: true)
    let up = try shortcutEvent(.keyUp, modifiers: [])
    XCTAssertTrue(monitor.handle(down, shortcut: .defaultValue))
    XCTAssertTrue(monitor.handle(repeatDown, shortcut: .defaultValue))
    XCTAssertEqual(presses, 1)
    XCTAssertEqual(releases, 0)
    XCTAssertTrue(monitor.handle(up, shortcut: .defaultValue))
    XCTAssertEqual(releases, 1)
  }

  func testFocusLossOrShutdownReleasesAHeldShortcutOnce() throws {
    _ = NSApplication.shared
    let monitor = WeChatVoiceShortcutMonitor()
    var releases = 0
    monitor.start(onPress: {}, onRelease: { releases += 1 })
    XCTAssertTrue(monitor.handle(try shortcutEvent(.keyDown, modifiers: [.control, .option, .command]), shortcut: .defaultValue))
    monitor.release()
    monitor.stop()
    XCTAssertEqual(releases, 1)
  }

  private func shortcutEvent(_ type: NSEvent.EventType, modifiers: NSEvent.ModifierFlags, repeating: Bool = false) throws -> NSEvent {
    try XCTUnwrap(NSEvent.keyEvent(with: type, location: .zero, modifierFlags: modifiers, timestamp: 0,
      windowNumber: 0, context: nil, characters: "v", charactersIgnoringModifiers: "v", isARepeat: repeating, keyCode: 9))
  }

  private func readyEnvironment(editor: NSTextView) -> WeChatVoiceInput.Environment {
    var environment = WeChatVoiceInput.Environment()
    environment.isWeChatRunning = { true }
    environment.hasPermission = { true }
    environment.isActive = { true }
    environment.focusedEditor = { editor }
    environment.modifiers = { [] }
    environment.wait = {}
    return environment
  }
}
