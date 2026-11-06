import Foundation

/// Shared geometry keeps the browser and spatial canvas clear of the HUD controls.
enum ImmersiveLayout {
  static let topInset: CGFloat = 16
  // The corner controls inset their glass surface by one point inside the panel.
  static let defaultDockBottomInset: CGFloat = topInset + 1
  static let dockHeight: CGFloat = 88
  static let dockShadowInset: CGFloat = 48

  enum Chrome: CaseIterable, Hashable {
    case voice, clock, system, dock

    var windowTitleKey: String {
      switch self {
      case .voice: "Augma 沉浸语音"
      case .clock: "Augma 沉浸时钟"
      case .system: "Augma 沉浸控制"
      case .dock: "Augma 沉浸 Dock"
      }
    }
  }

  static func content(in size: CGSize, menuBarShelfVisible: Bool = false, clockVisible: Bool = false,
                      dockBottomInset: CGFloat = defaultDockBottomInset) -> CGRect {
    let top: CGFloat = menuBarShelfVisible
      ? MenuBarShelfLayout.immersiveBottomInset(screenWidth: size.width, clockVisible: clockVisible) + 16 : 88
    let bottom = dockBottomInset + dockHeight + 12
    return CGRect(x: 20, y: top, width: max(200, size.width - 40), height: max(0, size.height - top - bottom))
  }

  /// Screen coordinates, using the visible frame so the system menu bar and Dock remain available.
  static func frame(for chrome: Chrome, in screen: CGRect, dockItemCount: Int = 12,
                    dockBottomInset: CGFloat = defaultDockBottomInset) -> CGRect {
    switch chrome {
    case .voice:
      return CGRect(x: screen.minX + 20, y: screen.maxY - topInset - 60, width: 60, height: 60)
    case .clock:
      let width = max(80, min(200, screen.width - 512))
      return CGRect(x: screen.midX - width / 2, y: screen.maxY - topInset - 60, width: width, height: 60)
    case .system:
      return CGRect(x: screen.maxX - 244, y: screen.maxY - topInset - 60, width: 224, height: 60)
    case .dock:
      let width = min(NativeDockMetrics.preferredWidth(itemCount: dockItemCount), screen.width - 40)
      return CGRect(x: screen.midX - width / 2, y: screen.minY + dockBottomInset, width: width, height: dockHeight)
    }
  }

  /// Liquid Glass draws its adaptive shadow on every side, outside the layout bounds.
  static func windowFrame(for chrome: Chrome, in screen: CGRect, dockItemCount: Int = 12,
                          dockBottomInset: CGFloat = defaultDockBottomInset) -> CGRect {
    let frame = frame(for: chrome, in: screen, dockItemCount: dockItemCount, dockBottomInset: dockBottomInset)
    guard chrome == .dock else { return frame }
    return frame.insetBy(dx: -dockShadowInset, dy: -dockShadowInset)
  }
}
