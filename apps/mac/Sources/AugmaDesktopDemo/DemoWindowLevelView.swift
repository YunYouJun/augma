import AppKit
import SwiftUI

/// Applies the SwiftUI preference to the window that owns this view.
struct DemoWindowLevelView: NSViewRepresentable {
  let alwaysOnTop: Bool

  func makeNSView(context: Context) -> WindowLevelView {
    WindowLevelView()
  }

  func updateNSView(_ view: WindowLevelView, context: Context) {
    view.alwaysOnTop = alwaysOnTop
  }
}

final class WindowLevelView: NSView {
  var alwaysOnTop = false {
    didSet { updateWindowLevel() }
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    updateWindowLevel()
  }

  private func updateWindowLevel() {
    window?.level = alwaysOnTop ? .floating : .normal
  }
}
