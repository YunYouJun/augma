import AppKit
import SwiftUI

struct CraftHubProjectPicker: View {
  @ObservedObject var projects: ProjectWorkspaceStore
  @ObservedObject private var hub: CraftHubConnectionStore
  let regionID: UUID?
  let onSelected: (UUID) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var configuration = ""
  @State private var editsConnection = false
  @State private var selectedID: String?
  @State private var selectionError: String?

  init(projects: ProjectWorkspaceStore, regionID: UUID? = nil, onSelected: @escaping (UUID) -> Void) {
    self.projects = projects; self.hub = projects.craftHub; self.regionID = regionID; self.onSelected = onSelected
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("选择 Craft Hub 项目").font(.title2.bold())
        Spacer()
        Button("关闭") { dismiss() }.keyboardShortcut(.cancelAction)
      }
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text("仅连接此 Mac 上明确共享的项目。绑定后复用项目资料，布局、工作网址和应用选择继续保存在 Augma。")
            .font(.callout).foregroundStyle(.secondary)
          HStack {
            Label(hub.connected ? String(localized: "已连接 · 只读") : String(localized: "尚未连接"),
                  systemImage: hub.connected ? "checkmark.shield" : "link")
            Spacer()
            if hub.connection != nil {
              Button("重新连接") { Task { await hub.refresh() } }.disabled(hub.busy)
              Button("断开连接") { hub.disconnect(); selectedID = nil }
                .accessibilityIdentifier("craft-hub-disconnect")
            }
            Button("连接设置") { editsConnection.toggle() }
          }
          if !hub.connected || editsConnection {
            VStack(alignment: .leading, spacing: 8) {
              Text("在 Craft Hub 的「设置 → Agent 连接」选择项目，启用只读访问，然后复制 JSON 配置到这里。无需启用插件读取。")
                .font(.callout)
              TextEditor(text: $configuration).font(.system(.caption, design: .monospaced)).frame(height: 120)
                .accessibilityLabel("Craft Hub JSON 连接配置").accessibilityIdentifier("craft-hub-configuration")
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
              Button("连接并读取项目") {
                Task {
                  if await hub.connect(json: configuration) { configuration = ""; editsConnection = false; selectedID = nil }
                }
              }.disabled(hub.busy || configuration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("craft-hub-connect")
            }
          }
          if hub.busy { ProgressView("正在读取共享项目…").controlSize(.small) }
          if let error = hub.error { Text(error).font(.callout).foregroundStyle(.orange).textSelection(.enabled) }
          if hub.connected {
            if hub.projects.isEmpty {
              ContentUnavailableView("没有共享项目", systemImage: "folder", description: Text("在 Craft Hub 中选择允许读取的项目，再重新连接。"))
            } else {
              List(hub.projects, selection: $selectedID) { project in
                VStack(alignment: .leading, spacing: 4) {
                  Text(project.name)
                  Text(project.path).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }.tag(project.id)
              }.frame(height: 180).accessibilityIdentifier("craft-hub-project-list")
            }
            if let selectedID, let context = hub.contexts[selectedID] {
              Text(String(format: String(localized: "%lld 个命令 · %lld 个技能"),
                          context.capabilities.filter { $0.kind == "command" }.count,
                          context.capabilities.filter { $0.kind == "skill" }.count)).font(.callout).foregroundStyle(.secondary)
            }
          }
          if let selectionError { Text(selectionError).font(.callout).foregroundStyle(.orange) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      HStack {
        Text("连接不会运行项目命令，也不会授予项目信任。")
          .font(.caption).foregroundStyle(.secondary)
        Spacer()
        Button(regionID == nil ? String(localized: "添加项目区域") : String(localized: "绑定所选项目"), action: selectProject)
          .buttonStyle(.borderedProminent)
          .fixedSize(horizontal: true, vertical: false)
          .disabled(!projects.editable || !hub.connected || selectedID.flatMap { hub.contexts[$0] } == nil)
          .accessibilityIdentifier("craft-hub-bind")
      }
    }
    .padding(NativePageLayout.pagePadding).frame(width: 590)
    .frame(minHeight: 480, idealHeight: 620, maxHeight: 700)
    .controlSize(.regular)
    .task { if !hub.connected, hub.connection != nil { await hub.refresh() } }
    .task(id: "\(hub.connection?.sourceID ?? "")/\(hub.connected)/\(selectedID ?? "")") {
      selectionError = nil
      guard let selectedID, hub.connected else { return }
      do { try await hub.read(hub.binding(for: selectedID)) }
      catch { if !Task.isCancelled { selectionError = error.localizedDescription } }
    }
  }

