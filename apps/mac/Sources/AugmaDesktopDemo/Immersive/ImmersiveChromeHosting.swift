import AppKit
import SwiftUI

@MainActor
enum ImmersiveChromeHosting {
  static func view<Content: View>(_ content: Content, for chrome: ImmersiveLayout.Chrome) -> NSView {
    NSHostingView(rootView: content
      .padding(chrome == .dock ? ImmersiveLayout.dockShadowInset : 0)
      .appLocalized(windowTitle: chrome.windowTitleKey))
  }
}
