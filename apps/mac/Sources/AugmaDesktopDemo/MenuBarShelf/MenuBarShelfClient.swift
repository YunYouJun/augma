import AppKit
import ApplicationServices
import ScreenCaptureKit

enum MenuBarShelfSystem {
  struct Application: Sendable {
    let pid: pid_t
    let name: String
    let bundleID: String
  }

  static func windows() -> [MenuBarShelfWindow] {
    let entries = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
    return entries.compactMap { entry in
      guard let id = entry[kCGWindowNumber as String] as? CGWindowID,
            let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
            let bounds = entry[kCGWindowBounds as String] as? NSDictionary,
            let frame = CGRect(dictionaryRepresentation: bounds), !frame.isNull, !frame.isInfinite else { return nil }
      return .init(id: id, ownerPID: pid, title: entry[kCGWindowName as String] as? String ?? "", frame: frame,
        layer: entry[kCGWindowLayer as String] as? Int ?? 0,
        isOnScreen: entry[kCGWindowIsOnscreen as String] as? Bool ?? false)
    }
  }

  static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
  }

  static func element(_ value: CFTypeRef?) -> AXUIElement? {
    guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    return unsafeBitCast(value, to: AXUIElement.self)
  }

  static func frame(_ element: AXUIElement) -> CGRect? {
    guard let position = attribute(element, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
          let size = attribute(element, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
    var origin = CGPoint.zero
    var dimensions = CGSize.zero
    guard AXValueGetValue(unsafeBitCast(position, to: AXValue.self), .cgPoint, &origin),
          AXValueGetValue(unsafeBitCast(size, to: AXValue.self), .cgSize, &dimensions),
          dimensions.width > 0, dimensions.height > 0 else { return nil }
    return CGRect(origin: origin, size: dimensions)
  }

  /// Read the target menu bar. Display layouts can differ, so never infer ownership
  /// or item identity from another display's ordering.
  static func scan(display: MenuBarShelfDisplay, displays: [MenuBarShelfDisplay],
                   applications: [Application]) throws -> [MenuBarShelfItem] {
    guard AXIsProcessTrusted() else { throw MenuBarShelfError.accessibilityRequired }
    guard CGDisplayIsActive(display.id) != 0 else { throw MenuBarShelfError.displayUnavailable }
    var descriptors: [(Application, CGRect, String, UInt)] = []
    for app in applications {
      try Task.checkCancellation()
      let root = AXUIElementCreateApplication(app.pid)
      AXUIElementSetMessagingTimeout(root, 0.15)
      guard let extras = element(attribute(root, kAXExtrasMenuBarAttribute)) else { continue }
      AXUIElementSetMessagingTimeout(extras, 0.15)
      for child in attribute(extras, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
        AXUIElementSetMessagingTimeout(child, 0.15)
        guard let rect = frame(child), rect.width < 600 else { continue }
        let description = attribute(child, kAXDescriptionAttribute) as? String ?? ""
        let title = attribute(child, kAXTitleAttribute) as? String ?? ""
        // Control Center also exposes anonymous placeholders for other apps' hosted items.
        if app.bundleID == "com.apple.controlcenter" && description.isEmpty && title.isEmpty { continue }
        descriptors.append((app, rect, description.isEmpty ? title : description, CFHash(child)))
      }
    }

    // Query AX before the window list: Tahoe may refresh its window copies during an AX query.
    let all = windows()
    let rows = displays.flatMap { screen in all.filter { screen.contains($0) } }
    let target = all.filter { display.contains($0) }.sorted { $0.frame.minX < $1.frame.minX }
    var identified: [CGWindowID: (Application, String)] = [:]
    var accessibilityIDs: [CGWindowID: UInt] = [:]
    for (app, rect, detail, hash) in descriptors {
      let candidates = rows.filter { window in
        abs(window.frame.midX - rect.midX) <= 12 && abs(window.frame.midY - rect.midY) <= 10
          && abs(window.frame.width - rect.width) <= 20
      }
      if let match = candidates.min(by: { abs($0.frame.midX - rect.midX) < abs($1.frame.midX - rect.midX) }) {
        identified[match.id] = (app, detail)
        accessibilityIDs[match.id] = hash
      }
    }
    // A second display's server-rendered copies are named after their owning bundle. Associate
    // copies within each application, by creation order, rather than comparing whole display layouts.
    // Existing per-display item orders can be different. Ambiguous groups stay unassociated.
    var families: [CGWindowID: [CGWindowID]] = [:]
    for app in applications where !app.bundleID.isEmpty && app.bundleID != "com.apple.controlcenter" {
      let originals = all.filter {
        identified[$0.id]?.0.pid == app.pid && $0.title != app.bundleID
      }.sorted { $0.id < $1.id }
      let copies = rows.filter { $0.title == app.bundleID }.sorted { $0.id < $1.id }
      guard !originals.isEmpty, originals.count == copies.count,
            zip(originals, copies).allSatisfy({ abs($0.frame.width - $1.frame.width) <= 20 }),
            originals.count == 1 || zip(originals, copies).allSatisfy({ $1.id == $0.id + 1 }) else { continue }
      for (original, copy) in zip(originals, copies) {
        let family = [original.id, copy.id]
        families[original.id] = family
        families[copy.id] = family
        identified[copy.id] = identified[original.id]
        accessibilityIDs[copy.id] = accessibilityIDs[original.id]
      }
    }
    return target.map { window in
      var identity = identified[window.id]
      if identity == nil, let app = applications.first(where: { !$0.bundleID.isEmpty && $0.bundleID == window.title }) {
        identity = (app, "")
      }
      return MenuBarShelfItem(window: window, applicationPID: identity?.0.pid ?? window.ownerPID,
        applicationName: identity?.0.name ?? String(appLocalized: "菜单栏图标"), bundleID: identity?.0.bundleID ?? "",
        detail: identity?.1 ?? window.title, windowIDs: families[window.id] ?? [], accessibilityID: accessibilityIDs[window.id])
    }
  }

  @MainActor static func displayRows() -> [MenuBarShelfDisplay] {
    NSScreen.screens.compactMap { screen in
      guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
      let bounds = CGDisplayBounds(number.uint32Value)
      return .init(id: number.uint32Value, frame: bounds,
        itemArea: CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width,
                         height: max(screen.safeAreaInsets.top + 1, NSStatusBar.system.thickness + 8)))
    }
  }
}

