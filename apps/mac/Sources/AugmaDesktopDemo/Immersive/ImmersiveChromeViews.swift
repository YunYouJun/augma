import SwiftUI

struct ImmersiveVoiceCorner: View {
  let select: (DemoModule) -> Void

  var body: some View {
    NativeOrbButton(title: String(localized: "语音助手"), symbol: "mic.fill", tint: .green,
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
      NativeOrbButton(title: String(localized: "通知"), symbol: "bell", tint: .augmaHighlight,
                      selected: session.selection == .notifications, badge: notices.unreadCount,
                      identifier: "immersive-notifications") { select(.notifications) }
      NativeOrbButton(title: String(localized: "设置"), symbol: "gearshape", tint: .augmaCyan,
                      selected: session.selection == .settings, identifier: "immersive-settings") { select(.settings) }
      Menu {
        ForEach(DemoModule.allCases) { module in
          Button(module.title, systemImage: module.symbol) { select(module) }
        }
        Divider()
        Button(preferences.value.dark ? String(localized: "切换浅色场景") : String(localized: "切换深色场景"),
               systemImage: preferences.value.dark ? "sun.max" : "moon") { preferences.value.dark.toggle() }
        if let switchLayout {
          Button("切换为侧栏布局", systemImage: "sidebar.left", action: switchLayout)
        }
        if immersive {
          Button(model.immersiveClickThrough ? String(localized: "操作界面") : String(localized: "操作桌面"),
                 systemImage: model.immersiveClickThrough ? "cursorarrow.click" : "desktopcomputer", action: toggleInteraction)
        }
        Divider()
        Button(immersive ? String(localized: "退出沉浸模式") : String(localized: "沉浸模式"),
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
      NativeOrbButton(title: immersive ? String(localized: "退出沉浸模式") : String(localized: "沉浸模式"),
                      symbol: immersive ? "xmark" : "arrow.up.left.and.arrow.down.right", tint: .secondary,
                      identifier: immersive ? "immersive-exit" : "main-enter-immersive", action: exit)
    }
    .padding(7)
    .augmaGlass(cornerRadius: 30)
    .padding(1)
    .focusedSceneValue(\.nativeDemo, session)
  }
}

struct ImmersiveDockView: View {
  @ObservedObject var session: NativeDemoModel
  @ObservedObject var preferences: NativePreferencesStore
  @ObservedObject var camera: NativeCameraStore
  let select: (DemoModule) -> Void

  var body: some View {
    VStack(spacing: 5) {
      Image(systemName: "arrowtriangle.down.fill")
        .font(.system(size: 8)).foregroundStyle(.secondary).accessibilityHidden(true)
      HStack(spacing: 10) {
        NativeOrbButton(title: String(localized: "镜像视图"), symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                        tint: .augmaCyan, selected: mirrored, identifier: "immersive-mirror") {
          if session.selection == .camera { camera.mirrored.toggle() }
          else { preferences.value.mirror.toggle() }
        }
        dockButton(.weather)
        NativeOrbButton(title: preferences.value.showHud ? String(localized: "隐藏 HUD") : String(localized: "显示 HUD"),
                        symbol: preferences.value.showHud ? "eye" : "eye.slash", tint: .blue,
                        selected: preferences.value.showHud, identifier: "immersive-hud") { preferences.value.showHud.toggle() }
        ForEach([DemoModule.audio, .space, .camera, .navigation, .browser]) { module in dockButton(module) }
        NativeOrbButton(title: "GitHub", symbol: "chevron.left.forwardslash.chevron.right", tint: .secondary,
                        identifier: "immersive-github") { openWeb("https://github.com/YunYouJun/augma") }
        NativeOrbButton(title: String(localized: "Augma 文档"), symbol: "book", tint: .blue,
                        identifier: "immersive-docs") { openWeb("https://augma.yyj.moe") }
      }
      .padding(.horizontal, 16).padding(.vertical, 8)
      .augmaGlass(cornerRadius: 34)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("应用 Dock")
    .focusedSceneValue(\.nativeDemo, session)
  }

  private var mirrored: Bool { session.selection == .camera ? camera.mirrored : preferences.value.mirror }

  private func dockButton(_ module: DemoModule) -> some View {
    NativeOrbButton(title: module.title, symbol: module.symbol, tint: color(for: module),
                    selected: session.selection == module && preferences.value.showHud,
                    identifier: "immersive-dock-" + module.rawValue) { select(module) }
  }

  private func color(for module: DemoModule) -> Color {
    switch module {
    case .weather: .orange
    case .audio: .blue
    case .space: .teal
    case .camera: .cyan
    case .navigation: .orange
    default: .augmaCyan
    }
  }

  private func openWeb(_ address: String) {
    guard let url = URL(string: address) else { return }
    session.browser.navigate(to: url)
    select(.browser)
  }
}
