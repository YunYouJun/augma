import Carbon
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class ImmersiveShortcutTests: XCTestCase {
  func testDoesNotRegisterUntilStartedAndInvokesTheCurrentAction() {
    withStore { store, registration, _ in
      XCTAssertTrue(registration.requests.isEmpty)
      var count = 0
      store.start { count += 1 }
      XCTAssertEqual(registration.requests, [.controlOptionA])
      registration.action?()
      XCTAssertEqual(count, 1)
      store.start { count += 10 }
      registration.action?()
      XCTAssertEqual(count, 11)
    }
  }

  func testChangingShortcutReleasesOldBindingAndPersistsTheNewChoice() {
    withStore { store, registration, defaults in
      store.start {}
      store.shortcut = .controlOptionCommandSpace
      XCTAssertEqual(registration.active, .controlOptionCommandSpace)
      XCTAssertEqual(defaults.string(forKey: ImmersiveShortcutStore.storageKey), "controlOptionCommandSpace")
      let restored = ImmersiveShortcutStore(defaults: defaults, registration: FakeHotKey())
      XCTAssertEqual(restored.shortcut, .controlOptionCommandSpace)
      store.shortcut = .disabled
      XCTAssertNil(registration.active)
      XCTAssertNil(registration.action)
      XCTAssertNil(store.registrationError)
    }
  }

  func testCollisionIsVisibleAndRetryCanRecoverWithoutSilentlyUsingOldShortcut() {
    withStore { store, registration, _ in
      store.start {}
      registration.nextStatus = OSStatus(eventHotKeyExistsErr)
      store.shortcut = .controlOptionCommandSpace
      XCTAssertEqual(store.registrationError, OSStatus(eventHotKeyExistsErr))
      XCTAssertNil(registration.active)
      registration.nextStatus = noErr
      store.refresh()
      XCTAssertNil(store.registrationError)
      XCTAssertEqual(registration.active, .controlOptionCommandSpace)
    }
  }

  func testStoppingPreventsReRegistrationUntilStartedAgain() {
    withStore { store, registration, _ in
      store.start {}
      store.stop()
      XCTAssertNil(registration.action)
      let count = registration.requests.count
      store.shortcut = .controlOptionCommandSpace
      XCTAssertEqual(registration.requests.count, count)
      store.start {}
      XCTAssertEqual(registration.active, .controlOptionCommandSpace)
    }
  }

  private func withStore(_ body: (ImmersiveShortcutStore, FakeHotKey, UserDefaults) -> Void) {
    let suite = "augma-shortcut-tests-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    let registration = FakeHotKey()
    let store = ImmersiveShortcutStore(defaults: defaults, registration: registration)
    defer { store.stop(); defaults.removePersistentDomain(forName: suite) }
    body(store, registration, defaults)
  }
}

@MainActor
private final class FakeHotKey: GlobalHotKeyRegistering {
  var requests: [ImmersiveShortcut] = []
  var active: ImmersiveShortcut?
  var action: (@MainActor () -> Void)?
  var nextStatus: OSStatus = noErr
  func register(_ shortcut: ImmersiveShortcut, action: @escaping @MainActor () -> Void) -> OSStatus {
    XCTAssertNil(active, "A new registration must release the previous shortcut")
    requests.append(shortcut)
    if nextStatus == noErr { active = shortcut; self.action = action }
    return nextStatus
  }
  func unregister() { active = nil; action = nil }
}
