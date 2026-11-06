import Foundation

enum MenuBarShelfLayout {
  static let immersiveHeight: CGFloat = 68
  // Drawing space for Liquid Glass's adaptive shadow, outside the shelf's layout bounds.
  static let shadowOutset: CGFloat = 48
  static let compactInset: CGFloat = 6
  static let expandedInset: CGFloat = 8

  static func windowFrame(for shelfFrame: CGRect) -> CGRect {
    shelfFrame.insetBy(dx: -shadowOutset, dy: -shadowOutset)
  }

  static func shelfFrame(in windowFrame: CGRect) -> CGRect {
    windowFrame.insetBy(dx: shadowOutset, dy: shadowOutset)
  }

  /// Use the clock's row when it is hidden and there is room between the corner controls.
  static func immersiveBottomInset(screenWidth: CGFloat, clockVisible: Bool) -> CGFloat {
    clockVisible || screenWidth - 512 < 320 ? 152 : 80
  }

  static func immersiveFrame(in screen: CGRect, clockVisible: Bool = false) -> CGRect {
    let bottomInset = immersiveBottomInset(screenWidth: screen.width, clockVisible: clockVisible)
    let width = min(760, max(0, screen.width - (bottomInset == 80 ? 512 : 40)))
    return CGRect(x: screen.midX - width / 2, y: screen.maxY - bottomInset,
                  width: width, height: immersiveHeight)
  }
}
