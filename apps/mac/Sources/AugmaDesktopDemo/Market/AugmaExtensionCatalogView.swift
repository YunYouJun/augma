import SwiftUI

struct AugmaExtensionCatalogView: View {
  @ObservedObject var dock: NativeDockStore
  let select: (DemoModule) -> Void
  @State private var query = ""
  @State private var onlyPinned = false

  private var extensions: [AugmaExtension] {
    AugmaExtension.catalog.filter {
      $0.matches(query) && (!onlyPinned || dock.items.contains(NativeDockItem(module: $0.module)))
    }
  }

  var body: some View {
    NativePage {
      Text("探索 Augma 的功能，将常用入口固定到 Dock。")
        .font(.callout).foregroundStyle(.secondary)
      TextField("搜索 Augma 扩展", text: $query).textFieldStyle(.roundedBorder)
        .accessibilityIdentifier("augma-link-search")
      Toggle("仅显示已加入 Dock", isOn: $onlyPinned).toggleStyle(.checkbox)
      if extensions.isEmpty {
        ContentUnavailableView("没有找到扩展", systemImage: "puzzlepiece.extension",
          description: Text("试试其他关键词，或关闭 Dock 筛选。"))
      }
      LazyVStack(spacing: 10) {
        ForEach(extensions) { entry in extensionRow(entry) }
      }
      Text("内置功能随 Augma 提供；第三方插件可在“插件”中管理。")
        .font(.caption).foregroundStyle(.secondary)
    }
  }

  private func extensionRow(_ entry: AugmaExtension) -> some View {
    let item = NativeDockItem(module: entry.module)
    let pinned = dock.items.contains(item)
    return VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        Image(systemName: entry.module.symbol).font(.title2).foregroundStyle(Color.augmaCyan)
          .frame(width: 40, height: 40).accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 3) {
          Text(entry.title).font(.headline)
          Text(entry.detail).font(.caption).foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
        Text("内置").font(.caption).foregroundStyle(.secondary)
      }
      HStack {
        Button("打开", systemImage: "arrow.up.forward.app") { select(entry.module) }
        Spacer(minLength: 8)
        if pinned {
          Button("从 Dock 中移除", systemImage: "minus.circle") { dock.remove(item) }
        } else {
          Button("加入 Dock", systemImage: "plus") { dock.restore(item) }
            .help("加入 Dock")
        }
      }
    }
    .nativeCard()
    .accessibilityIdentifier("augma-extension-" + entry.id)
  }
}
