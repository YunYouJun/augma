import Foundation

/// Shared geometry keeps the browser and spatial canvas clear of the HUD controls.
enum ImmersiveLayout {
  enum Chrome: CaseIterable, Hashable { case voice, clock, system, dock }

  static func content(in size: CGSize) -> CGRect {
    CGRect(x: 20, y: 88, width: max(200, size.width - 40), height: max(150, size.height - 200))
  }

  /// Screen coordinates, using the visible frame so the system menu bar and Dock remain available.
  static func frame(for chrome: Chrome, in screen: CGRect) -> CGRect {
    switch chrome {
    case .voice:
      return CGRect(x: screen.minX + 20, y: screen.maxY - 76, width: 60, height: 60)
    case .clock:
      let width = max(80, min(200, screen.width - 512))
      return CGRect(x: screen.midX - width / 2, y: screen.maxY - 76, width: width, height: 60)
    case .system:
      return CGRect(x: screen.maxX - 244, y: screen.maxY - 76, width: 224, height: 60)
    case .dock:
      return CGRect(x: screen.midX - min(620, screen.width - 40) / 2, y: screen.minY + 12,
             width: min(620, screen.width - 40), height: 88)
    }
  }
}
