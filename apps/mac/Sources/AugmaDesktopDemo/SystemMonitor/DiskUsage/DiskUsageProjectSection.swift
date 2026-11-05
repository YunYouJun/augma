import AppKit
import SwiftUI

struct DiskUsageProjectSection: View {
  @ObservedObject var hub: CraftHubConnectionStore
  let node: DiskUsageNode?
  @State private var feedback = ""
  @State private var opening = false
  @State private var request: Task<Void, Never>?
  @State private var generation = UUID()

  var body: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 10) {
        Text("Augma 分析目录占用；Craft Hub 管理项目维护、命令审阅和执行记录。")
          .font(.caption).foregroundStyle(.secondary)
        if hub.connection != nil {
          Button("刷新共享项目") { request = Task { await hub.refresh() } }
            .disabled(hub.busy || opening)
        }
        if hub.connected, let node, let project = DiskUsageAdvice.matchingProject(node.url, projects: hub.projects) {
          Text(project.name).font(.headline)
          Button("在 Craft Hub 维护项目", systemImage: "arrow.up.forward.app") { open(project) }
            .disabled(opening || hub.busy)
        } else {
          Text(hub.connection == nil ? String(localized: "可在项目区域连接 Craft Hub；空间分析可独立使用。")
            : String(localized: "刷新共享项目后，进入匹配的项目目录即可打开维护入口。"))
            .font(.caption).foregroundStyle(.secondary)
        }
        if opening || hub.busy { ProgressView().controlSize(.small) }
        if !feedback.isEmpty { Text(feedback).font(.caption).foregroundStyle(.secondary) }
        if let error = hub.error { Text(error).font(.caption).foregroundStyle(.secondary) }
      }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
    } label: { Label("项目维护", systemImage: "folder.badge.gearshape").font(.headline) }
    .onChange(of: node?.id) { _, _ in cancel() }
    .onDisappear { cancel() }
  }

  private func open(_ project: CraftHubProject) {
    cancel(); opening = true; feedback = ""
    let generation = self.generation
    request = Task {
      do {
        let binding = try hub.binding(for: project.id)
        let context = try await hub.read(binding)
        guard !Task.isCancelled, self.generation == generation else { return }
        if let url = context.navigationURL(scheme: "craft-hub"),
          NSWorkspace.shared.urlForApplication(toOpen: url) != nil, NSWorkspace.shared.open(url) {
          if context.reference == nil {
            feedback = String(localized: "已打开 Craft Hub，请在工作台中选择此本地项目。")
          }
        } else { feedback = String(localized: "未找到 Craft Hub 桌面入口，请手动打开 Craft Hub 查看此项目。") }
      } catch {
        guard !Task.isCancelled, self.generation == generation else { return }
        feedback = error.localizedDescription
      }
      if self.generation == generation { opening = false }
    }
  }

  private func cancel() { generation = UUID(); request?.cancel(); request = nil; opening = false; feedback = "" }
}
