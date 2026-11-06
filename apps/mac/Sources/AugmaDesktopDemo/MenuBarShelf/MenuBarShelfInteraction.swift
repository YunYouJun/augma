import AppKit
import ApplicationServices

struct MenuBarShelfMenuContext {
  let itemID: CGWindowID
  let applicationPID: pid_t
  let rendererPID: pid_t
  let baseline: Set<CGWindowID>

  func interfaces(in windows: [MenuBarShelfWindow]) -> [MenuBarShelfWindow] {
    windows.filter {
      $0.isOnScreen && !baseline.contains($0.id)
        && ($0.ownerPID == applicationPID || $0.ownerPID == rendererPID)
        && $0.layer >= Int(CGWindowLevelForKey(.floatingWindow))
        && $0.layer != Int(CGWindowLevelForKey(.statusWindow))
        && $0.frame.width > 8 && $0.frame.height > 8
    }
  }
}

extension MenuBarShelfClient {
  func openMenu(_ item: MenuBarShelfItem, rightClick: Bool) async throws {
    guard AXIsProcessTrusted() else { throw MenuBarShelfError.accessibilityRequired }
    let windows = MenuBarShelfSystem.windows()
    guard let display = MenuBarShelfDisplay.current(),
          let window = item.activeWindow(on: display, in: windows),
          let hash = item.accessibilityID else { throw MenuBarShelfError.itemUnavailable }
    menuContext = MenuBarShelfMenuContext(itemID: item.id, applicationPID: item.applicationPID,
      rendererPID: window.ownerPID, baseline: Set(windows.filter(\.isOnScreen).map(\.id)))
    // A foreign NSMenu stays owned and rendered by its original application. AX actions can
    // address its status item even behind the notch, without moving the item or the pointer.
    pressTask = Task.detached(priority: .userInitiated) {
      guard !Task.isCancelled else { return AXError.cannotComplete.rawValue }
      let root = AXUIElementCreateApplication(item.applicationPID)
      AXUIElementSetMessagingTimeout(root, 0.4)
      guard let bar = MenuBarShelfSystem.element(MenuBarShelfSystem.attribute(root, kAXExtrasMenuBarAttribute)),
            let children = MenuBarShelfSystem.attribute(bar, kAXChildrenAttribute) as? [AXUIElement],
            let element = children.first(where: { CFHash($0) == hash }), !Task.isCancelled else {
        return AXError.invalidUIElement.rawValue
      }
      AXUIElementSetMessagingTimeout(element, 0.4)
      var queue: [(AXUIElement, Int)] = [(element, 0)]
      var candidates: [(AXUIElement, [String])] = []
      while !queue.isEmpty, candidates.count < 32 {
        guard !Task.isCancelled else { return AXError.cannotComplete.rawValue }
        let (node, depth) = queue.removeFirst()
        AXUIElementSetMessagingTimeout(node, 0.4)
        let role = MenuBarShelfSystem.attribute(node, kAXRoleAttribute) as? String ?? ""
        // Descendant menu commands are never candidates for opening the status item.
        // In particular, an unsupported status button must not fall through to Quit or another command.
        if depth > 0 && [kAXMenuRole, kAXMenuItemRole, kAXMenuBarItemRole].contains(role) { continue }
        var names: CFArray?
        _ = AXUIElementCopyActionNames(node, &names)
        candidates.append((node, names as? [String] ?? []))
        if depth < 3 {
          queue += (MenuBarShelfSystem.attribute(node, kAXChildrenAttribute) as? [AXUIElement] ?? [])
            .prefix(32).map { ($0, depth + 1) }
        }
      }
      let preferred = rightClick ? [kAXShowMenuAction] : [kAXPressAction, kAXShowMenuAction]
      for action in preferred {
        for (node, actions) in candidates where actions.contains(action) {
          guard !Task.isCancelled else { return AXError.cannotComplete.rawValue }
          let result = AXUIElementPerformAction(node, action as CFString)
          if result != .actionUnsupported && result != .notImplemented { return result.rawValue }
        }
      }
      return AXError.actionUnsupported.rawValue
    }
  }

  func waitForMenuToClose(_ item: MenuBarShelfItem, on display: MenuBarShelfDisplay) async throws {
    guard let context = menuContext, context.itemID == item.id else { return }
    var observed = false
    var absentSamples = 0
    let openingDeadline = ContinuousClock.now + .seconds(1.5)
    while true {
      try Task.checkCancellation()
      let visible = !context.interfaces(in: MenuBarShelfSystem.windows()).isEmpty
      if visible { observed = true; absentSamples = 0 }
      else { absentSamples += 1 }
      // Submenu clicks and keyboard navigation keep their interface window on screen.
      // Keep the shelf operation active until the actual native menu closes.
      if observed && absentSamples >= 3 {
        _ = await pressTask?.value
        pressTask = nil
        menuContext = nil
        return
      }
      if !observed && ContinuousClock.now >= openingDeadline {
        let result = await pressTask?.value
        pressTask = nil
        if result == AXError.actionUnsupported.rawValue { throw MenuBarShelfError.actionUnsupported }
        if result == AXError.invalidUIElement.rawValue { throw MenuBarShelfError.itemUnavailable }
        // AX success (or a modal timeout) is not evidence that a dropdown actually appeared.
        throw MenuBarShelfError.menuDidNotOpen
      }
      try await Task.sleep(for: .milliseconds(100))
    }
  }

  func dismissMenu(_ item: MenuBarShelfItem) async throws {
    guard let context = menuContext, context.itemID == item.id else { return }
    pressTask?.cancel()
    _ = await pressTask?.value
    pressTask = nil
    let interfaces = context.interfaces(in: MenuBarShelfSystem.windows())
    if !interfaces.isEmpty {
      // Send Escape only to the processes that own this operation's interface, never the foreground app.
      for pid in Set(interfaces.map(\.ownerPID)) { MenuBarShelfEvents.escape(pid: pid) }
      for _ in 0..<10 {
        try await Task.sleep(for: .milliseconds(70))
        if context.interfaces(in: MenuBarShelfSystem.windows()).isEmpty { menuContext = nil; return }
      }
      throw MenuBarShelfError.menuStillOpen
    }
    menuContext = nil
  }
}

/// Cancellation is addressed only to the process that owns this operation's visible menu.
@MainActor
enum MenuBarShelfEvents {
  static func escape(pid: pid_t) {
    guard let source = CGEventSource(stateID: .privateState) else { return }
    for down in [true, false] {
      let event = CGEvent(keyboardEventSource: source, virtualKey: 53, keyDown: down)
      event?.flags = []
      event?.postToPid(pid)
    }
  }
}
