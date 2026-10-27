import AppKit
import SwiftUI

struct DiskCleanupPlanView: View {
  let plan: DiskCleanupPlan
  @ObservedObject var store: ApplicationMarketStore

  var body: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        Text(plan.summary).textSelection(.enabled)
        Text(String(format: String(localized: "计划候选约 %@ · 已按规则保留 %lld 项"),
                    SystemMetricFormat.bytes(plan.bytes, style: .file), plan.protectedCount)).font(.headline)
        if let target = plan.goal.targetBytes {
          Text(String(format: String(localized: "目标 %@ · 候选差额 %@（估算，尚未释放）"),
                      SystemMetricFormat.bytes(target, style: .file), SystemMetricFormat.bytes(target > plan.bytes ? target - plan.bytes : 0, style: .file)))
            .font(.callout).monospacedDigit()
        }
        Text("当前仅允许处理下载目录顶层至少 7 天未修改的 dmg / pkg / xip 安装包。其他占用只供查看，不会自动删除。")
          .font(.caption).foregroundStyle(.secondary)
        if plan.scanIncomplete || plan.occupancy.incomplete {
          Label("部分目录无法读取或已达到扫描上限，结果不完整；未完整检查的项目不会列出。", systemImage: "info.circle")
            .font(.caption).foregroundStyle(.secondary)
        }
        if plan.candidates.isEmpty {
          Text("保留规则下没有可执行候选。可选择更小目录重新扫描，或在 Finder 中检查其他占用。")
            .foregroundStyle(.secondary)
        }
        ForEach(plan.candidates) { candidate in
          HStack(alignment: .top, spacing: NativePageLayout.itemSpacing) {
            Toggle(isOn: Binding(get: { store.selection.contains(candidate.id) }, set: { selected in
              if selected { store.selection.insert(candidate.id) } else { store.selection.remove(candidate.id) }
            })) {
              VStack(alignment: .leading, spacing: 3) {
                Text(candidate.url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                Text(candidate.category.title + " · " + SystemMetricFormat.bytes(candidate.bytes, style: .file))
                  .font(.caption).foregroundStyle(.secondary)
                Text(candidate.url.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
              }
            }
            .toggleStyle(.checkbox).disabled(store.isBusy)
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(candidate.url.path)
            Button("在 Finder 中显示", systemImage: "folder") { NSWorkspace.shared.activateFileViewerSelecting([candidate.url]) }
              .labelStyle(.iconOnly).help("在 Finder 中显示")
              .controlSize(.small)
          }
        }
        Text(String(format: String(localized: "已选 %lld 项 · %@"), store.selectedCandidates.count,
                    SystemMetricFormat.bytes(store.selectedCandidates.reduce(0) { $0 + $1.bytes }, style: .file))).font(.callout)
        if !plan.occupancy.entries.isEmpty {
          DisclosureGroup("磁盘占用（仅查看）") {
            VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
              ForEach(plan.occupancy.entries.prefix(10)) { entry in
                HStack {
                  Text(entry.name).lineLimit(1).truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                  Spacer(minLength: 8)
                  Text(entry.complete ? SystemMetricFormat.bytes(entry.size, style: .file)
                       : entry.size > 0 ? SystemMetricFormat.bytes(entry.size, style: .file) + "+" : "—")
                    .monospacedDigit().fixedSize(horizontal: true, vertical: false)
                  Button("在 Finder 中显示", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: entry.path)])
                  }.labelStyle(.iconOnly).help(entry.path)
                    .controlSize(.small)
                }
              }
            }.padding(.top, 8)
          }
        }
      }.padding(NativePageLayout.itemSpacing).frame(maxWidth: .infinity, alignment: .leading)
    } label: { Label(plan.usedAI ? "AI 已调整计划" : "本地清理计划", systemImage: "list.bullet.clipboard").font(.headline) }
  }
}
