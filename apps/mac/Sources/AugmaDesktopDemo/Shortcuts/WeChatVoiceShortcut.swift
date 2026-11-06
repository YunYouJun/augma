import AppKit
import SwiftUI

/// A native menu shortcut stored independently from WeChat's own input key.
struct WeChatVoiceShortcut: RawRepresentable, Equatable, Sendable {
  static let storageKey = "augma.wechat-voice-input.shortcut"
  static let defaultValue = WeChatVoiceShortcut(key: "v", modifiers: [.control, .option, .command])
  static var current: Self {
    Self(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .defaultValue
  }
  let key: Character
  let modifierBits: UInt
  private static let modifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]

  init(key: Character, modifiers: NSEvent.ModifierFlags) {
    self.key = key
    modifierBits = modifiers.intersection(Self.modifiers).rawValue
  }

  init?(rawValue: String) {
    let parts = rawValue.split(separator: ":")
    guard parts.count == 2, let bits = UInt(parts[0]), let value = UInt32(parts[1]),
          let scalar = UnicodeScalar(value),
          !NSEvent.ModifierFlags(rawValue: bits).intersection([.command, .control, .option]).isEmpty
    else { return nil }
    self.init(key: Character(String(scalar)), modifiers: NSEvent.ModifierFlags(rawValue: bits))
  }

  init?(event: NSEvent) {
    guard event.type == .keyDown, !event.isARepeat,
          let characters = event.charactersIgnoringModifiers, characters.unicodeScalars.count == 1,
          let key = characters.lowercased().first,
          !event.modifierFlags.intersection([.command, .control, .option]).isEmpty
    else { return nil }
    self.init(key: key, modifiers: event.modifierFlags)
  }

  var rawValue: String { "\(modifierBits):\(key.unicodeScalars.first!.value)" }
  var keyboardShortcut: KeyboardShortcut {
    let flags = NSEvent.ModifierFlags(rawValue: modifierBits)
    var modifiers: EventModifiers = []
    if flags.contains(.command) { modifiers.insert(.command) }
    if flags.contains(.control) { modifiers.insert(.control) }
    if flags.contains(.option) { modifiers.insert(.option) }
    if flags.contains(.shift) { modifiers.insert(.shift) }
    return KeyboardShortcut(KeyEquivalent(key), modifiers: modifiers)
  }
  var label: String {
    let flags = NSEvent.ModifierFlags(rawValue: modifierBits)
    let prefix = [(NSEvent.ModifierFlags.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
      .filter { flags.contains($0.0) }.map(\.1).joined()
    let named: [UInt32: String] = [32: "Space", 13: "↩", 9: "⇥", 27: "⎋", 127: "⌫",
      UInt32(NSLeftArrowFunctionKey): "←", UInt32(NSRightArrowFunctionKey): "→",
      UInt32(NSUpArrowFunctionKey): "↑", UInt32(NSDownArrowFunctionKey): "↓"]
    let value = key.unicodeScalars.first!.value
    let name = named[value] ?? ((UInt32(NSF1FunctionKey)...UInt32(NSF24FunctionKey)).contains(value)
      ? "F\(value - UInt32(NSF1FunctionKey) + 1)" : String(key).uppercased())
    return prefix + name
  }
}

/// AppKit captures a chord only while this button is the key window's first responder.
struct WeChatVoiceShortcutRecorder: NSViewRepresentable {
  @Binding var shortcut: WeChatVoiceShortcut

  func makeNSView(context: Context) -> RecorderButton {
    let button = RecorderButton()
    button.bezelStyle = .rounded
    button.setButtonType(.momentaryPushIn)
    button.target = button
    button.action = #selector(RecorderButton.toggleRecording)
    button.setAccessibilityIdentifier("wechat-voice-shortcut-recorder")
    return button
  }

  func updateNSView(_ button: RecorderButton, context: Context) {
    button.label = shortcut.label
    button.onRecord = { shortcut = $0 }
    button.refreshTitle()
    button.setAccessibilityLabel(String(appLocalized: "录制语音输入快捷键"))
  }

  final class RecorderButton: NSButton {
    var label = ""
    var onRecord: ((WeChatVoiceShortcut) -> Void)?
    private var recording = false
    override var acceptsFirstResponder: Bool { true }

    @objc func toggleRecording() {
      recording.toggle()
      if recording { window?.makeFirstResponder(self) }
      refreshTitle()
    }

    func refreshTitle() {
      title = recording ? String(appLocalized: "按下快捷键，Esc 取消") : label
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
      guard recording, window?.isKeyWindow == true, window?.firstResponder === self else {
        return super.performKeyEquivalent(with: event)
      }
      capture(event)
      return true
    }

    override func keyDown(with event: NSEvent) {
      if recording { capture(event) }
      else { super.keyDown(with: event) }
    }

    private func capture(_ event: NSEvent) {
      if event.keyCode == 53 { recording = false; refreshTitle(); return }
      guard let shortcut = WeChatVoiceShortcut(event: event) else {
        title = String(appLocalized: "请包含 ⌘、⌥ 或 ⌃")
        return
      }
      recording = false
      label = shortcut.label
      refreshTitle()
      onRecord?(shortcut)
    }

    override func resignFirstResponder() -> Bool {
      recording = false
      refreshTitle()
      return super.resignFirstResponder()
    }
  }
}
