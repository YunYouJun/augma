import SwiftUI

public extension View {
  /// Applies Augma's circular orb background and concentric rings outside a control (such as a
  /// macOS borderless `Menu`, whose `label:` can otherwise flatten custom background/overlay shapes).
  func augmaOrbChrome(tint: Color = .augmaCyan, selected: Bool = false, diameter: CGFloat = 44) -> some View {
    let scale = diameter / 44
    return frame(width: diameter, height: diameter)
      .background(selected ? tint.opacity(0.9) : tint.opacity(0.14), in: Circle())
      .overlay {
        Circle()
          .strokeBorder(tint.opacity(selected ? 1 : 0.65), lineWidth: 1.5 * scale)
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
      .overlay {
        Circle()
          .inset(by: 4 * scale)
          .strokeBorder(tint.opacity(selected ? 0.15 : 0.25), lineWidth: scale)
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
      .contentShape(Circle())
  }
}

/// Concentric Augma circular icon label for use inside an outer glass container (such as a Dock).
public struct AugmaOrbLabel: View {
  public let symbol: String
  public let tint: Color
  public var selected: Bool
  public var diameter: CGFloat

  private var scale: CGFloat { diameter / 44 }

  public init(symbol: String, tint: Color = .augmaCyan, selected: Bool = false, diameter: CGFloat = 44) {
    self.symbol = symbol
    self.tint = tint
    self.selected = selected
    self.diameter = diameter
  }

  public var body: some View {
    Image(systemName: symbol)
      .font(.system(size: 19 * scale, weight: .medium))
      .foregroundStyle(selected ? Color.white : tint)
      .augmaOrbChrome(tint: tint, selected: selected, diameter: diameter)
  }
}

/// Standalone iOS 26 and macOS 26 Liquid Glass circular action button with Augma concentric rings.
/// Avoid nesting this view inside another `.augmaGlass` container; use `AugmaOrbLabel` inside outer capsules.
public struct AugmaGlassOrbButton: View {
  public let title: String
  public let symbol: String
  public var tint: Color
  public var selected: Bool
  public var badge: Int
  public var diameter: CGFloat
  public let action: () -> Void

  private var scale: CGFloat { diameter / 44 }

  public init(
    title: String,
    symbol: String,
    tint: Color = .augmaCyan,
    selected: Bool = false,
    badge: Int = 0,
    diameter: CGFloat = 44,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.symbol = symbol
    self.tint = tint
    self.selected = selected
    self.badge = badge
    self.diameter = diameter
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 19 * scale, weight: .medium))
        .foregroundStyle(selected ? Color.white : tint)
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
    }
    .augmaButton(selected ? .floatingProminent : .floating)
    .buttonBorderShape(.circle)
    .tint(tint)
    .overlay {
      Circle()
        .strokeBorder(tint.opacity(selected ? 0.9 : 0.55), lineWidth: 1.5 * scale)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
    .overlay {
      Circle()
        .inset(by: 4 * scale)
        .strokeBorder(tint.opacity(selected ? 0.2 : 0.25), lineWidth: scale)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
    .overlay(alignment: .topTrailing) {
      if badge > 0 {
        Text(badge > 99 ? "99+" : String(badge))
          .font(.system(size: 10, weight: .bold, design: .rounded))
          .foregroundStyle(.white)
          .padding(.horizontal, 4)
          .frame(minWidth: 16, minHeight: 16)
          .background(Color.augmaHighlight, in: Capsule())
          .offset(x: 3, y: -2)
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
    }
    .accessibilityLabel(title)
  }
}
