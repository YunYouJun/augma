import AppKit
import SwiftUI

struct CraftHubCompanionSection: View {
  @ObservedObject var store: CraftHubCompanionStore
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label("Craft Hub · 今日重点", systemImage: "checklist")
        Spacer()
        Button("打开主界面", systemImage: "arrow.up.forward.app") { Task { await store.openMain() } }
          .accessibilityIdentifier("craft-hub-open-main")
      }
      if let summary = store.summary {
        ForEach(summary.items) { item in
          VStack(alignment: .leading, spacing: 2) {
            Text(item.title).lineLimit(2)
            Text(item.sourceTitle).font(.caption).foregroundStyle(.secondary)
          }
        }
        if summary.items.isEmpty { Text("此次读取未发现待办事项。").font(.callout).foregroundStyle(.secondary) }
        if let date = summary.date {
          Text(String(format: String(appLocalized: "缓存更新于 %@"), date.formatted(.dateTime.locale(NativeLocalization.locale))))
            .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("craft-hub-summary-time")
        }
        Text(String(format: String(appLocalized: "已读取 %lld/%lld 个来源 · %lld 项；打开 Craft Hub 查看最新内容。"), summary.loadedSourceCount, summary.sourceCount, summary.total))
          .font(.caption).foregroundStyle(.secondary)
      } else {
        Text("在 Craft Hub 的应用菜单选择“共享今日重点摘要…”，再选择该文件。")
          .font(.caption).foregroundStyle(.secondary)
      }
      if let error = store.error { Text(error).font(.caption).foregroundStyle(.orange).textSelection(.enabled) }
      HStack {
        Button("选择摘要…", action: store.chooseSummary)
        if store.summaryPath != nil {
          Button("重新读取", action: store.refresh)
          Button("断开", action: store.disconnect)
        }
        Spacer()
        Button("选择主应用…", action: store.chooseApplication)
      }.font(.caption)
    }
    .task { store.refresh() }
  }
}

/// The menu and floating capture window edit the same document and use the existing durable delivery flow.
struct QuickCaptureUtilityView: View {
  @ObservedObject var store: WorkspaceStore
  @ObservedObject var commands: WorkspaceCommands
  let companion: CraftHubCompanionStore
  let close: () -> Void
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Label("快速记录", systemImage: "square.and.pencil").font(.headline)
        Spacer()
        Button("关闭", action: close).keyboardShortcut(.cancelAction)
      }
      NoteComposer(store: store, commands: commands, autofocus: true)
      WorkspaceSaveStatus(store: store)
      Divider()
      CraftHubCompanionSection(store: companion)
    }
    .padding(20).frame(width: 460)
  }
}
