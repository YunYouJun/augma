import AppKit
import IOKit.hidsystem
import SwiftUI

/// A menu shortcut alias for WeChat's configured voice input shortcut.
/// WeChat owns recording and inserts the result through the native text system.
/// Posted events have no recording acknowledgement.
@MainActor
final class WeChatVoiceInput {
  static var title: String { String(appLocalized: "微信语音输入") }

  enum Trigger: String, CaseIterable, Identifiable {
    case controlFn, fn, rightControl
    static let storageKey = "augma.wechat-voice-input.trigger"
    static let holdStorageKey = "augma.wechat-voice-input.hold-trigger"
    var id: Self { self }
    var title: String {
      switch self {
      case .controlFn: "Control + Fn"
      case .fn: "Fn"
      case .rightControl: String(appLocalized: "右 Control")
      }
    }
    static var current: Self { Self(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .controlFn }
    static var holdCurrent: Self {
      Self(rawValue: UserDefaults.standard.string(forKey: holdStorageKey) ?? "") ?? .controlFn
    }
    var keyCode: CGKeyCode { self == .rightControl ? 62 : 63 }
    var flags: CGEventFlags {
      switch self {
      case .controlFn: [.maskControl, .maskSecondaryFn, CGEventFlags(rawValue: UInt64(NX_DEVICELCTLKEYMASK))]
      case .fn: .maskSecondaryFn
      case .rightControl: [.maskControl, CGEventFlags(rawValue: UInt64(NX_DEVICERCTLKEYMASK))]
      }
    }
  }

  enum Failure: Error, Equatable {
    case weChatNotRunning, accessibilityRequired, inputUnavailable, composing, keysHeld, eventUnavailable

    var message: String {
      switch self {
      case .weChatNotRunning: String(appLocalized: "请先打开并登录微信，启用语音输入并将控制范围设为所有窗口；Augma 中选择的微信快捷键需与微信设置一致。")
      case .accessibilityRequired: String(appLocalized: "请在系统设置的“隐私与安全性 → 辅助功能”中允许 Augma 控制键盘，然后重试。")
      case .inputUnavailable: String(appLocalized: "请先点击可编辑的输入框，再使用微信语音输入。")
      case .composing: String(appLocalized: "请先确认或取消当前输入法候选文字，再使用微信语音输入。")
      case .keysHeld: String(appLocalized: "请松开快捷键后重试。")
      case .eventUnavailable: String(appLocalized: "无法发送微信语音输入快捷键，请重试。")
      }
    }
  }

  @MainActor struct Environment {
    var isWeChatRunning: @MainActor () -> Bool = {
      NSWorkspace.shared.runningApplications.contains {
        ["com.tencent.xinWeChat", "com.tencent.xinWeChat.devdst"].contains($0.bundleIdentifier ?? "")
      }
    }
    var hasPermission: @MainActor () -> Bool = { CGPreflightPostEventAccess() }
    var isActive: @MainActor () -> Bool = { NSApp.isActive }
    var focusedEditor: @MainActor () -> NSTextView? = {
      guard let editor = NSApp.keyWindow?.firstResponder as? NSTextView, editor.isEditable else { return nil }
      return editor
    }
    var modifiers: @MainActor () -> CGEventFlags = { CGEventSource.flagsState(.combinedSessionState) }
    var wait: @MainActor () async throws -> Void = { try await Task.sleep(for: .milliseconds(20)) }
    var sendShortcut: @MainActor () async throws -> Void = { try await WeChatVoiceInput.postShortcut(trigger: .current) }
    var pressHoldKey: @MainActor () throws -> (@MainActor () -> Void) = {
      try WeChatVoiceInput.pressHeldKey(trigger: .holdCurrent)
    }
  }

  private let environment: Environment
  private var triggering = false
  private var holdGeneration = 0
  private var holdStarting = false
  private var releaseHoldKey: (@MainActor () -> Void)?

  init(environment: Environment = Environment()) { self.environment = environment }

  func beginHold(prepareInput: () -> Void) async throws {
    try Task.checkCancellation()
    guard !holdStarting, releaseHoldKey == nil else { return }
    holdGeneration += 1
    let generation = holdGeneration
    holdStarting = true
    defer { if generation == holdGeneration { holdStarting = false } }
    guard environment.isWeChatRunning() else { throw Failure.weChatNotRunning }
    guard environment.hasPermission() else { throw Failure.accessibilityRequired }
    guard environment.isActive() else { return }
    if environment.focusedEditor() == nil { prepareInput() }
    for _ in 0..<50 {
      try Task.checkCancellation()
      guard generation == holdGeneration, environment.isActive() else { return }
      if environment.focusedEditor() != nil { break }
      try await environment.wait()
    }
    try Task.checkCancellation()
    guard generation == holdGeneration, environment.isActive() else { return }
    guard let editor = environment.focusedEditor() else { throw Failure.inputUnavailable }
    guard !editor.hasMarkedText() else { throw Failure.composing }
    releaseHoldKey = try environment.pressHoldKey()
  }

