import SwiftUI

/// Keep the immersive shelf focused on status icons; names remain available on hover and via AX.
struct MenuBarShelfCompactView: View {
  @ObservedObject var store: MenuBarShelfStore

  var body: some View {
    HStack(spacing: 10) {
      // Keep the shelf identity separate from the original applications' status items.
      Image(systemName: "menubar.arrow.down.rectangle")
        .foregroundStyle(Color.augmaCyan)
        .frame(width: 24, height: 36)
        .help("菜单栏收纳")
      Divider().frame(height: 24)
      content.frame(maxWidth: .infinity, alignment: .leading)
      if let error = store.error {
        Image(systemName: "exclamationmark.circle")
          .foregroundStyle(Color.augmaCritical).help(error).accessibilityLabel(error)
      }
      if store.isRefreshing { ProgressView().controlSize(.mini) }
      Button { store.refresh(clearError: true) } label: {
        Image(systemName: "arrow.clockwise").frame(width: 28, height: 36)
      }
      .buttonStyle(.plain)
      .help("刷新图标")
      .disabled(store.isRefreshing || store.isBusy)
    }
    .padding(.horizontal, 12)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    .padding(MenuBarShelfLayout.compactInset)
  }

  @ViewBuilder private var content: some View {
    if store.isBusy {
      status("正在打开原应用菜单…")
    } else if !store.accessibilityAllowed {
      HStack(spacing: 8) {
        status("允许辅助功能后，即可查看和打开被遮挡的图标。")
        Button(String(appLocalized: "允许辅助功能…")) { store.requestAccessibility() }
      }
    } else if store.needsIconAccess {
      Button(String(appLocalized: "允许读取图标…")) { store.requestCapture() }
    } else if store.items.isEmpty {
      status(store.isRefreshing ? "正在查找被遮挡的图标…" : "当前没有被刘海遮挡的图标。")
    } else {
      ScrollView(.horizontal) {
        HStack(spacing: 4) {
          ForEach(store.items) { item in
            MenuBarShelfItemView(item: item, image: store.images[item.id], compact: true) { store.open(item) }
              .contextMenu {
                Button(String(appLocalized: "打开原应用菜单")) { store.open(item) }
                Button(String(appLocalized: "以右键打开原菜单")) { store.open(item, rightClick: true) }
              }
          }
        }
      }
      .scrollIndicators(.automatic)
    }
  }

  private func status(_ key: String.LocalizationValue) -> some View {
    Text(String(appLocalized: key)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
  }
}
