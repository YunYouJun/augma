import AppKit

struct MenuBarShelfWindow: Codable, Equatable, Sendable, Identifiable {
  let id: CGWindowID
  let ownerPID: pid_t
  let title: String
  let frame: CGRect
  let layer: Int
  let isOnScreen: Bool
}

/// Geometry uses Quartz's global, top-left coordinates, including negative display origins.
struct MenuBarShelfDisplay: Codable, Equatable, Sendable {
  let id: CGDirectDisplayID
  let frame: CGRect
  let itemArea: CGRect

  func contains(_ window: MenuBarShelfWindow) -> Bool {
    window.layer == Int(CGWindowLevelForKey(.statusWindow))
      && window.frame.width > 0 && window.frame.width < 600
      && window.frame.height > 0 && window.frame.height <= itemArea.height + 8
      && abs(window.frame.minY - frame.minY) <= 3
      && window.frame.midX >= frame.minX && window.frame.midX < frame.maxX
  }

  func isOccluded(_ window: MenuBarShelfWindow) -> Bool {
    // WindowServer includes a small rim outside the last item's visible content.
    window.frame.minX < itemArea.minX - 4 || window.frame.maxX > itemArea.maxX + 4
  }

  @MainActor static func current() -> MenuBarShelfDisplay? {
    guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }),
          let right = screen.auxiliaryTopRightArea,
          let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
    let id = number.uint32Value
    let bounds = CGDisplayBounds(id)
    return .init(id: id, frame: bounds,
      itemArea: CGRect(x: right.minX, y: bounds.minY, width: right.width, height: screen.safeAreaInsets.top + 1))
  }
}

struct MenuBarShelfItem: Identifiable, Sendable {
  let window: MenuBarShelfWindow
  let applicationPID: pid_t
  let applicationName: String
  let bundleID: String
  let detail: String
  let windowIDs: [CGWindowID]
  let accessibilityID: UInt?
  // Tahoe swaps a status item's window copies between displays when the active menu bar changes.
  var id: CGWindowID { windowIDs.min() ?? window.id }
  var canOpenMenu: Bool { accessibilityID != nil }
  var label: String { detail.isEmpty || detail == applicationName ? applicationName : "\(applicationName) · \(detail)" }

  func activeWindow(on display: MenuBarShelfDisplay, in windows: [MenuBarShelfWindow]) -> MenuBarShelfWindow? {
    let candidates = windows.filter { windowIDs.contains($0.id) && $0.ownerPID == window.ownerPID && display.contains($0) }
    return candidates.first(where: \.isOnScreen) ?? candidates.first
  }

  init(window: MenuBarShelfWindow, applicationPID: pid_t, applicationName: String, bundleID: String,
       detail: String, windowIDs: [CGWindowID] = [], accessibilityID: UInt? = nil) {
    self.window = window
    self.applicationPID = applicationPID
    self.applicationName = applicationName
    self.bundleID = bundleID
    self.detail = detail
    self.windowIDs = Array(Set(windowIDs + [window.id])).sorted()
    self.accessibilityID = accessibilityID
  }
}

enum MenuBarShelfError: LocalizedError {
  case accessibilityRequired, displayUnavailable, itemUnavailable
  case menuStillOpen, busy, eventUnavailable, menuDidNotOpen, actionUnsupported

  var errorDescription: String? {
    switch self {
    case .accessibilityRequired: String(appLocalized: "请先允许 Augma 使用辅助功能，再打开原应用菜单。")
    case .displayUnavailable: String(appLocalized: "请连接并启用内建刘海屏后重试。")
    case .itemUnavailable: String(appLocalized: "这个图标已发生变化，请刷新收纳栏后重试。")
    case .menuStillOpen: String(appLocalized: "请先关闭原应用菜单，再打开其他图标。")
    case .busy: String(appLocalized: "请先完成当前菜单操作。")
    case .menuDidNotOpen: String(appLocalized: "原应用未显示菜单，请稍后重试。")
    case .actionUnsupported: String(appLocalized: "这个应用暂不支持直接打开该菜单。")
    case .eventUnavailable: String(appLocalized: "系统暂时无法操作菜单栏，请稍后重试。")
    }
  }
}
