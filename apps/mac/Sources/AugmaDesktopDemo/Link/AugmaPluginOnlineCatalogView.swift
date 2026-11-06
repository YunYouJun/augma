import SwiftUI

struct AugmaPluginOnlineCatalogView: View {
  @ObservedObject var plugins: AugmaPluginStore
  @ObservedObject var catalog: AugmaPluginCatalogStore
  @State private var query = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("在线插件目录", systemImage: "globe").font(.headline)
        Spacer()
        Button("刷新目录", systemImage: "arrow.clockwise") { Task { await catalog.refresh() } }
          .disabled(catalog.refreshing).accessibilityIdentifier("augma-plugin-catalog-refresh")
      }
      TextField("搜索在线插件", text: $query).textFieldStyle(.roundedBorder)
        .accessibilityIdentifier("augma-plugin-catalog-search")
      Link(String(format: String(appLocalized: "目录来源：%@"), catalog.client.source.host ?? ""), destination: catalog.client.source)
        .font(.caption).foregroundStyle(.secondary)
      if catalog.refreshing { ProgressView("正在查询插件目录…").controlSize(.small) }
      if !catalog.error.isEmpty { Text(catalog.error).font(.callout).foregroundStyle(.red) }
      if catalog.loaded && catalog.matches(query).isEmpty && !catalog.refreshing {
        Text("没有找到匹配的在线插件。可以更换关键词或刷新目录。")
          .font(.callout).foregroundStyle(.secondary)
      }
      ForEach(catalog.matches(query)) { entry in
        VStack(alignment: .leading, spacing: 12) {
          Label(entry.manifest.displayName, systemImage: entry.manifest.symbol).font(.headline)
          Text(entry.manifest.displaySummary).font(.callout).foregroundStyle(.secondary)
          Text(entry.manifest.author + " · " + entry.manifest.version).font(.caption).foregroundStyle(.secondary)
          HStack {
            Text(ByteCountFormatter.string(fromByteCount: Int64(entry.size), countStyle: .file))
              .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button(plugins.installation(entry.id) == nil ? "下载并安装" : "已安装",
                   systemImage: plugins.installation(entry.id) == nil ? "arrow.down.circle" : "checkmark.circle") { plugins.install(entry) }
              .disabled(!plugins.loaded || plugins.busy || plugins.installation(entry.id) != nil)
              .accessibilityIdentifier("augma-plugin-download-" + entry.id)
          }
          Text("下载后校验完整性，安装完成后由你选择启用。")
            .font(.caption).foregroundStyle(.secondary)
        }.nativeCard().accessibilityElement(children: .contain)
      }
    }
    .task { if !catalog.loaded { await catalog.refresh() } }
  }
}
