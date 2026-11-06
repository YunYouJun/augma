import SwiftUI

struct ApplicationMarketView: View {
  @ObservedObject var store: ApplicationMarketStore
  @ObservedObject var dock: NativeDockStore
  @ObservedObject var plugins: AugmaPluginStore
  let select: (DemoModule) -> Void
  let openPlugin: (String) -> Void

  var body: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 12) {
        Label("Augma Link", systemImage: "puzzlepiece.extension").font(.title2.bold())
        Text("扩展中心").font(.callout).foregroundStyle(.secondary)
        Picker("扩展类型", selection: $store.section) {
          ForEach(AugmaLinkSection.allCases) { section in Text(section.title).tag(section) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("augma-link-section")
      }
      .padding()
      Divider()
      switch store.section {
      case .tools: ApplicationToolsView(store: store)
      case .extensions: AugmaExtensionCatalogView(dock: dock, select: select)
      case .plugins: AugmaPluginManagerView(plugins: plugins, dock: dock, open: openPlugin)
      }
    }
  }
}
