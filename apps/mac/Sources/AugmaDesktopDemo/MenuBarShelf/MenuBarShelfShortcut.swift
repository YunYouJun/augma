import Carbon

/// A registered accelerator (⌃⌥B), with no keyboard event tap or background key logging.
@MainActor
final class MenuBarShelfShortcut {
  private var key: EventHotKeyRef?
  private var handler: EventHandlerRef?
  private var action: (() -> Void)?
  private var pressed = false

  func register(action: @escaping () -> Void) -> Bool {
    unregister()
    var types = [kEventHotKeyPressed, kEventHotKeyReleased].map {
      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32($0))
    }
    let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
      guard let event, let context else { return OSStatus(eventNotHandledErr) }
      var identifier = EventHotKeyID()
      guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
        MemoryLayout<EventHotKeyID>.size, nil, &identifier) == noErr,
        identifier.signature == 0x41554753, identifier.id == 1 else { return OSStatus(eventNotHandledErr) }
      MainActor.assumeIsolated {
        let shortcut = Unmanaged<MenuBarShelfShortcut>.fromOpaque(context).takeUnretainedValue()
        if GetEventKind(event) == UInt32(kEventHotKeyPressed) {
          if !shortcut.pressed { shortcut.pressed = true; shortcut.action?() }
        } else { shortcut.pressed = false }
      }
      return noErr
    }, types.count, &types, Unmanaged.passUnretained(self).toOpaque(), &handler)
    guard status == noErr else { unregister(); return false }
    let result = RegisterEventHotKey(UInt32(kVK_ANSI_B), UInt32(controlKey | optionKey),
      EventHotKeyID(signature: 0x41554753, id: 1), GetApplicationEventTarget(), 0, &key)
    guard result == noErr else { unregister(); return false }
    self.action = action
    return true
  }

  func unregister() {
    if let key { UnregisterEventHotKey(key) }
    if let handler { RemoveEventHandler(handler) }
    key = nil
    handler = nil
    action = nil
    pressed = false
  }
}
