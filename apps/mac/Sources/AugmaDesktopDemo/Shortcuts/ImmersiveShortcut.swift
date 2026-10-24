import Carbon
import Combine
import Foundation

enum ImmersiveShortcut: String, CaseIterable, Identifiable {
  case controlOptionA, controlOptionCommandSpace, disabled
  var id: String { rawValue }
  var title: String {
    switch self {
    case .controlOptionA: "⌃⌥A"
    case .controlOptionCommandSpace: "⌃⌥⌘Space"
    case .disabled: String(localized: "关闭")
    }
  }
  var keyCode: UInt32 { UInt32(self == .controlOptionA ? kVK_ANSI_A : kVK_Space) }
  var modifiers: UInt32 { UInt32(controlKey | optionKey | (self == .controlOptionCommandSpace ? cmdKey : 0)) }
}

@MainActor
protocol GlobalHotKeyRegistering: AnyObject {
  func register(_ shortcut: ImmersiveShortcut, action: @escaping @MainActor () -> Void) -> OSStatus
  func unregister()
}

/// Carbon registers one accelerator; it does not install a keyboard event tap or read typed text.
@MainActor
final class CarbonGlobalHotKey: GlobalHotKeyRegistering {
  private var hotKey: EventHotKeyRef?
  private var handler: EventHandlerRef?
  private var action: (@MainActor () -> Void)?
  private var keyIsDown = false
  private static let identifier = EventHotKeyID(signature: 0x4155474D, id: 1) // AUGM

  func register(_ shortcut: ImmersiveShortcut, action: @escaping @MainActor () -> Void) -> OSStatus {
    unregister()
    guard shortcut != .disabled else { return noErr }
    var types = [kEventHotKeyPressed, kEventHotKeyReleased].map {
      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32($0))
    }
    let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
      guard let event, let userData else { return OSStatus(eventNotHandledErr) }
      var id = EventHotKeyID()
      let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                     nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
      guard result == noErr, id.signature == 0x4155474D, id.id == 1 else { return OSStatus(eventNotHandledErr) }
      MainActor.assumeIsolated {
        let registration = Unmanaged<CarbonGlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
        if GetEventKind(event) == UInt32(kEventHotKeyPressed) {
          guard !registration.keyIsDown else { return }
          registration.keyIsDown = true
          registration.action?()
        } else { registration.keyIsDown = false }
      }
      return noErr
    }, types.count, &types, Unmanaged.passUnretained(self).toOpaque(), &handler)
    guard status == noErr else { return status }
    let registered = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, Self.identifier,
                                        GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &hotKey)
    guard registered == noErr else { unregister(); return registered }
    self.action = action
    return noErr
  }

  func unregister() {
    if let hotKey { UnregisterEventHotKey(hotKey) }
    if let handler { RemoveEventHandler(handler) }
    hotKey = nil
    handler = nil
    action = nil
    keyIsDown = false
  }
}

@MainActor
final class ImmersiveShortcutStore: ObservableObject {
  static let storageKey = "augma.immersiveShortcut"
  @Published var shortcut: ImmersiveShortcut {
    didSet {
      defaults.set(shortcut.rawValue, forKey: Self.storageKey)
      if action != nil { refresh() }
    }
  }
  @Published private(set) var registrationError: OSStatus?
  private let defaults: UserDefaults
  private let registration: GlobalHotKeyRegistering
  private var action: (@MainActor () -> Void)?

  init(defaults: UserDefaults = .standard, registration: GlobalHotKeyRegistering? = nil) {
    self.defaults = defaults
    self.registration = registration ?? CarbonGlobalHotKey()
    shortcut = defaults.string(forKey: Self.storageKey).flatMap(ImmersiveShortcut.init(rawValue:)) ?? .controlOptionA
  }

  func start(action: @escaping @MainActor () -> Void) {
    self.action = action
    refresh()
  }

  func refresh() {
    registration.unregister()
    registrationError = nil
    guard let action, shortcut != .disabled else { return }
    let result = registration.register(shortcut, action: action)
    if result != noErr { registrationError = result }
  }

  func stop() {
    registration.unregister()
    action = nil
    registrationError = nil
  }
}
