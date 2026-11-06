import AppKit
import SwiftUI

struct AugmaPluginManagerView: View {
  @ObservedObject var plugins: AugmaPluginStore
  @ObservedObject var dock: NativeDockStore
  let open: (String) -> Void
  @State private var query = ""
  @State private var removing: AugmaPluginInstallation?

  private var filtered: [AugmaPluginInstallation] {
    plugins.installations.filter { query.isEmpty || $0.manifest.displayName.localizedStandardContains(query) || $0.id.localizedStandardContains(query) }
  }

  var body: some View {
    NativePage {
      Text("从在线目录或本地文件夹安装插件，为 Augma 添加独立的小工具。")
        .font(.callout).foregroundStyle(.secondary)
      HStack {
        Spacer()
        Button("从文件夹安装…", systemImage: "plus") { choosePackage() }
          .disabled(!plugins.loaded || plugins.busy).fixedSize()
          .accessibilityIdentifier("augma-plugin-import")
      }
      if let progress = plugins.downloadProgress {
        VStack(alignment: .leading, spacing: 8) {
          ProgressView(value: Double(progress.bytes), total: Double(max(1, progress.total)))
          HStack {
            Text(String(format: String(appLocalized: "正在下载插件：%@ / %@"),
              ByteCountFormatter.string(fromByteCount: Int64(progress.bytes), countStyle: .file),
              ByteCountFormatter.string(fromByteCount: Int64(progress.total), countStyle: .file))).font(.caption)
            Spacer()
            Button("取消下载") { plugins.cancelDownload() }.accessibilityIdentifier("augma-plugin-download-cancel")
          }
        }
      } else if plugins.busy { ProgressView("正在更新插件…").controlSize(.small) }
      if !plugins.error.isEmpty {
        Text(plugins.error).font(.callout).foregroundStyle(.red).textSelection(.enabled)
        Button("重试", systemImage: "arrow.clockwise") { Task { await plugins.retry() } }.disabled(plugins.busy)
      }
      AugmaPluginOnlineCatalogView(plugins: plugins, catalog: plugins.catalog)
      Divider()
      Label("已安装插件", systemImage: "puzzlepiece.extension").font(.headline)
      TextField("搜索已安装插件", text: $query).textFieldStyle(.roundedBorder).accessibilityIdentifier("augma-plugin-search")
      if filtered.isEmpty && plugins.loaded {
        ContentUnavailableView("暂无已安装插件", systemImage: "puzzlepiece.extension",
          description: Text("安装呼吸环示例，或选择包含 augma-plugin.json 的插件文件夹。"))
      }
      LazyVStack(spacing: 12) {
        ForEach(filtered) { installation in pluginRow(installation) }
      }
      if plugins.installation("org.augma.examples.breathing-orbit") == nil {
        Divider()
        Text("离线示例").font(.headline)
        exampleCard
      }
    }
    .task { await plugins.load() }
    .confirmationDialog("卸载插件？", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
      titleVisibility: .visible, presenting: removing) { plugin in
      Button("卸载", role: .destructive) { removing = nil; Task { await plugins.uninstall(plugin.id) } }
        .accessibilityIdentifier("augma-plugin-confirm-uninstall")
    } message: { plugin in
      Text(String(format: String(appLocalized: "将移除 %@ 的安装文件、运行页面和 Dock 入口。原始插件文件夹会保留。"), plugin.manifest.displayName))
    }
  }

