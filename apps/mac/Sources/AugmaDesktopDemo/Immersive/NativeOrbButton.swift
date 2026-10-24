import SwiftUI

/// Native button semantics with Augma's colored concentric rings.
struct NativeOrbButton: View {
  let title: String
  let symbol: String
  var tint: Color = .augmaCyan
  var selected = false
  var badge = 0
  let identifier: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      NativeOrbLabel(symbol: symbol, tint: tint, selected: selected)
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
    .help(title)
    .accessibilityLabel(title)
    .accessibilityValue(badge > 0 ? String(format: String(localized: "%lld 条未读通知"), badge) : selected ? String(localized: "已选中") : "")
    .accessibilityIdentifier(identifier)
  }
}

struct NativeOrbLabel: View {
  let symbol: String
  let tint: Color
  var selected = false

  var body: some View {
    Image(systemName: symbol)
      .font(.system(size: 19, weight: .medium))
      .foregroundStyle(selected ? Color.white : tint)
      .frame(width: 44, height: 44)
      .background(selected ? tint.opacity(0.9) : tint.opacity(0.14), in: Circle())
      .overlay { Circle().strokeBorder(tint.opacity(selected ? 1 : 0.65), lineWidth: 1.5) }
      .overlay { Circle().inset(by: 4).strokeBorder(tint.opacity(selected ? 0.15 : 0.25), lineWidth: 1) }
      .contentShape(Circle())
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
