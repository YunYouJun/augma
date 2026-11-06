import Foundation

/// Shrink the icons and their spacing together so the entire Dock stays visible.
struct NativeDockMetrics {
  let scale: CGFloat
  var iconSize: CGFloat { 44 * scale }
  var spacing: CGFloat { 10 * scale }
  var horizontalPadding: CGFloat { 16 * scale }
  var verticalPadding: CGFloat { 8 * scale }

  init(itemCount: Int, availableWidth: CGFloat) {
    scale = min(1, max(0, availableWidth) / Self.preferredWidth(itemCount: itemCount))
  }

  static func preferredWidth(itemCount: Int) -> CGFloat {
    guard itemCount > 0 else { return 160 }
    return CGFloat(itemCount) * 44 + CGFloat(itemCount - 1) * 10 + 32
  }
}
