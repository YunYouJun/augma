import AppKit
import SwiftUI

struct ImmersiveDockView: View {
  @ObservedObject var session: NativeDemoModel
  @ObservedObject var preferences: NativePreferencesStore
  @ObservedObject var camera: NativeCameraStore
  @ObservedObject var dock: NativeDockStore
  let select: (DemoModule) -> Void
  @State private var dockViewport = CGRect.zero

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 5) {
        Image(systemName: "arrowtriangle.down.fill")
          .font(.system(size: 8)).foregroundStyle(.secondary).accessibilityHidden(true)
        dockItems(availableWidth: geometry.size.width)
          .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { dockViewport = $0 }
          .contentShape(Capsule())
          .contextMenu { customizationMenu }
          .augmaGlass(cornerRadius: 34)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("应用 Dock")
    .accessibilityAction(named: Text("恢复默认 Dock")) { dock.reset() }
    .focusedSceneValue(\.nativeDemo, session)
    .onDisappear { dock.cancelDrag() }
    .alert("无法打开应用", isPresented: Binding(get: { session.isImmersive && !dock.launchError.isEmpty },
      set: { if !$0 { dock.launchError = "" } })) {
      Button("好") { dock.launchError = "" }
    } message: { Text(dock.launchError) }
  }

  private func dockItems(availableWidth: CGFloat) -> some View {
    NativeDockRow(store: dock, viewport: dockViewport, availableWidth: availableWidth) { item, iconSize in
      dockButton(item, size: iconSize)
        .contextMenu {
          Menu("选项") {
            Button("从 Dock 中移除", systemImage: "minus.circle") { dock.remove(item) }
            Button("在访达中显示", systemImage: "folder") {
              if let url = revealURL(item) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
            .disabled(revealURL(item) == nil)
            Divider()
            Button("向左移动", systemImage: "arrow.left") { dock.move(item, by: -1) }
              .disabled(dock.items.first == item)
            Button("向右移动", systemImage: "arrow.right") { dock.move(item, by: 1) }
              .disabled(dock.items.last == item)
          }
          customizationMenu
        }
        .accessibilityAction(named: Text("从 Dock 中移除")) { dock.remove(item) }
        .accessibilityAction(named: Text("向左移动")) { dock.move(item, by: -1) }
        .accessibilityAction(named: Text("向右移动")) { dock.move(item, by: 1) }
    } empty: {
      Menu { customizationMenu } label: { Label("自定 Dock", systemImage: "plus") }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .frame(height: 44)
        .accessibilityIdentifier("dock-customize")
    }
  }
  @ViewBuilder
  private var customizationMenu: some View {
    Button("浏览与添加应用…", systemImage: "square.grid.2x2") {
      select(.library)
    }
    Button("Augma Link · 扩展中心", systemImage: "puzzlepiece.extension") {
      session.market.section = .plugins
      select(.market)
    }
    if !dock.removedItems.isEmpty {
      Menu("添加到 Dock") {
        ForEach(dock.removedItems) { item in
          Button(item.title) { dock.restore(item) }
        }
      }
    }
    Button("恢复默认 Dock", systemImage: "arrow.counterclockwise") { dock.reset() }
  }

  private var mirrored: Bool { session.selection == .camera ? camera.mirrored : preferences.value.mirror }

  private func dockButton(_ item: NativeDockItem, size: CGFloat) -> some View {
    NativeOrbButton(title: title(for: item), symbol: symbol(for: item), tint: color(for: item),
                    selected: selected(item), dockTooltip: true,
                    applicationIcon: item.application.map { NSWorkspace.shared.icon(forFile: $0.path) },
                    diameter: size,
                    identifier: identifier(for: item)) {
      if let plugin = item.plugin { session.openPlugin(plugin.id); return }
      if item.application != nil { Task { await dock.open(item) }; return }
      if let module = item.module { select(module) }
      else {
        switch item {
        case .mirror:
          if session.selection == .camera { camera.mirrored.toggle() }
          else { preferences.value.mirror.toggle() }
        case .hud: preferences.value.showHud.toggle()
        case .github: openWeb("https://github.com/YunYouJun/augma")
        case .docs: openWeb("https://augma.yyj.moe")
        default: break
        }
      }
    }
  }

  private func title(for item: NativeDockItem) -> String {
    item == .hud ? (preferences.value.showHud ? String(appLocalized: "隐藏 HUD") : String(appLocalized: "显示 HUD")) : item.title
  }

  private func symbol(for item: NativeDockItem) -> String {
    if let plugin = item.plugin { return plugin.symbol }
    return switch item {
    case .mirror: "arrow.left.and.right.righttriangle.left.righttriangle.right"
    case .hud: preferences.value.showHud ? "eye" : "eye.slash"
    case .github: "chevron.left.forwardslash.chevron.right"
    case .docs: "book"
    default: item.module?.symbol ?? "app"
    }
  }

  private func selected(_ item: NativeDockItem) -> Bool {
    if let plugin = item.plugin { return session.selection == .plugin && session.activePluginID == plugin.id }
    if item.application != nil { return false }
    return switch item {
    case .mirror: mirrored
    case .hud: preferences.value.showHud
    default: item.module == session.selection && preferences.value.showHud
    }
  }

  private func identifier(for item: NativeDockItem) -> String {
    "immersive-" + (item.module == nil ? "" : "dock-") + item.id
  }

  private func revealURL(_ item: NativeDockItem) -> URL? {
    if let plugin = item.plugin { return session.plugins.enabledPackage(plugin.id)?.root }
    if item.application != nil { return dock.resolvedApplication(for: item).map { URL(fileURLWithPath: $0.path) } }
    return Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main.bundleURL : nil
  }

  private func color(for item: NativeDockItem) -> Color {
    switch item {
    case .weather, .navigation: .orange
    case .audio, .hud, .docs: .blue
    case .space: .teal
    case .camera: .cyan
    case .github: .secondary
    default: .augmaCyan
    }
  }

  private func openWeb(_ address: String) {
    guard let url = URL(string: address) else { return }
    session.browser.navigate(to: url)
    select(.browser)
  }
}
