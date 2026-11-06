import AppKit

@MainActor
final class MenuBarShelfSession {
  static let legacyRecoveryKey = "augma.menu-bar-shelf.return-point"
  private let client: any MenuBarShelfInteracting
  private(set) var isBusy = false

  init(client: any MenuBarShelfInteracting, defaults: UserDefaults = .standard) {
    self.client = client
    // Direct menu actions no longer move status items. Retire the old position journal
    // without letting a failed restoration block opening an application's menu.
    defaults.removeObject(forKey: Self.legacyRecoveryKey)
  }

  func open(_ selection: MenuBarShelfItem, on display: MenuBarShelfDisplay, rightClick: Bool = false) async throws {
    guard !isBusy else { throw MenuBarShelfError.busy }
    isBusy = true
    defer { isBusy = false }
    try Task.checkCancellation()
    let items = try await client.items(on: display)
    guard let item = items.first(where: { $0.id == selection.id }), item.canOpenMenu,
          item.applicationPID == selection.applicationPID,
          item.bundleID == selection.bundleID,
          item.accessibilityID == selection.accessibilityID else {
      throw MenuBarShelfError.itemUnavailable
    }
    try Task.checkCancellation()
    do {
      try await client.openMenu(item, rightClick: rightClick)
      try await client.waitForMenuToClose(item, on: display)
    } catch {
      // Cancellation closes only this operation's menu; there is no position to restore.
      try? await Task { @MainActor in try await self.client.dismissMenu(item) }.value
      throw error
    }
  }
}
