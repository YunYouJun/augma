import SwiftUI

struct SimulatorCleanupConfirmation: Identifiable {
  let id = UUID()
  let scanID: UUID
  let items: [SimulatorCleanupItem]
}

struct SimulatorCleanupConfirmationView: View {
  let confirmation: SimulatorCleanupConfirmation
  let confirm: (Bool) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var runtimeScopeAcknowledged = false

  private var includesRuntime: Bool { confirmation.items.contains { $0.kind == .runtime } }

  var body: some View {
    VStack(alignment: .leading, spacing: NativePageLayout.sectionSpacing) {
      Label("永久删除所选模拟器项目？", systemImage: "exclamationmark.triangle")
        .font(.title2.weight(.semibold))
      Text("设备中的 App、登录状态和测试数据会一并删除，无法从废纸篓恢复。运行时删除后需重新下载，也可能重启模拟器服务。")
        .font(.callout)
      if includesRuntime {
        Text("仅扫描默认设备集。其他设备集（如 Xcode 预览或 CI）的依赖与运行状态未核对，删除运行时会使其中相关设备不可用，并可能关闭模拟器。")
          .font(.callout)
        Toggle("我已检查其他设备集并关闭相关模拟器，确认删除此全局运行时。", isOn: $runtimeScopeAcknowledged)
          .toggleStyle(.checkbox)
          .accessibilityIdentifier("cleanup-simulator-runtime-scope")
      }
      ScrollView {
        VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
          ForEach(confirmation.items) { item in
            SimulatorCleanupItemLabel(item: item)
            if item.id != confirmation.items.last?.id { Divider() }
          }
        }
      }
      .frame(maxHeight: 320)
      Text("确认仅适用于本次扫描和列出的项目，有效期为 5 分钟；状态或关联设备变化时会跳过。")
        .font(.caption).foregroundStyle(.secondary)
      HStack {
        Button("取消", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
        Spacer()
        Button("永久删除", role: .destructive) { confirm(runtimeScopeAcknowledged) }
          .disabled(includesRuntime && !runtimeScopeAcknowledged)
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("cleanup-simulator-confirm")
      }
    }
    .padding(NativePageLayout.pagePadding)
    .frame(minWidth: 440, idealWidth: 560)
    .onChange(of: confirmation.id) { _, _ in runtimeScopeAcknowledged = false }
  }
}
