import SwiftUI

/// The same destination controls fit the main composer and the narrow menu-bar panel.
struct MicrosoftCaptureControls: View {
  @ObservedObject var store: MicrosoftToDoStore
  let open: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: NativePageLayout.itemSpacing) { destination; openButton }
          .fixedSize(horizontal: true, vertical: false)
        VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) { destination; openButton }
      }
      if let error = store.error {
        Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
      }
    }
  }

  @ViewBuilder private var destination: some View {
    if store.connected {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text("待办清单").fixedSize()
        Picker("待办清单", selection: $store.selectedListID) {
          if !store.lists.contains(where: { $0.id == store.selectedListID }) {
            Text("请刷新并选择清单").tag(store.selectedListID)
          }
          ForEach(store.lists) { list in Text(list.displayName).tag(list.id) }
        }
        .labelsHidden()
        .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
        .disabled(store.busy || store.lists.isEmpty)
        .accessibilityLabel("待办清单")
        .accessibilityIdentifier("capture-todo-list")
        Button("刷新清单", systemImage: "arrow.clockwise") { Task { await store.refreshLists() } }
          .labelStyle(.iconOnly)
          .disabled(store.busy)
          .help("刷新清单")
          .accessibilityIdentifier("capture-refresh-todo")
      }
    } else {
      Button("连接 Microsoft To Do", systemImage: "person.crop.circle.badge.checkmark") { store.signIn() }
        .disabled(!store.configured || store.busy)
        .accessibilityIdentifier("capture-connect-todo")
    }
  }

  private var openButton: some View {
    Button("打开 Microsoft To Do", systemImage: "arrow.up.forward.app", action: open)
      .fixedSize()
      .help("优先打开本机应用，未安装时在浏览器中打开。")
      .accessibilityIdentifier("capture-open-todo")
  }
}
