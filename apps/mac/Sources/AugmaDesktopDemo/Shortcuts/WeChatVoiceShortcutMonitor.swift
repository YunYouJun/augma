import AppKit

/// Only observes Augma's own events. A matched key-up releases the forwarded
/// WeChat key even if the user has already released the chord's modifiers.
@MainActor
final class WeChatVoiceShortcutMonitor {
  private var monitor: Any?
  private var resignObserver: NSObjectProtocol?
  private var pressedKey: UInt16?
  private var onPress: () -> Void = {}
  private var onRelease: () -> Void = {}

  func start(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) {
    stop()
    self.onPress = onPress
    self.onRelease = onRelease
    monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
      let handled = MainActor.assumeIsolated {
        guard let self else { return false }
        if event.type == .keyUp { return self.handle(event, shortcut: .current) }
        if NSApp.keyWindow?.firstResponder is WeChatVoiceShortcutRecorder.RecorderButton { return false }
        return self.handle(event, shortcut: .current)
      }
      return handled ? nil : event
    }
    resignObserver = NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification,
      object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.release() }
      }
  }

  @discardableResult
  func handle(_ event: NSEvent, shortcut: WeChatVoiceShortcut) -> Bool {
    if event.type == .keyUp, event.keyCode == pressedKey { release(); return true }
    guard event.type == .keyDown else { return false }
    if event.keyCode == pressedKey { return true }
    if event.keyCode == 53 { release(); return false }
    guard !event.isARepeat, WeChatVoiceShortcut(event: event) == shortcut else { return false }
    pressedKey = event.keyCode
    onPress()
    return true
  }

  func release() {
    guard pressedKey != nil else { return }
    pressedKey = nil
    onRelease()
  }

  func stop() {
    release()
    if let monitor { NSEvent.removeMonitor(monitor) }
    if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
    monitor = nil
    resignObserver = nil
  }

  isolated deinit {
    if let monitor { NSEvent.removeMonitor(monitor) }
    if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
  }
}
