import AppKit
import SwiftUI

/// The menu item that starts or finishes a voice command, and the key the page shows for it.
///
/// Users rebind it under System Settings → Keyboard → Keyboard Shortcuts → App Shortcuts by its menu title,
/// so the page reads the key from the menu item instead of assuming the default.
enum VoiceShortcut {
  /// The menu item title, which App Shortcuts matches.
  static var title: String { String(localized: "开始或结束语音指令") }

  // ⌥⌘V: ⇧⌘V is the Paste and Pastebot clipboard managers' default global hotkey, which takes the key before
  // Augma sees it, while ⌥⌘V is only Finder's Move Item Here and a menu key fires only while Augma is frontmost.
  // ⌘ stays the base modifier: fn/Globe is reserved by the system and missing on many external keyboards, and
  // ⌃⌥ is VoiceOver's.
  static let defaultKey: KeyEquivalent = "v"
  static let defaultModifiers: EventModifiers = [.command, .option]
  static let defaultChord = "Alt+Meta+v"

  /// - Returns: The menu item's key as a page chord, `nil` when it has no key, or the default before the menu exists
  @MainActor
  static func currentChord() -> String? {
    guard let item = NSApp.mainMenu.flatMap({ menuItem(titled: title, in: $0) }) else { return defaultChord }
    return chord(keyEquivalent: item.keyEquivalent, modifiers: item.keyEquivalentModifierMask)
  }

  private static func menuItem(titled title: String, in menu: NSMenu) -> NSMenuItem? {
    for item in menu.items {
      if item.title == title { return item }
      if let submenu = item.submenu, let found = menuItem(titled: title, in: submenu) { return found }
    }
    return nil
  }

  private static let namedKeys: [UInt32: String] = [
    0x20: "Space", 0x0D: "Enter", 0x03: "Enter", 0x09: "Tab", 0x1B: "Escape", 0x08: "Backspace", 0x7F: "Backspace",
    UInt32(NSDeleteFunctionKey): "Delete", UInt32(NSHomeFunctionKey): "Home", UInt32(NSEndFunctionKey): "End",
    UInt32(NSPageUpFunctionKey): "PageUp", UInt32(NSPageDownFunctionKey): "PageDown",
    UInt32(NSUpArrowFunctionKey): "ArrowUp", UInt32(NSDownArrowFunctionKey): "ArrowDown",
    UInt32(NSLeftArrowFunctionKey): "ArrowLeft", UInt32(NSRightArrowFunctionKey): "ArrowRight",
  ]

  /// Convert an AppKit key equivalent to the page's canonical chord, modifiers in the order Ctrl, Alt, Shift, Meta.
  ///
  /// - Returns: The chord, or `nil` when there is no key or the page has no name for it
  static func chord(keyEquivalent: String, modifiers: NSEvent.ModifierFlags) -> String? {
    let scalars = keyEquivalent.unicodeScalars
    guard scalars.count == 1, let scalar = scalars.first else { return nil }
    var shift = modifiers.contains(.shift)
    let key: String
    switch scalar.value {
    case 0x41...0x5A:
      // An uppercase key equivalent implies Shift.
      shift = true
      key = keyEquivalent.lowercased()
    case 0x21...0x7E:
      key = keyEquivalent
    case UInt32(NSF1FunctionKey)...UInt32(NSF24FunctionKey):
      key = "F\(scalar.value - UInt32(NSF1FunctionKey) + 1)"
    default:
      guard let name = namedKeys[scalar.value] else { return nil }
      key = name
    }
    return [
      modifiers.contains(.control) ? "Ctrl" : nil,
      modifiers.contains(.option) ? "Alt" : nil,
      shift ? "Shift" : nil,
      modifiers.contains(.command) ? "Meta" : nil,
      key,
    ].compactMap { $0 }.joined(separator: "+")
  }
}
