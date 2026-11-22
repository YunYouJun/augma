import AugmaUI
import SwiftUI

typealias NativeOrbLabel = AugmaOrbLabel

/// Native button semantics with Augma's colored concentric rings.
struct NativeOrbButton: View {
  let title: String
  let symbol: String
  var tint: Color = .augmaCyan
  var selected = false
  var badge = 0
  var dockTooltip = false
  var applicationIcon: NSImage? = nil
  var diameter: CGFloat = 44
  let identifier: String
  let action: () -> Void

  @ViewBuilder
  var body: some View {
    if dockTooltip {
      button.modifier(DockTooltip(title: title))
    } else {
      button.help(title)
    }
  }

  private var button: some View {
    Button(action: action) {
      NativeOrbLabel(symbol: symbol, tint: tint, selected: selected, diameter: diameter)
        .overlay {
          if let applicationIcon {
            Image(nsImage: applicationIcon).resizable().scaledToFit()
              .frame(width: diameter * 38 / 44, height: diameter * 38 / 44)
              .background(.background, in: Circle()).accessibilityHidden(true)
          }
        }
        .overlay(alignment: .topTrailing) {
          if badge > 0 {
            Text(badge > 99 ? "99+" : String(badge))
              .font(.system(size: 10, weight: .bold, design: .rounded))
              .foregroundStyle(.white)
              .padding(.horizontal, 4).frame(minWidth: 16, minHeight: 16)
              .background(Color.augmaHighlight, in: Capsule())
              .offset(x: 3, y: -2)
              .accessibilityHidden(true)
          }
        }
    }
    .buttonStyle(NativeOrbButtonStyle())
    .accessibilityLabel(title)
    .accessibilityValue(badge > 0 ? String(format: String(appLocalized: "%lld 条未读通知"), badge) : selected ? String(appLocalized: "已选中") : "")
    .accessibilityIdentifier(identifier)
  }
}

private struct NativeOrbButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var enabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(enabled ? (configuration.isPressed ? 0.65 : 1) : 0.35)
      .scaleEffect(configuration.isPressed ? 0.94 : 1)
  }
}
