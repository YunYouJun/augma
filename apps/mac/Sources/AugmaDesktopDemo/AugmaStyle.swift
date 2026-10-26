import AppKit
import SwiftUI

// Native counterparts of the web tokens in packages/core/src/tokens.css.
extension Color {
  /// Decorative HUD light (`--agm-highlight`), identical in both appearances.
  static let augmaHighlight = Color(red: 242 / 255, green: 140 / 255, blue: 18 / 255)
  /// Action color (`--agm-accent`).
  static let augmaAccent = Color(light: (183, 94, 8), dark: (241, 167, 76))
  /// Continuous controls and healthy state (`--agm-cyan`).
  static let augmaCyan = Color(light: (37, 140, 164), dark: (103, 200, 218))
  /// Status text stays readable on light glass; system green/red are too bright at caption sizes.
  static let augmaHealthy = Color(light: (28, 117, 65), dark: (102, 211, 137))
  static let augmaCritical = Color(light: (189, 41, 41), dark: (255, 128, 118))
  /// Traffic direction is categorical; keep upload blue so orange retains its warning meaning.
  static let augmaUpload = Color(light: (30, 100, 192), dark: (112, 175, 255))

  private init(light: (Double, Double, Double), dark: (Double, Double, Double)) {
    self.init(nsColor: NSColor(name: nil) { appearance in
      let rgb = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
      return NSColor(srgbRed: rgb.0 / 255, green: rgb.1 / 255, blue: rgb.2 / 255, alpha: 1)
    })
  }
}

/// Matches `--agm-ease`: arrive fast, settle softly.
extension Animation {
  static func augma(duration: Double = 0.42) -> Animation {
    .timingCurve(0.16, 1, 0.3, 1, duration: duration)
  }
}

/// HUD rings: a 60-mark scale, a cyan orbit with two counter-rotating orange arcs and a dashed core.
struct AugmaRing: View {
  var size: CGFloat = 96
  var spinning = true
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 30, paused: !spinning || reduceMotion)) { context in
      let seconds = spinning && !reduceMotion ? context.date.timeIntervalSinceReferenceDate : 0
      let angle = (seconds / 24).truncatingRemainder(dividingBy: 1) * 360
      let tick = max(2, size * 0.05)
      let marks = 2 * .pi * (size / 2 - tick / 2) / 60
      ZStack {
        Circle()
          .strokeBorder(Color.primary.opacity(0.35), style: StrokeStyle(lineWidth: tick, dash: [1, marks - 1]))
          .rotationEffect(.degrees(angle * 0.25))
        Circle()
          .inset(by: size * 0.11)
          .stroke(Color.augmaCyan.opacity(0.5), lineWidth: 1)
        ForEach([0.0, 0.5], id: \.self) { start in
          Circle()
            .inset(by: size * 0.11)
            .trim(from: start, to: start + 0.14)
            .stroke(Color.augmaHighlight, style: StrokeStyle(lineWidth: max(2, size * 0.025), lineCap: .round))
            .rotationEffect(.degrees(-angle))
        }
        Circle()
          .inset(by: size * 0.22)
          .stroke(Color.primary.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
          .rotationEffect(.degrees(angle * 0.5))
      }
      .frame(width: size, height: size)
      .shadow(color: Color.augmaHighlight.opacity(0.25), radius: 4)
    }
    .accessibilityHidden(true)
  }
}

/// Status dot with a sonar ping, like the web HudStatus.
struct StatusPing: View {
  var color: Color
  var active = true
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 30, paused: !active || reduceMotion)) { context in
      let cycle = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4
      let progress = min(cycle / 0.7, 1)
      let pinging = active && !reduceMotion
      ZStack {
        Circle()
          .fill(color)
          .frame(width: 7, height: 7)
          .scaleEffect(pinging ? 1 + 2.2 * progress : 1)
          .opacity(pinging ? 0.55 * (1 - progress) : 0)
        Circle()
          .fill(color)
          .frame(width: 7, height: 7)
      }
    }
    .frame(width: 22, height: 22)
    .accessibilityHidden(true)
  }
}

/// Four corner brackets around a target area.
struct HudBrackets: Shape {
  var length: CGFloat = 14

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let l = min(length, rect.width / 2, rect.height / 2)
    for (corner, dx, dy) in [
      (CGPoint(x: rect.minX, y: rect.minY), 1.0, 1.0),
      (CGPoint(x: rect.maxX, y: rect.minY), -1.0, 1.0),
      (CGPoint(x: rect.minX, y: rect.maxY), 1.0, -1.0),
      (CGPoint(x: rect.maxX, y: rect.maxY), -1.0, -1.0),
    ] {
      path.move(to: CGPoint(x: corner.x + dx * l, y: corner.y))
      path.addLine(to: corner)
      path.addLine(to: CGPoint(x: corner.x, y: corner.y + dy * l))
    }
    return path
  }
}

/// Materialize: the view first appears as a lit horizontal line, then unfolds vertically.
private struct MaterializeModifier: ViewModifier {
  var active: Bool
  var delay: Double
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var stage = 0

  func body(content: Content) -> some View {
    content
      .mask {
        GeometryReader { geometry in
          Rectangle()
            .frame(width: stage == 0 ? 0 : geometry.size.width, height: stage < 2 ? 2 : geometry.size.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .brightness(stage == 2 ? 0 : 0.3)
      .opacity(stage == 0 ? 0 : 1)
      .task(id: active) {
        guard active else {
          stage = 0
          return
        }
        guard !reduceMotion else {
          stage = 2
          return
        }
        stage = 0
        try? await Task.sleep(for: .seconds(delay))
        withAnimation(.easeOut(duration: 0.16)) { stage = 1 }
        try? await Task.sleep(for: .seconds(0.16))
        withAnimation(.augma(duration: 0.46)) { stage = 2 }
      }
  }
}

extension View {
  /// Replays the materialize entrance whenever `active` becomes true.
  func augmaMaterialize(active: Bool = true, delay: Double = 0) -> some View {
    modifier(MaterializeModifier(active: active, delay: delay))
  }

  /// Native floating surfaces let the system supply the rim, contrast and accessibility treatment.
  @ViewBuilder
  func augmaGlass(cornerRadius: CGFloat = 20, clear: Bool = false) -> some View {
    if #available(macOS 26, *) {
      glassEffect(clear ? .clear : .regular, in: .rect(cornerRadius: cornerRadius))
    } else {
      background(clear ? .ultraThinMaterial : .regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
  }

  /// Floating actions use system styles, including keyboard focus and disabled appearances.
  @ViewBuilder
  func nativeFloatingButton(prominent: Bool = false) -> some View {
    if #available(macOS 26, *) {
      if prominent { buttonStyle(.glassProminent) }
      else { buttonStyle(.glass) }
    } else {
      if prominent { buttonStyle(.borderedProminent) }
      else { buttonStyle(.bordered) }
    }
  }
}

/// Borderless panels cache their shadow from the first frame; recompute it once the
/// materialize entrance has finished so the shadow follows the final shape.
@MainActor
func refreshShadowAfterEntrance(of window: NSWindow, delay: Duration = .milliseconds(800)) {
  Task { @MainActor [weak window] in
    try? await Task.sleep(for: delay)
    window?.invalidateShadow()
  }
}
