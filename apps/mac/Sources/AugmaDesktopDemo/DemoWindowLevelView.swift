import AppKit
import SwiftUI

/// Applies the SwiftUI preference to the window that owns this view.
struct DemoWindowLevelView: NSViewRepresentable {
  let alwaysOnTop: Bool
  var onWindow: ((NSWindow?) -> Void)?

  func makeNSView(context: Context) -> WindowLevelView {
    WindowLevelView()
  }

  func updateNSView(_ view: WindowLevelView, context: Context) {
    view.onWindow = onWindow
    onWindow?(view.window)
    view.alwaysOnTop = alwaysOnTop
  }
}

final class WindowLevelView: NSView {
  var onWindow: ((NSWindow?) -> Void)?
  var alwaysOnTop = false {
    didSet { updateWindowLevel() }
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    onWindow?(window)
    updateWindowLevel()
  }

  private func updateWindowLevel() {
    window?.level = alwaysOnTop ? .floating : .normal
  }
}
