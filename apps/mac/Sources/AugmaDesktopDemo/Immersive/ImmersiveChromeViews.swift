import SwiftUI

struct ImmersiveVoiceCorner: View {
  let select: (DemoModule) -> Void

  var body: some View {
    NativeOrbButton(title: String(appLocalized: "语音助手"), symbol: "mic.fill", tint: .green,
                    identifier: "immersive-voice") { select(.commands) }
      .padding(7)
      .augmaGlass(cornerRadius: 30)
      .padding(1)
  }
}

struct ImmersiveClockView: View {
  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      VStack(spacing: 3) {
        Text("AUGMA").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(3)
          .foregroundStyle(.secondary)
        Text(context.date, format: .dateTime.hour().minute().second())
          .font(.system(size: 20, weight: .semibold, design: .monospaced)).monospacedDigit()
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 7)
      .background(.regularMaterial, in: Capsule())
    }
    .padding(3)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Augma 时钟")
  }
}

struct ImmersiveSystemCorner: View {
  @ObservedObject var session: NativeDemoModel
  @ObservedObject var preferences: NativePreferencesStore
  @ObservedObject var model: HudModel
  @ObservedObject var notices: NativeNotificationStore
  let select: (DemoModule) -> Void
  let toggleInteraction: () -> Void
  let exit: () -> Void
  var immersive = true
  var switchLayout: (() -> Void)? = nil

  var body: some View {
    HStack(spacing: 8) {
      NativeOrbButton(title: String(appLocalized: "通知"), symbol: "bell", tint: .augmaHighlight,
                      selected: session.selection == .notifications, badge: notices.unreadCount,
                      identifier: "immersive-notifications") { select(.notifications) }
      NativeOrbButton(title: String(appLocalized: "设置"), symbol: "gearshape", tint: .augmaCyan,
                      selected: session.selection == .settings, identifier: "immersive-settings") { select(.settings) }
      Menu {
        ForEach(DemoModule.allCases) { module in
          Button(module.title, systemImage: module.symbol) { select(module) }
        }
        Divider()
        Toggle("显示顶部时钟", isOn: $preferences.showsClock)
        Button(preferences.value.dark ? String(appLocalized: "切换浅色场景") : String(appLocalized: "切换深色场景"),
               systemImage: preferences.value.dark ? "sun.max" : "moon") { preferences.value.dark.toggle() }
        if let switchLayout {
          Button("切换为侧栏布局", systemImage: "sidebar.left", action: switchLayout)
        }
        if immersive {
          Button(model.immersiveClickThrough ? String(appLocalized: "操作界面") : String(appLocalized: "操作桌面"),
                 systemImage: model.immersiveClickThrough ? "cursorarrow.click" : "desktopcomputer", action: toggleInteraction)
        }
        Divider()
        Button(immersive ? String(appLocalized: "退出沉浸模式") : String(appLocalized: "沉浸模式"),
               systemImage: immersive ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right", action: exit)
      } label: {
        Image(systemName: model.immersiveClickThrough ? "cursorarrow.click" : "line.3.horizontal")
      }
      .menuStyle(.borderlessButton).menuIndicator(.hidden)
      .frame(width: 44, height: 44)
      .background(Color.augmaCyan.opacity(model.immersiveClickThrough ? 0.9 : 0.14), in: Circle())
      .overlay { Circle().strokeBorder(Color.augmaCyan.opacity(0.65), lineWidth: 1.5).allowsHitTesting(false) }
      .overlay { Circle().inset(by: 4).strokeBorder(Color.augmaCyan.opacity(0.25), lineWidth: 1).allowsHitTesting(false) }
      .help("系统菜单").accessibilityLabel("系统菜单")
      .accessibilityIdentifier("immersive-system-menu")
      NativeOrbButton(title: immersive ? String(appLocalized: "退出沉浸模式") : String(appLocalized: "沉浸模式"),
                      symbol: immersive ? "xmark" : "arrow.up.left.and.arrow.down.right", tint: .secondary,
                      identifier: immersive ? "immersive-exit" : "main-enter-immersive", action: exit)
    }
    .padding(7)
    .augmaGlass(cornerRadius: 30)
    .padding(1)
    .focusedSceneValue(\.nativeDemo, session)
  }
}
