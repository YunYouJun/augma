import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ProjectRegionSections: View {
  @ObservedObject var space: NativeSpaceStore
  @ObservedObject private var projects: ProjectWorkspaceStore
  @State private var confirmsRebuild = false
  @State private var choosingCraftHub = false
  init(space: NativeSpaceStore) { self.space = space; projects = space.projects }
  private var selected: ProjectRegion? { projects.regions.first { $0.id == space.selectedProjectID } ?? projects.regions.first }

  var body: some View {
    Group {
      Section("项目区域") {
        Button("添加项目文件夹…", systemImage: "folder.badge.plus") {
          ProjectWorkspacePanels.chooseFolder { url in
            if let id = projects.add(folderURL: url) { space.selectedProjectID = id }
          }
        }
        .disabled(!projects.editable || projects.regions.count >= ProjectRegion.capacity)
        .accessibilityIdentifier("project-add-folder")
        Button("从 Craft Hub 添加…", systemImage: "link") { choosingCraftHub = true }
          .disabled(!projects.editable || projects.regions.count >= ProjectRegion.capacity)
          .accessibilityIdentifier("project-add-craft-hub")
        if projects.regions.isEmpty {
          Text("把项目文件夹、VS Code 和工作网址放在同一个区域。")
            .font(.callout).foregroundStyle(.secondary)
        }
        ForEach(projects.regions.sorted { $0.slot < $1.slot }) { region in
          Button {
            space.selectedProjectID = region.id
          } label: {
            Label {
              VStack(alignment: .leading, spacing: 3) {
                Text(projects.displayName(region)).fontWeight(selected?.id == region.id ? .semibold : .regular)
                Text(String(format: String(localized: "%lld 个工作网址"), region.websites.count)).font(.caption).foregroundStyle(.secondary)
              }.frame(maxWidth: .infinity, alignment: .leading)
            } icon: { Image(systemName: selected?.id == region.id ? "folder.fill" : "folder") }
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("project-select-" + region.id.uuidString)
        }
        Text(String(format: String(localized: "%lld / 6 个区域"), projects.regions.count)).font(.caption).foregroundStyle(.secondary)
        if projects.canUndoRemoval {
          Button("撤销移除区域", action: projects.undoRemoval).disabled(!projects.editable || projects.regions.count >= ProjectRegion.capacity)
        }
      }
      if let selected { ProjectRegionEditor(projects: projects, regionID: selected.id) }
      if let error = projects.error {
        Section {
          Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
          Button("知道了", action: projects.dismissError)
        }
      }
      Section("项目配置") {
        if let error = projects.loadError {
          Text(error).foregroundStyle(.orange)
          Button("重新读取项目配置", action: projects.reload)
          Button("重新建立项目区域…") { confirmsRebuild = true }
        } else if let error = projects.saveError {
          Label("项目配置尚未保存", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
          Text(error).font(.caption)
          Button("重试保存项目配置", action: projects.retrySave)
        } else if projects.hasUnsavedDrafts {
          Label("有尚未保存的配置", systemImage: "pencil.circle").foregroundStyle(.secondary)
        } else { Label("项目配置已保存在此 Mac", systemImage: "checkmark.circle").foregroundStyle(.secondary) }
        Text("主窗口与沉浸模式共享配置、编辑内容和打开结果。")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .sheet(isPresented: $choosingCraftHub) {
      CraftHubProjectPicker(projects: projects) { space.selectedProjectID = $0 }
    }
    .task {
      if projects.craftHub.connection != nil && !projects.craftHub.connected {
        await projects.craftHub.refresh()
      }
      for region in projects.regions { await projects.refreshBinding(region.id) }
    }
    .confirmationDialog("重新建立项目区域？", isPresented: $confirmsRebuild) {
      Button("备份原文件并重建", role: .destructive, action: projects.rebuildUnreadableConfiguration)
    } message: { Text("无法读取的配置会先备份，再建立空白项目区域。") }
  }
}

private struct ProjectRegionEditor: View {
  @ObservedObject var projects: ProjectWorkspaceStore
  let regionID: UUID
  private var region: ProjectRegion? { projects.regions.first { $0.id == regionID } }

  var body: some View {
    if let region {
      CraftHubBindingSection(projects: projects, region: region)
      Section("工作区入口") {
        if region.craftHub == nil {
          Text(region.folder.displayPath).font(.callout).textSelection(.enabled)
            .accessibilityIdentifier("project-folder-path")
          HStack {
            Button("在访达中查看") { projects.revealFolder(regionID) }
            Button("重新选择文件夹…") {
              ProjectWorkspacePanels.chooseFolder { projects.rebindFolder(regionID, url: $0) }
            }.disabled(!projects.editable)
          }
        } else {
          Text("打开工作区前会重新读取 Craft Hub 项目目录；工作网址和应用仍使用下方配置。")
            .font(.caption).foregroundStyle(.secondary)
        }
        applicationBinding(region.editor, title: "VS Code", editor: true)
        applicationBinding(region.browser, title: "Chrome", editor: false)
        Button("打开工作区", systemImage: "arrow.up.forward.app") { projects.open(regionID) }
          .buttonStyle(.borderedProminent).disabled(!projects.editable)
          .accessibilityIdentifier("project-open-workspace")
        Text("在 VS Code 新窗口中打开项目，并在 Chrome 中打开下方网址。网址请求交给浏览器后标记为已打开。")
          .font(.caption).foregroundStyle(.secondary)
      }
      if let report = projects.reports[regionID] {
        Section("打开结果") {
          ForEach(report.items) { item in
            HStack(alignment: .top) {
              Image(systemName: symbol(item.state)).foregroundStyle(tint(item.state))
              VStack(alignment: .leading, spacing: 3) {
                Text(item.title).lineLimit(2)
                Text(status(item.state)).font(.caption).foregroundStyle(.secondary)
              }
            }.accessibilityIdentifier("project-open-result-" + item.id)
          }
          if projects.openingID == regionID {
            Button("取消后续打开", action: projects.cancelOpening)
          } else if report.hasFailures {
            Button("仅重试失败项") { projects.open(regionID, failedOnly: true) }.disabled(!projects.editable)
          } else if report.items.contains(where: { $0.state == .cancelled }) {
            Button("继续未完成项") { projects.open(regionID, failedOnly: true) }.disabled(!projects.editable)
          }
        }
      }
      Section("编辑项目区域") {
        TextField("区域名称", text: draftBinding(\.name, region: region))
          .disabled(region.craftHub != nil)
          .accessibilityIdentifier("project-region-name")
        Text("工作网址（每行一个）")
        TextEditor(text: draftBinding(\.websites, region: region))
          .font(.body).frame(height: 110)
          .accessibilityLabel("工作网址（每行一个）").accessibilityIdentifier("project-websites")
        Text("支持 https:// 和 http://，包括 localhost；最多 10 个网址。")
          .font(.caption).foregroundStyle(.secondary)
        HStack {
          Button("保存配置") { projects.saveDraft(regionID) }.accessibilityIdentifier("project-save")
          if projects.draft(for: region) != ProjectRegionDraft(region) {
            Button("撤销配置编辑") { projects.discardDraft(regionID) }
          }
        }
        Picker("区域位置", selection: Binding(get: { region.slot }, set: { projects.move(regionID, to: $0) })) {
          ForEach(0..<ProjectRegion.capacity, id: \.self) { slot in
            Text(String(format: String(localized: "第 %lld 行 · 第 %lld 列"), slot / 3 + 1, slot % 3 + 1)).tag(slot)
          }
        }.accessibilityIdentifier("project-region-slot")
        Button("移除项目区域", role: .destructive) { projects.remove(regionID) }
          .accessibilityIdentifier("project-remove")
        Text("移除区域只删除绑定配置，项目文件保持原样。")
          .font(.caption).foregroundStyle(.secondary)
      }.disabled(!projects.editable)
    }
  }

  private func draftBinding(_ keyPath: WritableKeyPath<ProjectRegionDraft, String>, region: ProjectRegion) -> Binding<String> {
    Binding(get: { projects.draft(for: region)[keyPath: keyPath] }, set: {
      var draft = projects.draft(for: region); draft[keyPath: keyPath] = $0; projects.setDraft(regionID, draft)
    })
  }
  private func applicationBinding(_ app: ProjectApplication?, title: String, editor: Bool) -> some View {
    HStack {
      LabeledContent(title, value: app?.name ?? String(localized: "未选择应用"))
      Button("选择…") {
        ProjectWorkspacePanels.chooseApplication { projects.bindApplication(regionID, url: $0, editor: editor) }
      }
      .help(editor ? "选择 VS Code 应用" : "选择 Chrome 应用")
      .accessibilityIdentifier(editor ? "project-choose-editor" : "project-choose-browser")
      .disabled(!projects.editable)
    }
  }
  private func symbol(_ state: ProjectOpenState) -> String {
    switch state {
    case .waiting: "circle"
    case .opening: "hourglass"
    case .opened: "checkmark.circle.fill"
    case .failed: "exclamationmark.triangle"
    case .cancelled: "minus.circle"
    }
  }
  private func tint(_ state: ProjectOpenState) -> Color {
    switch state { case .opened: .green; case .failed: .orange; default: .secondary }
  }
  private func status(_ state: ProjectOpenState) -> String {
    switch state {
    case .waiting: String(localized: "等待打开")
    case .opening: String(localized: "正在打开…")
    case .opened: String(localized: "已打开")
    case .failed(let error): error
    case .cancelled: String(localized: "已取消后续打开")
    }
  }
}

@MainActor
private enum ProjectWorkspacePanels {
  static func chooseFolder(_ completion: @escaping (URL) -> Void) {
    let panel = NSOpenPanel()
    panel.title = String(localized: "选择项目文件夹")
    panel.canChooseDirectories = true; panel.canChooseFiles = false
    panel.allowsMultipleSelection = false; panel.canCreateDirectories = false
    panel.begin { if $0 == .OK, let url = panel.url { completion(url) } }
  }
  static func chooseApplication(_ completion: @escaping (URL) -> Void) {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.applicationBundle]
    panel.directoryURL = URL(fileURLWithPath: "/Applications")
    panel.canChooseDirectories = false; panel.canChooseFiles = true; panel.allowsMultipleSelection = false
    panel.begin { if $0 == .OK, let url = panel.url { completion(url) } }
  }
}
