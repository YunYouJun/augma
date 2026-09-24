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
      }
    }
    .background(Color.clear)
  }
}

struct ImmersiveControlsView: View {
  @Binding var selection: DemoModule?
  @ObservedObject var model: HudModel
  let toggleInteraction: () -> Void
  let exit: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Menu {
        ForEach(DemoModule.allCases) { module in
          Button(module.title, systemImage: module.symbol) {
            selection = module
          }
        }
      } label: {
        Label(selection?.title ?? "选择应用", systemImage: "square.grid.2x2")
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
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background {
      ActiveBackdropView()
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.15)))
    .padding(4)
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
