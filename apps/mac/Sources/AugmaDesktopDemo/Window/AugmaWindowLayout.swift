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
    VStack(spacing: 12) {
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
      Group {
        if preferences.value.showHud || model.selection == .space {
          content()
        } else {
          ContentUnavailableView("HUD 已隐藏", systemImage: "eye.slash",
                                 description: Text("使用底部 Dock 显示 HUD 或打开应用。"))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .clipShape(RoundedRectangle(cornerRadius: 16))
      ImmersiveDockView(session: model, preferences: preferences, camera: appDelegate.camera, select: select)
        .frame(height: 82)
    }
    .padding(16)
  }

  private func select(_ module: DemoModule) {
    preferences.value.showHud = true
    model.selection = module
  }
}
