import AppKit
import SwiftUI

struct ImmersiveCanvasView: View {
  @Binding var selection: DemoModule?
  @State private var loadError: String?
  @State private var panelRegions: [CGRect] = []
  let onInteractiveRegionsChanged: ([CGRect]) -> Void

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .topLeading) {
        ForEach(panelRegions.indices, id: \.self) { index in
          let rect = panelRegions[index]
          ActiveBackdropView()
            .frame(width: rect.width, height: rect.height)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
        }
        DemoWebView(selection: $selection, loadError: $loadError, immersive: true) { regions in
          if panelRegions != regions.panels {
            panelRegions = regions.panels
          }
          onInteractiveRegionsChanged(regions.interactive)
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        if let loadError {
          ContentUnavailableView("无法载入沉浸界面", systemImage: "exclamationmark.triangle", description: Text(loadError))
            .frame(width: 420, height: 240)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        LinkStartOverlay()
          .frame(width: geometry.size.width, height: geometry.size.height)
      }
    }
    .background(Color.clear)
  }
}

/// One-shot entrance when the overlay takes over the desktop: a scan line crosses the
/// screen and rings expand from its centre. Never intercepts input; skipped for reduced motion.
private struct LinkStartOverlay: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var line: CGFloat = 0
  @State private var ripple: CGFloat = 0
  @State private var visible = true

  var body: some View {
    if visible && !reduceMotion {
      GeometryReader { geometry in
        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        ZStack {
          LinearGradient(colors: [.clear, .white.opacity(0.9), Color.augmaHighlight, .white.opacity(0.9), .clear], startPoint: .leading, endPoint: .trailing)
            .frame(width: geometry.size.width * line, height: 2)
            .shadow(color: Color.augmaHighlight.opacity(0.8), radius: 8)
            .position(center)
          ForEach(0..<3) { index in
            let spread = max(0, ripple - CGFloat(index) * 0.18)
            Circle()
              .stroke(index == 0 ? Color.augmaHighlight : Color.white, lineWidth: index == 0 ? 2 : 1)
              .frame(width: 80 + spread * 560, height: 80 + spread * 560)
              .opacity(Double(max(0, 1 - spread)) * (ripple > 0 ? 0.9 : 0))
              .position(center)
          }
          AugmaRing(size: 120)
            .opacity(ripple > 0 && ripple < 1 ? 1 : 0)
            .scaleEffect(0.85 + ripple * 0.3)
            .position(center)
        }
        .shadow(color: .black.opacity(0.35), radius: 3)
      }
      .allowsHitTesting(false)
      .accessibilityHidden(true)
      .task {
        withAnimation(.augma(duration: 0.4)) { line = 1 }
        try? await Task.sleep(for: .seconds(0.25))
        withAnimation(.easeOut(duration: 1.1)) { ripple = 1.4 }
        withAnimation(.easeIn(duration: 0.5).delay(0.5)) { line = 0 }
        try? await Task.sleep(for: .seconds(1.2))
        visible = false
      }
    }
  }
}

struct ImmersiveControlsView: View {
  @Binding var selection: DemoModule?
  @ObservedObject var model: HudModel
  let toggleInteraction: () -> Void
  let exit: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      AugmaRing(size: 22, spinning: !model.immersiveClickThrough)
      Menu {
        ForEach(DemoModule.allCases) { module in
          Button(module.title, systemImage: module.symbol) {
            selection = module
          }
        }
      } label: {
        Label(selection?.title ?? String(localized: "选择应用"), systemImage: "square.grid.2x2")
      }
      .frame(minWidth: 105)

      Divider()
        .frame(height: 20)

      Button(model.immersiveClickThrough ? "操作界面" : "操作桌面", systemImage: model.immersiveClickThrough ? "cursorarrow.click" : "desktopcomputer", action: toggleInteraction)
        .help(model.immersiveClickThrough ? "恢复界面交互，空白处仍可点击桌面" : "所有区域都允许点击下方桌面")

      Button("退出", systemImage: "xmark", action: exit)
        .help("退出沉浸模式")
    }
    .buttonStyle(.borderless)
    .tint(.augmaAccent)
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .controlBarGlass()
    .padding(4)
    .augmaMaterialize(delay: 0.35)
  }
}

private extension View {
  /// Liquid Glass on macOS 26. Earlier systems keep a backdrop forced active, so the bar
  /// stays blurred while the control panel is not key.
  @ViewBuilder
  func controlBarGlass() -> some View {
    if #available(macOS 26, *) {
      augmaGlass(markLength: 24)
    } else {
      background {
        ActiveBackdropView()
          .clipShape(RoundedRectangle(cornerRadius: 3))
      }
      .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.primary.opacity(0.15)))
      .overlay { HudAccentMarks(length: 24) }
    }
  }
}

private struct ActiveBackdropView: NSViewRepresentable {
  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = .hudWindow
    view.blendingMode = .behindWindow
    view.state = .active
    return view
  }

  func updateNSView(_ view: NSVisualEffectView, context: Context) {
    view.state = .active
  }
}
