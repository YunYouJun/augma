import SwiftUI

enum NativeWindowLayout: String, CaseIterable {
  case augma, sidebar
  static let storageKey = "augma.mainWindowLayout"
  var toggled: Self { self == .augma ? .sidebar : .augma }
}

/// The window only changes its shell; every module keeps the same scene-owned store.
struct AugmaWindowLayout<Content: View>: View {
  @ObservedObject var model: NativeDemoModel
  @ObservedObject var preferences: NativePreferencesStore
  let appDelegate: HudAppDelegate
  let switchLayout: () -> Void
  @ViewBuilder let content: () -> Content

  var body: some View {
    Group {
      if preferences.value.showHud || model.selection == .space {
        content()
      } else {
        ContentUnavailableView("HUD 已隐藏", systemImage: "eye.slash",
                               description: Text("使用底部 Dock 显示 HUD 或打开应用。"))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    // Keep scrolling content in the same safe-area hierarchy as the fixed controls.
    // Clipping the content pane here would cut off the system's blurred transition.
    .safeAreaBar(edge: .top, spacing: 12) { header }
    .safeAreaBar(edge: .bottom, spacing: 12) {
      ImmersiveDockView(session: model, preferences: preferences, camera: appDelegate.camera, select: select)
        .frame(height: 82)
    }
    .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
    .padding(16)
  }

  private var header: some View {
    ZStack {
      ImmersiveClockView().frame(width: 180)
      HStack {
        ImmersiveVoiceCorner(select: select)
        Spacer()
        ImmersiveSystemCorner(
          session: model, preferences: preferences, model: appDelegate.model, notices: model.notifications,
          select: select, toggleInteraction: {}, exit: { appDelegate.enterImmersive(model) },
          immersive: false, switchLayout: switchLayout
        )
      }
    }
    .frame(height: 60)
  }

  private func select(_ module: DemoModule) {
    preferences.value.showHud = true
    model.selection = module
  }
}
