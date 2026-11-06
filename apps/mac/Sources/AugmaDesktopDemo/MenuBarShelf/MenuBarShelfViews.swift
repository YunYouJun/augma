import AppKit
import SwiftUI

struct MenuBarShelfCommands: Commands {
  @ObservedObject var store: MenuBarShelfStore

  var body: some Commands {
    CommandGroup(after: .windowArrangement) {
      Button(String(appLocalized: "菜单栏收纳")) { store.show() }.disabled(!store.enabled || store.isBusy)
    }
  }
}

struct MenuBarShelfSettingsView: View {
  @ObservedObject var store: MenuBarShelfStore

  var body: some View {
    Form {
      NativeMenuBarContentSettings()
      Section("菜单栏收纳") {
        Toggle(String(appLocalized: "启用菜单栏收纳"), isOn: $store.enabled)
          .accessibilityIdentifier("menu-bar-shelf-enabled")
        Text(String(appLocalized: "在刘海下方查看被遮挡的图标，点击直接打开原应用菜单。默认关闭。"))
          .font(.caption).foregroundStyle(.secondary)
        if store.enabled {
          Button(String(appLocalized: "展开收纳栏")) { store.show() }
            .disabled(store.isBusy || !store.hasNotchedDisplay)
            .accessibilityIdentifier("menu-bar-shelf-show")
          Text(store.shortcutAvailable ? "全局快捷键：⌃⌥B" : "快捷键 ⌃⌥B 不可用，请从这里或 Augma 菜单栏打开。")
            .font(.caption).foregroundStyle(.secondary)
          if !store.hasNotchedDisplay {
            Text(String(appLocalized: "第一版支持内建刘海屏，请连接并启用该显示器。"))
              .font(.caption).foregroundStyle(.secondary)
          }
        }
      }
      if store.enabled {
        Section("权限") {
          LabeledContent("辅助功能", value: store.accessibilityAllowed ? String(appLocalized: "已允许") : String(appLocalized: "未允许"))
          if !store.accessibilityAllowed {
            Button(String(appLocalized: "允许辅助功能…")) { store.requestAccessibility() }
            Text(String(appLocalized: "用于识别菜单栏图标，并直接打开原应用菜单。"))
              .font(.caption).foregroundStyle(.secondary)
          }
          if store.needsIconAccess {
            Text(String(appLocalized: "多显示器下，读取图标窗口还需要屏幕录制权限。仅用于菜单栏识别和可选的图标截图。"))
              .font(.caption).foregroundStyle(.secondary)
            Button(String(appLocalized: "允许读取图标…")) { store.requestCapture() }
          }
          Toggle(String(appLocalized: "显示原始状态图标"), isOn: $store.originalIcons)
          Text(String(appLocalized: "可选。通过屏幕录制权限截取图标窗口，仅在收纳栏展开时刷新，不保存截图；未开启时显示应用图标。"))
            .font(.caption).foregroundStyle(.secondary)
          if store.originalIcons && !store.captureAllowed {
            Button(String(appLocalized: "允许截取图标…")) { store.requestCapture() }
          }
          Button(String(appLocalized: "重新检查权限")) { store.refreshPermissions() }
        }
      }
      if store.isBusy || store.error != nil {
        Section("菜单操作") {
          if store.isBusy { Label(String(appLocalized: "请完成原应用菜单操作。"), systemImage: "clock") }
          if let error = store.error { Text(error).foregroundStyle(Color.augmaCritical).textSelection(.enabled) }
        }
      }
    }
    .formStyle(.grouped)
    .contentMargins(NativePageLayout.pagePadding, for: .scrollContent)
    .onAppear { store.refreshPermissions() }
  }
}

struct MenuBarShelfMenuControl: View {
  @ObservedObject var store: MenuBarShelfStore

  var body: some View {
    if store.enabled {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Button(String(appLocalized: "菜单栏收纳"), systemImage: "menubar.arrow.down.rectangle") { store.show() }
            .disabled(store.isBusy).accessibilityIdentifier("menu-bar-shelf-menu-open")
          Spacer()
          Text(String(appLocalized: "⌃⌥B")).font(.caption).foregroundStyle(.secondary)
        }
        if store.isBusy { Text(String(appLocalized: "原应用菜单已打开。")) }
        if let error = store.error { Text(error).foregroundStyle(Color.augmaCritical) }
      }
      .font(.caption)
      Divider()
    }
  }
}

struct MenuBarShelfView: View {
  @ObservedObject var store: MenuBarShelfStore
  var compact = false