  private func selectProject() {
    guard let selectedID else { return }
    do {
      let binding = try hub.binding(for: selectedID)
      let id: UUID?
      if let regionID { projects.bind(regionID, to: binding); id = projects.error == nil ? regionID : nil }
      else { id = projects.add(binding: binding) }
      guard let id else {
        selectionError = projects.saveError ?? projects.error
        return
      }
      onSelected(id); dismiss()
    } catch { selectionError = error.localizedDescription }
  }
}

struct CraftHubBindingSection: View {
  @ObservedObject var projects: ProjectWorkspaceStore
  @ObservedObject private var hub: CraftHubConnectionStore
  let region: ProjectRegion
  @State private var choosing = false
  @State private var navigationError: String?
  init(projects: ProjectWorkspaceStore, region: ProjectRegion) {
    self.projects = projects; self.hub = projects.craftHub; self.region = region
  }

  var body: some View {
    Section("Craft Hub 项目（可选）") {
      if let binding = region.craftHub {
        if let context = hub.context(for: binding) {
          VStack(alignment: .leading, spacing: 4) {
            Text("项目").font(.caption).foregroundStyle(.secondary)
            Text(context.project.name).fixedSize(horizontal: false, vertical: true)
          }
          Text(context.project.path).font(.callout).textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("craft-hub-project-path")
          Label(context.project.trust == "trusted" ? String(localized: "已在 Craft Hub 信任") : String(localized: "尚未在 Craft Hub 信任"), systemImage: "shield")
            .font(.caption).foregroundStyle(.secondary)
          ForEach(Array(context.capabilities.prefix(8).enumerated()), id: \.offset) { _, capability in
            Label(capability.name, systemImage: capability.kind == "skill" ? "sparkles" : "terminal")
              .font(.callout).lineLimit(2)
          }
          Text(String(format: String(localized: "%lld 个命令 · %lld 个技能"),
                      context.capabilities.filter { $0.kind == "command" }.count,
                      context.capabilities.filter { $0.kind == "skill" }.count)).font(.caption).foregroundStyle(.secondary)
          Button("在 Craft Hub 中查看", action: openCraftHub).accessibilityIdentifier("craft-hub-open")
        } else {
          Label("绑定项目当前不可用", systemImage: "link.badge.plus").foregroundStyle(.secondary)
          Text(hub.error ?? (hub.connected && hub.connection?.sourceID == binding.sourceID
            ? CraftHubError.notShared.localizedDescription : CraftHubError.disconnected.localizedDescription)).font(.caption)
        }
        ViewThatFits(in: .horizontal) {
          HStack(spacing: NativePageLayout.itemSpacing) { bindingActions }
            .fixedSize(horizontal: true, vertical: false)
          VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) { bindingActions }
        }
        Button("解除绑定，使用本地配置") { projects.unlink(region.id) }
          .disabled(!projects.editable).accessibilityIdentifier("craft-hub-unlink")
        Text("解除绑定会恢复区域原来的名称和项目文件夹，保留应用、网址与布局。")
          .font(.caption).foregroundStyle(.secondary)
      } else {
        Text("独立使用本地项目；也可选择 Craft Hub 已共享的项目。")
          .font(.callout).foregroundStyle(.secondary)
        Button("绑定 Craft Hub 项目…") { choosing = true }.disabled(!projects.editable)
          .accessibilityIdentifier("craft-hub-choose")
      }
      if let navigationError { Text(navigationError).foregroundStyle(.orange) }
    }
    .sheet(isPresented: $choosing) { CraftHubProjectPicker(projects: projects, regionID: region.id) { _ in } }
    .task(id: "\(region.craftHub?.projectID ?? "")/\(region.craftHub?.sourceID ?? "")/\(hub.connected)") {
      if hub.connected { await projects.refreshBinding(region.id) }
    }
  }

  @ViewBuilder private var bindingActions: some View {
    Button("刷新项目资料") { Task { await projects.refreshBinding(region.id) } }
      .disabled(!hub.connected || hub.busy)
    Button("更换绑定…") { choosing = true }.disabled(!projects.editable)
  }

  private func openCraftHub() {
    guard let context = hub.context(for: region.craftHub) else { return }
    for scheme in ["craft-hub-native", "craft-hub"] {
      if let url = context.navigationURL(scheme: scheme), NSWorkspace.shared.urlForApplication(toOpen: url) != nil,
        NSWorkspace.shared.open(url) { navigationError = nil; return }
    }
    navigationError = String(localized: "未找到 Craft Hub 桌面入口，请手动打开 Craft Hub 查看此项目。")
  }
}
