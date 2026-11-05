import AppKit
import SwiftUI

struct DiskUsageRanking: View {
  let node: DiskUsageNode
  let metric: DiskUsageMetric
  let focus: (DiskUsageNode) -> Void

  var body: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 10) {
        Text("当前目录下的大目录，包含嵌套目录；父子目录的占用不能相加。")
          .font(.caption).foregroundStyle(.secondary)
        let ranked = node.largestDirectories(metric: metric)
        if ranked.isEmpty { Text("没有已读取的子目录。").foregroundStyle(.secondary) }
        ForEach(ranked) { entry in
          VStack(alignment: .leading, spacing: 3) {
            DiskUsageEntryRow(node: entry, metric: metric) { focus(entry) }
            Text(String(entry.id.dropFirst(node.id == "/" ? 1 : node.id.count + 1)))
              .font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
          }
        }
      }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
    } label: { Label("大目录排行", systemImage: "chart.bar.xaxis").font(.headline) }
  }
}

struct DiskUsageEntryRow: View {
  let node: DiskUsageNode
  let metric: DiskUsageMetric
  let focus: () -> Void

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      if node.isDirectory {
        Button(action: focus) { Label(node.url.lastPathComponent, systemImage: "folder") }
          .buttonStyle(.link).lineLimit(1).truncationMode(.middle)
      } else { Label(node.url.lastPathComponent, systemImage: "doc").lineLimit(1).truncationMode(.middle) }
      Spacer(minLength: 8)
      Text((node.incomplete ? "≥ " : "") + SystemMetricFormat.bytes(node.bytes(metric)))
        .font(.callout).monospacedDigit().fixedSize()
      DiskUsageRevealButton(url: node.url)
    }.help(node.url.path)
  }
}

struct DiskUsageRevealButton: View {
  let url: URL
  var body: some View {
    Button("在 Finder 中显示", systemImage: "arrow.up.forward.square") {
      NSWorkspace.shared.activateFileViewerSelecting([url])
    }.labelStyle(.iconOnly).help("在 Finder 中显示").controlSize(.small)
  }
}
