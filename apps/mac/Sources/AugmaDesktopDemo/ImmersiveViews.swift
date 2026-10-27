import AppKit
import SwiftUI

struct ImmersiveCanvasView: View {
  @ObservedObject var session: NativeDemoModel
  @ObservedObject var preferences: NativePreferencesStore
  let workspace: WorkspaceStore
  let commands: WorkspaceCommands
  let monitor: SystemMonitorStore
  let weather: WeatherStore
  let audio: NativeAudioStore
  let maps: NativeMapStore
  let camera: NativeCameraStore
  let onInteractiveRegionsChanged: ([CGRect]) -> Void

  private var panelVisible: Bool { session.selection != nil && preferences.value.showHud }

  var body: some View {
    GeometryReader { geometry in
      let available = ImmersiveLayout.content(in: geometry.size)
      let wide = geometry.size.width >= 900
      let spaceCanvas = !preferences.value.showHud ? available
        : wide ? CGRect(x: 440, y: available.minY, width: max(200, geometry.size.width - 460), height: min(660, available.height))
        : CGRect(x: 20, y: available.minY, width: available.width, height: min(300, available.height * 0.45))
      let panel = session.selection == .browser ? available : session.selection == .space && !wide
        ? CGRect(x: 20, y: spaceCanvas.maxY + 16, width: available.width, height: max(150, available.maxY - spaceCanvas.maxY - 16))
        : CGRect(x: 20, y: available.minY, width: min(400, available.width), height: min(660, available.height))
      ZStack(alignment: .topLeading) {
        if session.selection == .space {
          NativeSpaceCanvas(store: session.space, preferences: preferences)
            .frame(width: spaceCanvas.width, height: spaceCanvas.height)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .offset(x: spaceCanvas.minX, y: spaceCanvas.minY)
            .shadow(radius: 12)
        }
        if panelVisible {
          VStack(spacing: 0) {
            HStack {
              Label(session.selection?.title ?? String(localized: "选择应用"), systemImage: session.selection?.symbol ?? "square.grid.2x2")
                .font(.headline)
              Spacer()
              Button("关闭面板", systemImage: "xmark") { session.selection = nil }
                .labelStyle(.iconOnly).buttonStyle(.borderless)
            }
            .padding(14)
            Divider()
            ImmersiveNativePanel(session: session, preferences: preferences, workspace: workspace, commands: commands,
                                 monitor: monitor, weather: weather, audio: audio, maps: maps, camera: camera)
              .scrollContentBackground(.hidden)
          }
          .background { ActiveBackdropView().opacity(preferences.value.opacity / 100) }
          .clipShape(RoundedRectangle(cornerRadius: 16))
          .frame(width: panel.width, height: panel.height)
          .offset(x: panel.minX, y: panel.minY)
          .shadow(radius: 12)
        }
        LinkStartOverlay().frame(width: geometry.size.width, height: geometry.size.height)
      }
      .onAppear { reportRegions(panel, spaceCanvas) }
      .onChange(of: session.selection) { _, _ in reportRegions(panel, spaceCanvas) }
      .onChange(of: preferences.value.showHud) { _, _ in reportRegions(panel, spaceCanvas) }
      .onChange(of: geometry.size) { _, _ in reportRegions(panel, spaceCanvas) }
    }
    .background(Color.clear)
    .focusedSceneValue(\.nativeDemo, session)
  }

  private func reportRegions(_ panel: CGRect, _ spaceCanvas: CGRect) {
    onInteractiveRegionsChanged((session.selection == .space ? [spaceCanvas] : []) + (panelVisible ? [panel] : []))
  }
}

private struct ImmersiveNativePanel: View {
  @ObservedObject var session: NativeDemoModel
  let preferences: NativePreferencesStore
  let workspace: WorkspaceStore
  let commands: WorkspaceCommands
  let monitor: SystemMonitorStore
  let weather: WeatherStore
  let audio: NativeAudioStore
  let maps: NativeMapStore
  let camera: NativeCameraStore

  var body: some View {
    switch session.selection {
    case .notes: QuickNotesView(store: workspace, commands: commands)
    case .focus: FocusTimerView(store: workspace, commands: commands)
    case .actions: WorkspaceCommandView(commands: commands, store: workspace, compact: true)
    case .monitor: SystemMonitorView(store: monitor)
    case .market: ApplicationMarketView(store: session.market)
    case .weather: NativeLiveWeatherView(store: weather)
    case .audio: NativeAudioView(store: audio)
    case .navigation: NativeMapView(store: maps)
    case .camera: NativeCameraView(store: camera)
    case .space: NativeSpaceControlsView(store: session.space, preferences: preferences)
    case .settings: NativeScenePreferencesView(store: preferences)
    case .notifications: NativeNotificationsView(store: session.notifications)
    case .commands: NativeCommandView(store: session.assistant, commands: commands)
    case .device: NativeDeviceView(store: session.device, space: session.space, camera: camera, preferences: preferences)
    case .browser: NativeBrowserView(store: session.browser, presentation: .immersive)
    case nil: EmptyView()
    }
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