  func endHold() {
    holdGeneration += 1
    holdStarting = false
    let release = releaseHoldKey
    releaseHoldKey = nil
    release?()
  }

  static func pressHeldKey(
    trigger: Trigger,
    post: @escaping @MainActor (CGEvent) -> Void = { $0.post(tap: .cghidEventTap) }
  ) throws -> @MainActor () -> Void {
    if trigger == .controlFn {
      // WeChat's continuous-input shortcut toggles recording. Pair its start
      // and stop in order, including a key-up arriving during the first pulse.
      let start = Task { try await postShortcut(trigger: .controlFn, post: post) }
      return {
        Task {
          guard (try? await start.value) != nil else { return }
          try? await postShortcut(trigger: .controlFn, post: post)
        }
      }
    }
    guard let source = CGEventSource(stateID: .privateState),
          let down = CGEvent(keyboardEventSource: source, virtualKey: trigger.keyCode, keyDown: true),
          let up = CGEvent(keyboardEventSource: source, virtualKey: trigger.keyCode, keyDown: false)
    else { throw Failure.eventUnavailable }
    down.type = .flagsChanged
    down.flags = trigger.flags
    up.type = .flagsChanged
    up.flags = []
    post(down)
    return { withExtendedLifetime(source) { post(up) } }
  }

  func start(prepareInput: () -> Void) async throws {
    // Holding a menu shortcut must not enqueue multiple toggles of WeChat's recorder.
    guard !triggering else { return }
    triggering = true
    defer { triggering = false }
    guard environment.isWeChatRunning() else { throw Failure.weChatNotRunning }
    guard environment.hasPermission() else { throw Failure.accessibilityRequired }
    guard environment.isActive() else { return }

    if environment.focusedEditor() == nil { prepareInput() }
    for _ in 0..<50 {
      try Task.checkCancellation()
      guard environment.isActive() else { return }
      if environment.focusedEditor() != nil { break }
      try await environment.wait()
    }
    guard environment.isActive() else { return }
    guard let editor = environment.focusedEditor() else { throw Failure.inputUnavailable }
    guard !editor.hasMarkedText() else { throw Failure.composing }

    // Do not merge the original shortcut's Command/Option flags into WeChat's shortcut.
    let keyboardModifiers: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand, .maskShift, .maskSecondaryFn]
    for _ in 0..<100 {
      try Task.checkCancellation()
      guard environment.isActive(), environment.focusedEditor() === editor else { return }
      if environment.modifiers().intersection(keyboardModifiers).isEmpty { break }
      try await environment.wait()
    }
    try Task.checkCancellation()
    guard environment.isActive(), environment.focusedEditor() === editor else { return }
    guard environment.modifiers().intersection(keyboardModifiers).isEmpty else { throw Failure.keysHeld }
    guard !editor.hasMarkedText() else { throw Failure.composing }
    try await environment.sendShortcut()
  }

  static func postShortcut(
    trigger: Trigger = .fn,
    post: @MainActor (CGEvent) -> Void = { $0.post(tap: .cghidEventTap) },
    wait: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
  ) async throws {
    guard let source = CGEventSource(stateID: .privateState) else { throw Failure.eventUnavailable }
    func event(key: CGKeyCode, down: Bool, flags: CGEventFlags) throws -> CGEvent {
      guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else {
        throw Failure.eventUnavailable
      }
      event.type = .flagsChanged
      event.flags = flags
      return event
    }
    let prefix: CGEventFlags = trigger == .controlFn
      ? [.maskControl, CGEventFlags(rawValue: UInt64(NX_DEVICELCTLKEYMASK))] : []
    var press = [try event(key: trigger.keyCode, down: true, flags: trigger.flags)]
    var release = [try event(key: trigger.keyCode, down: false, flags: prefix)]
    if trigger == .controlFn {
      press.insert(try event(key: 59, down: true, flags: prefix), at: 0)
      release.append(try event(key: 59, down: false, flags: []))
    }

    for event in press { post(event) }
    // Release every synthesized modifier even when the task is cancelled.
    defer { for event in release { post(event) } }
    try await wait(trigger == .controlFn ? .milliseconds(150) : .milliseconds(500))
  }
}
