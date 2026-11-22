import SwiftUI

/// Semantic button hierarchy across content and floating Liquid Glass surfaces.
public enum AugmaButtonRole: String, CaseIterable, Sendable {
  /// Primary action inside standard scrolling forms, cards, and panels.
  case primary
  /// Secondary action inside standard scrolling forms, cards, and panels.
  case secondary
  /// Floating action resting above spatial, camera, map, or HUD content.
  case floating
  /// Emphasized floating Liquid Glass action.
  case floatingProminent
}

public extension View {
  /// Native floating Liquid Glass surface backed by system rim, refraction, and contrast.
  func augmaGlass(cornerRadius: CGFloat = 20, clear: Bool = false, interactive: Bool = false) -> some View {
    let base: Glass = clear ? .clear : .regular
    return glassEffect(interactive ? base.interactive() : base, in: .rect(cornerRadius: cornerRadius))
  }

  /// Native capsule-shaped Liquid Glass surface for compact HUD pills and bars.
  func augmaGlassCapsule(clear: Bool = false, interactive: Bool = false) -> some View {
    let base: Glass = clear ? .clear : .regular
    return glassEffect(interactive ? base.interactive() : base, in: .capsule)
  }

  /// Applies a unified Augma button role across iOS 26 and macOS 26.
  @ViewBuilder
  func augmaButton(_ role: AugmaButtonRole) -> some View {
    switch role {
    case .primary:
      buttonStyle(.borderedProminent)
    case .secondary:
      buttonStyle(.bordered)
    case .floating:
      buttonStyle(.glass)
    case .floatingProminent:
      buttonStyle(.glassProminent)
    }
  }

  /// Floating actions use native Liquid Glass button styles, including focus and disabled states.
  @ViewBuilder
  func nativeFloatingButton(prominent: Bool = false) -> some View {
    augmaButton(prominent ? .floatingProminent : .floating)
  }
}

/// Groups sibling floating Liquid Glass actions inside a shared container so they merge cleanly.
public struct AugmaGlassActionBar<Content: View>: View {
  private let spacing: CGFloat
  private let content: () -> Content

  public init(spacing: CGFloat = 10, @ViewBuilder content: @escaping () -> Content) {
    self.spacing = spacing
    self.content = content
  }

  public var body: some View {
    GlassEffectContainer(spacing: spacing) {
      HStack(spacing: spacing, content: content)
    }
  }
}