  var body: some View {
    Group {
      if compact { MenuBarShelfCompactView(store: store) }
      else { expandedContent }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("menu-bar-shelf-panel")
  }

  private var expandedContent: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: "menubar.arrow.down.rectangle").foregroundStyle(Color.augmaCyan)
        Text(String(appLocalized: "菜单栏收纳")).font(.headline)
        Spacer()
        if store.isRefreshing { ProgressView().controlSize(.mini) }
        Button { store.refresh(clearError: true) } label: { Image(systemName: "arrow.clockwise") }
          .help("刷新图标").disabled(store.isRefreshing)
        Button { store.hide() } label: { Image(systemName: "xmark") }.help("关闭")
      }
      .buttonStyle(.plain)
      if let error = store.error {
        Text(error).font(.caption).foregroundStyle(Color.augmaCritical)
      }
      if store.isBusy {
        HStack(spacing: 10) {
          ProgressView().controlSize(.small)
          Text(String(appLocalized: "正在打开原应用菜单…")).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if !store.accessibilityAllowed {
        HStack {
          Text(String(appLocalized: "允许辅助功能后，即可查看和打开被遮挡的图标。"))
          Spacer()
          Button(String(appLocalized: "允许辅助功能…")) { store.requestAccessibility() }
        }.frame(maxHeight: .infinity)
      } else if store.needsIconAccess {
        VStack(alignment: .leading, spacing: 10) {
          Text(String(appLocalized: "多显示器下，读取图标窗口还需要屏幕录制权限。仅用于菜单栏识别和可选的图标截图。"))
            .font(.callout).foregroundStyle(.secondary)
          Button(String(appLocalized: "允许读取图标…")) { store.requestCapture() }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      } else if store.items.isEmpty {
        HStack(spacing: 10) {
          Image(systemName: "checkmark.circle").foregroundStyle(Color.augmaCyan)
          Text(store.isRefreshing ? "正在查找被遮挡的图标…" : "当前没有被刘海遮挡的图标。")
            .foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView(.horizontal) {
          HStack(alignment: .center, spacing: 8) {
            ForEach(store.items) { item in
              MenuBarShelfItemView(item: item, image: store.images[item.id]) { store.open(item) }
                .contextMenu {
                  Button(String(appLocalized: "打开原应用菜单")) { store.open(item) }
                  Button(String(appLocalized: "以右键打开原菜单")) { store.open(item, rightClick: true) }
                }
            }
          }.padding(.vertical, 4)
        }
        .scrollIndicators(.visible)
        .frame(maxHeight: .infinity)
      }
      HStack {
        Text(String(appLocalized: "点击直接打开原应用菜单。"))
        Spacer()
        Text(String(appLocalized: "⌃⌥B · Esc"))
      }.font(.caption2).foregroundStyle(.secondary)
    }
    .padding(18)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22))
    .padding(MenuBarShelfLayout.expandedInset)
  }
}

struct MenuBarShelfItemView: View {
  let item: MenuBarShelfItem
  let image: NSImage?
  var compact = false
  let open: () -> Void
  @State private var hovering = false

  private var width: CGFloat {
    if compact { return image == nil ? 36 : min(116, max(36, item.window.frame.width + 8)) }
    return image == nil ? 66 : min(116, max(56, item.window.frame.width + 10))
  }

  var body: some View {
    Button(action: open) {
      VStack(spacing: 7) {
        if let image {
          Image(nsImage: image).resizable().scaledToFit()
            .frame(width: width - 8, height: compact ? 22 : 28)
        } else if let icon = NSRunningApplication(processIdentifier: item.applicationPID)?.icon {
          Image(nsImage: icon).resizable().scaledToFit().frame(width: compact ? 22 : 26, height: compact ? 22 : 28)
        } else {
          Image(systemName: "app.dashed").font(.title2).frame(height: compact ? 22 : 28)
        }
        if !compact {
          Text(item.applicationName).font(.caption2).lineLimit(1).truncationMode(.tail)
        }
      }
      .frame(width: width, height: compact ? 36 : 66)
      .background(.primary.opacity(hovering ? 0.1 : 0), in: RoundedRectangle(cornerRadius: 10))
      .contentShape(RoundedRectangle(cornerRadius: 10))
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
    .disabled(!item.canOpenMenu)
    .help(item.canOpenMenu ? item.label : String(appLocalized: "暂时无法识别所属应用，请刷新后重试。"))
    .accessibilityLabel(item.label)
    .accessibilityIdentifier("menu-bar-shelf-item-" + String(item.id))
  }
}
