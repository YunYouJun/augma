import AppKit
@_exported import AugmaUI
import SwiftUI

/// Borderless panels cache their shadow from the first frame; recompute it once the
/// materialize entrance has finished so the shadow follows the final shape.
@MainActor
func refreshShadowAfterEntrance(of window: NSWindow, delay: Duration = .milliseconds(800)) {
  Task { @MainActor [weak window] in
    try? await Task.sleep(for: delay)
    window?.invalidateShadow()
  }
}