@MainActor
protocol MenuBarShelfInteracting: AnyObject {
  func items(on display: MenuBarShelfDisplay) async throws -> [MenuBarShelfItem]
  func images(for items: [MenuBarShelfItem]) async -> [CGWindowID: NSImage]
  func openMenu(_ item: MenuBarShelfItem, rightClick: Bool) async throws
  func waitForMenuToClose(_ item: MenuBarShelfItem, on display: MenuBarShelfDisplay) async throws
  func dismissMenu(_ item: MenuBarShelfItem) async throws
}

@MainActor
final class MenuBarShelfClient: MenuBarShelfInteracting {
  var menuContext: MenuBarShelfMenuContext?
  var pressTask: Task<Int32, Never>?

  func items(on display: MenuBarShelfDisplay) async throws -> [MenuBarShelfItem] {
    guard AXIsProcessTrusted() else { throw MenuBarShelfError.accessibilityRequired }
    let apps = NSWorkspace.shared.runningApplications.map {
      MenuBarShelfSystem.Application(pid: $0.processIdentifier, name: $0.localizedName ?? $0.bundleIdentifier ?? "",
                                     bundleID: $0.bundleIdentifier ?? "")
    }
    let displays = MenuBarShelfSystem.displayRows()
    let scan = Task.detached(priority: .userInitiated) {
      try MenuBarShelfSystem.scan(display: display, displays: displays, applications: apps)
    }
    let items = try await withTaskCancellationHandler { try await scan.value } onCancel: { scan.cancel() }
    try Task.checkCancellation()
    return items
  }

  func images(for items: [MenuBarShelfItem]) async -> [CGWindowID: NSImage] {
    guard CGPreflightScreenCaptureAccess(), !items.isEmpty,
          let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false) else { return [:] }
    var result: [CGWindowID: NSImage] = [:]
    for item in items {
      guard !Task.isCancelled, CGPreflightScreenCaptureAccess() else { break }
      guard let window = content.windows.first(where: { $0.windowID == item.window.id }) else { continue }
      let config = SCStreamConfiguration()
      config.width = max(1, Int(ceil(window.frame.width * 2)))
      config.height = max(1, Int(ceil(window.frame.height * 2)))
      config.showsCursor = false
      config.ignoreShadowsSingleWindow = true
      config.captureResolution = .best
      if let image = try? await SCScreenshotManager.captureImage(
        contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: config) {
        result[item.id] = NSImage(cgImage: image, size: window.frame.size)
      }
    }
    return result
  }
}
