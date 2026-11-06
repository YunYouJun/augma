import AppKit
import SwiftUI

struct DiskUsageView: View {
  @StateObject private var store: DiskUsageStore
  let hub: CraftHubConnectionStore?
  @Environment(\.dismiss) private var dismiss

  init(store: DiskUsageStore? = nil, hub: CraftHubConnectionStore? = nil) {
    _store = StateObject(wrappedValue: store ?? DiskUsageStore())
    self.hub = hub
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Label("空间分析", systemImage: "square.grid.3x3.square").font(.title2.weight(.semibold))
        Spacer()
        Button("完成") { store.cancel(); dismiss() }.keyboardShortcut(.cancelAction)
      }.padding(NativePageLayout.pagePadding)
      Divider()
      ScrollView {
        VStack(alignment: .leading, spacing: NativePageLayout.sectionSpacing) {
          controls
          if let snapshot = store.snapshot, let node = store.focusedNode {
            summary(snapshot)
            contents(node, snapshot: snapshot)
            if let hub { DiskUsageProjectSection(hub: hub, node: node) }
            DiskUsageRanking(node: node, metric: store.metric, focus: store.focus)
            advice(node)
            diagnostics(snapshot)
          } else if !store.scanning {
            ContentUnavailableView("选择目录，查看空间去向", systemImage: "externaldrive",
              description: Text("按需读取文件元数据，展示区块图与大目录排行。扫描结果仅保留在本次窗口中。"))
          }
          if store.snapshot == nil, let hub { DiskUsageProjectSection(hub: hub, node: nil) }
        }.nativePageContent()
      }
    }
    .frame(minWidth: 480, idealWidth: 780, minHeight: 600, idealHeight: 800)
    .onDisappear { store.cancel() }
  }

  private var controls: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("只读扫描所选目录，建议在本机生成。可定位文件和跳转项目维护。")
        .font(.callout).foregroundStyle(.secondary)
      ViewThatFits(in: .horizontal) {
        HStack { scanButtons; Spacer(); metricPicker }
        VStack(alignment: .leading, spacing: 8) { scanButtons; metricPicker }
      }
      if let root = store.root { Text(root.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
      if store.scanning {
        HStack {
          ProgressView().controlSize(.small)
          Text(String(format: String(appLocalized: "已检查 %lld 项 · 逻辑大小 %@"), store.progress.entries,
            SystemMetricFormat.bytes(store.progress.logicalBytes))).font(.caption).monospacedDigit()
          Button("取消") { store.cancel() }
        }.accessibilityElement(children: .contain)
      }
      if !store.feedback.isEmpty { Text(store.feedback).font(.callout).foregroundStyle(.secondary) }
    }
  }

  private var scanButtons: some View {
    HStack {
      Button("选择目录…", systemImage: "folder.badge.plus", action: chooseFolder)
        .accessibilityIdentifier("disk-usage-choose")
      if let root = store.root {
        Button("重新扫描", systemImage: "arrow.clockwise") { store.start(root) }.disabled(store.scanning)
      }
    }
  }

  private var metricPicker: some View {
    Picker("统计口径", selection: $store.metric) {
      ForEach(DiskUsageMetric.allCases, id: \.rawValue) { Text($0.title).tag($0) }
    }.pickerStyle(.segmented).frame(width: 220)
  }

  private func summary(_ scan: DiskUsageSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        Text((scan.root.incomplete ? "≥ " : "") + SystemMetricFormat.bytes(scan.root.bytes(store.metric)))
          .font(.largeTitle.weight(.semibold)).monospacedDigit()
        Spacer()
        Text(scan.checkedAt, format: .dateTime.hour().minute().second()).font(.caption).foregroundStyle(.secondary)
      }
      Text(String(format: String(appLocalized: "%lld 个文件 · 逻辑大小 %@ · 磁盘分配 %@"), scan.root.fileCount,
        SystemMetricFormat.bytes(scan.root.logicalBytes), SystemMetricFormat.bytes(scan.root.allocatedBytes)))
        .font(.caption).foregroundStyle(.secondary)
      if scan.root.incomplete {
        Label("结果不完整，未读取部分的占用未知。", systemImage: "info.circle").font(.callout)
      }
      Text("逻辑大小是文件长度；磁盘分配按文件块统计，不含目录自身开销。共享数据、快照和云端文件会影响差异，这些数字不代表可释放空间。")
        .font(.caption).foregroundStyle(.secondary)
    }
  }

  private func contents(_ node: DiskUsageNode, snapshot: DiskUsageSnapshot) -> some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Button("上一级", systemImage: "arrow.up") { store.goUp() }.disabled(node.id == snapshot.root.id)
          if node.id != snapshot.root.id { Button("扫描根目录") { store.focus(snapshot.root) } }
          Spacer()
          DiskUsageRevealButton(url: node.url)
        }
        Text(node.url.path).font(.caption).textSelection(.enabled).lineLimit(3).truncationMode(.middle)
        if node.children.contains(where: { $0.bytes(store.metric) > 0 }) {
          DiskUsageTreemap(node: node, metric: store.metric) { entry in
            if entry.isDirectory { store.focus(entry) }
            else { NSWorkspace.shared.activateFileViewerSelecting([entry.url]) }
          }
          Text("点击目录区块下钻，点击文件在 Finder 中显示；小项目合并展示。")
            .font(.caption).foregroundStyle(.secondary)
        } else {
          Text(node.incomplete ? String(appLocalized: "此目录尚未完整读取。") : String(appLocalized: "当前统计口径下没有已测得占用的项目。"))
            .foregroundStyle(.secondary)
        }
        ForEach(Array(node.children.sorted {
          $0.bytes(store.metric) == $1.bytes(store.metric) ? $0.id < $1.id : $0.bytes(store.metric) > $1.bytes(store.metric)
        }.prefix(20))) { entry in
          DiskUsageEntryRow(node: entry, metric: store.metric) { store.focus(entry) }
        }
        if node.children.count > 20 { Text("此处显示占用最大的 20 项，可选择更具体的目录重新扫描。").font(.caption).foregroundStyle(.secondary) }
      }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
    } label: { Label("空间占用区块图", systemImage: "square.grid.3x3.square").font(.headline) }
  }

  private func advice(_ node: DiskUsageNode) -> some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        Text("按占用排序的检查建议；预计可释放量尚未评估。")
          .font(.caption).foregroundStyle(.secondary)
        ForEach(DiskUsageAdvice.suggestions(for: node, metric: store.metric)) { advice in
          VStack(alignment: .leading, spacing: 5) {
            DiskUsageEntryRow(node: advice.node, metric: store.metric) { store.focus(advice.node) }
            Text(advice.message).font(.caption).foregroundStyle(.secondary)
          }
        }
      }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
    } label: { Label("清理建议（只读）", systemImage: "lightbulb").font(.headline) }
  }

  private func diagnostics(_ scan: DiskUsageSnapshot) -> some View {
    DisclosureGroup("扫描范围与统计说明") {
      VStack(alignment: .leading, spacing: 8) {
        Text("不跟随符号链接，不跨磁盘卷；同一硬链接文件仅计入首次遇到的目录。云端文件仅读取元数据，不主动下载内容。")
        Text(String(format: String(appLocalized: "已跳过 %lld 个符号链接、%lld 个重复文件和 %lld 个特殊文件。"),
          scan.skippedSymlinks, scan.duplicateFiles, scan.skippedSpecialFiles))
        Text("每次最多检查 50,000 个条目、48 层目录，时间预算为 8 秒；单次系统调用可能延长等待。")
        ForEach(scan.issues) { issue in
          Text(issue.reason.title + " · " + issue.path).textSelection(.enabled)
        }
        if scan.omittedIssues > 0 { Text(String(format: String(appLocalized: "另有 %lld 条未显示的范围提示。"), scan.omittedIssues)) }
      }.font(.caption).foregroundStyle(.secondary).padding(.top, 8)
    }
  }

  private func chooseFolder() {
    let panel = NSOpenPanel()
    panel.title = String(appLocalized: "选择空间分析目录")
    panel.canChooseDirectories = true; panel.canChooseFiles = false
    panel.allowsMultipleSelection = false; panel.canCreateDirectories = false
    panel.begin { response in
      if response == .OK, let url = panel.url { store.start(url) }
    }
  }
}