  private var exampleCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("呼吸环 · Breathing Orbit", systemImage: "circle.dotted.circle").font(.headline)
      Text("跟随圆环吸气、呼气。独立的本地 HTML / CSS / JavaScript 示例，无需账号。")
        .font(.callout).foregroundStyle(.secondary)
      Text("安装后保持停用，由你选择启用。")
        .font(.caption).foregroundStyle(.secondary)
      Button("安装示例插件", systemImage: "arrow.down.circle") {
        if let source = AugmaPluginStore.exampleURL { Task { await plugins.install(from: source) } }
      }
      .disabled(!plugins.loaded || plugins.busy || AugmaPluginStore.exampleURL == nil)
      .accessibilityIdentifier("augma-plugin-install-example")
    }.nativeCard()
  }

  private func pluginRow(_ installation: AugmaPluginInstallation) -> some View {
    let manifest = installation.manifest
    return VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        Image(systemName: manifest.symbol).font(.title2).foregroundStyle(Color.augmaCyan)
          .frame(width: 40, height: 40).accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 4) {
          Text(manifest.displayName).font(.headline)
          Text(manifest.displaySummary).font(.callout).foregroundStyle(.secondary)
          Text(manifest.author + " · " + manifest.version).font(.caption).foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
      }
      Label(installation.enabled ? "已启用" : "已停用", systemImage: installation.enabled ? "checkmark.circle" : "pause.circle")
        .font(.caption).foregroundStyle(.secondary)
      if let problem = installation.problem { Text(problem).font(.caption).foregroundStyle(.red) }
      ViewThatFits(in: .horizontal) {
        HStack { primaryActions(installation); Spacer(); uninstallButton(installation) }
        VStack(alignment: .leading, spacing: 10) { primaryActions(installation); uninstallButton(installation) }
      }
    }
    .nativeCard()
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("augma-plugin-" + installation.id)
  }

  private func primaryActions(_ plugin: AugmaPluginInstallation) -> some View {
    HStack {
      if plugin.enabled {
        Button("停用", systemImage: "pause") { Task { await plugins.setEnabled(plugin.id, enabled: false) } }
          .disabled(plugins.busy).accessibilityIdentifier("augma-plugin-disable-" + plugin.id)
      } else {
        Button("启用", systemImage: "play") { Task { await plugins.setEnabled(plugin.id, enabled: true) } }
          .disabled(plugins.busy || plugin.problem != nil).accessibilityIdentifier("augma-plugin-enable-" + plugin.id)
      }
      if plugin.enabled && plugin.problem == nil {
        Button("打开", systemImage: "arrow.up.forward.app") { open(plugin.id) }.disabled(plugins.busy)
          .accessibilityIdentifier("augma-plugin-open-" + plugin.id)
        Button("加入 Dock", systemImage: "plus") { plugins.pin(plugin.id) }
          .disabled(plugins.busy || dock.items.contains { $0.plugin?.id == plugin.id })
          .help("加入 Dock")
          .accessibilityIdentifier("augma-plugin-pin-" + plugin.id)
      }
    }
  }

  private func uninstallButton(_ plugin: AugmaPluginInstallation) -> some View {
    Button("卸载…", systemImage: "trash") { removing = plugin }.disabled(plugins.busy)
      .accessibilityIdentifier("augma-plugin-uninstall-" + plugin.id)
  }

  private func choosePackage() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
    panel.treatsFilePackagesAsDirectories = true
    panel.message = String(appLocalized: "选择包含 augma-plugin.json 的插件文件夹。")
    panel.begin { response in
      if response == .OK, let url = panel.url { Task { await plugins.install(from: url) } }
    }
  }
}

struct AugmaPluginPanel: View {
  @ObservedObject var plugins: AugmaPluginStore
  let id: String?
  let showLink: () -> Void

  var body: some View {
    if let id, let package = plugins.enabledPackage(id) {
      VStack(spacing: 0) {
        HStack {
          Label(package.manifest.displayName, systemImage: package.manifest.symbol).font(.headline)
          Spacer()
          Button("管理插件", systemImage: "puzzlepiece.extension", action: showLink)
            .accessibilityIdentifier("augma-plugin-manage")
        }.padding(14)
        Divider()
        AugmaPluginWebView(package: package).id(id)
      }
    } else {
      ContentUnavailableView {
        Label("插件不可用", systemImage: "puzzlepiece.extension")
      } actions: { Button("管理插件", action: showLink) }
    }
  }
}
