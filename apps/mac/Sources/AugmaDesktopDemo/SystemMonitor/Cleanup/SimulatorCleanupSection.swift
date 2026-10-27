import SwiftUI

struct SimulatorCleanupSection: View {
  @ObservedObject var store: SimulatorCleanupStore
  var disabled = false
  @State private var aiReady = false
  @State private var confirmingAI = false
  @State private var confirmation: SimulatorCleanupConfirmation?
  @State private var showingSettings = false

  private var isBusy: Bool { disabled || store.isBusy }

  var body: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        Text("扫描默认设备集的设备数据与共享运行时映像。运行中的设备、默认设备集仍有关联设备的运行时只供查看；删除运行时需另行确认其他设备集的影响。")
          .font(.caption).foregroundStyle(.secondary)
        scanControls
        if let scan = store.scan {
          scanSummary(scan)
          if scan.items.isEmpty {
            Text("本次未发现模拟器设备或运行时。").foregroundStyle(.secondary)
          }
          if !scan.warnings.isEmpty {
            ForEach(Array(scan.warnings.enumerated()), id: \.offset) { _, warning in
              Label(warning, systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
            }
          }
          itemGroup(String(localized: "模拟器设备"), systemImage: "iphone.gen3", tint: .augmaCyan,
                    items: scan.items.filter { $0.kind == .device })
          itemGroup(String(localized: "共享运行时"), systemImage: "square.stack.3d.up", tint: .augmaAccent,
                    items: scan.items.filter { $0.kind == .runtime })
          aiControls
          if let advice = store.advice {
            VStack(alignment: .leading, spacing: 8) {
              Label("AI 清理建议", systemImage: "sparkles").font(.callout.weight(.medium))
              Text(advice.summary).font(.callout).textSelection(.enabled)
              ForEach(scan.items.filter { advice.recommendedIDs.contains($0.id) }) { item in
                Label(item.name, systemImage: "magnifyingglass").font(.caption)
              }
              Text("AI 建议不会自动勾选或删除项目，请结合测试环境用途判断。").font(.caption).foregroundStyle(.secondary)
            }
          }
          selectionControls(scan)
          Text("扫描与确认在 5 分钟内有效；执行前会重新核对身份、运行状态和关联设备。容量为估算，不保证等量释放。")
            .font(.caption).foregroundStyle(.secondary)
        }
        if store.isCleaning {
          ProgressView("正在复查并清理所选模拟器项目…").controlSize(.small)
        }
        if let receipt = store.receipt { receiptSummary(receipt) }
        if let error = store.error { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
      }
      .padding(NativePageLayout.itemSpacing).frame(maxWidth: .infinity, alignment: .leading)
    } label: { Label("模拟器专项清理", systemImage: "iphone.gen3").font(.headline) }
    .onAppear { aiReady = AssistantRuntimeSettings.isReady }
    .onDisappear { store.cancelReadOnly() }
    .onReceive(NotificationCenter.default.publisher(for: .augmaDeepSeekConfigChanged)) { _ in
      aiReady = AssistantRuntimeSettings.isReady
      if store.phase == .analyzing { store.cancelReadOnly() }
    }
    .sheet(isPresented: $showingSettings) { AssistantSettingsView() }
    .sheet(item: $confirmation) { pending in
      SimulatorCleanupConfirmationView(confirmation: pending) { runtimeScopeAcknowledged in
        confirmation = nil
        store.delete(scanID: pending.scanID, ids: Set(pending.items.map(\.id)),
                     runtimeScopeAcknowledged: runtimeScopeAcknowledged)
      }
    }
    .confirmationDialog("将模拟器匿名摘要发送给所选 AI 运行时？", isPresented: $confirmingAI, titleVisibility: .visible) {
      Button("发送摘要并分析") {
        guard AssistantRuntimeSettings.isReady else { aiReady = false; return }
        store.analyze()
      }
    } message: {
      Text("仅发送匿名编号、类型、容量、使用时间间隔、状态和关联设备数量。不发送设备名称、UUID、路径或内容。API 调用可能收费；AI 只给建议，操作仍需逐项选择并确认。")
    }
  }

  private var scanControls: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: NativePageLayout.itemSpacing) { scanButton; readProgress }
      VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) { scanButton; readProgress }
    }
  }

  private var scanButton: some View {
    Button(store.scan == nil ? String(localized: "扫描模拟器占用") : String(localized: "重新扫描模拟器"), systemImage: "magnifyingglass") { store.startScan() }
      .disabled(isBusy).accessibilityIdentifier("cleanup-simulator-scan")
  }

  @ViewBuilder private var readProgress: some View {
    if store.phase == .scanning || store.phase == .analyzing {
      HStack(spacing: NativePageLayout.itemSpacing) {
        ProgressView().controlSize(.small)
        Button("取消") { store.cancelReadOnly() }.fixedSize(horizontal: true, vertical: false)
      }
    }
  }

  private func scanSummary(_ scan: SimulatorCleanupScan) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        occupancySummary(String(localized: "设备数据"), systemImage: "iphone.gen3", bytes: scan.deviceBytes, tint: .augmaCyan)
        occupancySummary(String(localized: "运行时映像"), systemImage: "square.stack.3d.up", bytes: scan.runtimeBytes, tint: .augmaAccent)
      }
      Label {
        Text(scan.createdAt, format: .dateTime.month().day().hour().minute())
      } icon: {
        Image(systemName: "clock.arrow.circlepath").accessibilityHidden(true)
      }
      .font(.caption).foregroundStyle(.secondary)
      .accessibilityLabel(Text(String(format: String(localized: "扫描时间：%@"),
                                     scan.createdAt.formatted(.dateTime.month().day().hour().minute()))))
      Text("设备容量仅包含默认设备集，由系统报告数据目录大小，不包含共享运行时；未知容量不计入合计。映像大小与挂载卷展开后的大小可能不同。")
        .font(.caption).foregroundStyle(.secondary)
    }
  }

  private func occupancySummary(_ title: String, systemImage: String, bytes: UInt64, tint: Color) -> some View {
    HStack(spacing: 10) {
      Image(systemName: systemImage).font(.title3).foregroundStyle(tint).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(.caption).foregroundStyle(.secondary)
        Text("≈ " + SystemMetricFormat.bytes(bytes, style: .file))
          .font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(.primary)
          .lineLimit(1).minimumScaleFactor(0.8)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder private func itemGroup(_ title: String, systemImage: String, tint: Color,
                                     items: [SimulatorCleanupItem]) -> some View {
    if !items.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 6) {
          Label {
            Text(title)
          } icon: {
            Image(systemName: systemImage).foregroundStyle(tint).accessibilityHidden(true)
          }
          .font(.callout.weight(.semibold))
          Text(items.count, format: .number).font(.caption).foregroundStyle(.secondary)
        }
        ForEach(items) { item in
          HStack(alignment: .top, spacing: 10) {
            Toggle(item.name, isOn: Binding(get: { store.selection.contains(item.id) }, set: { selected in
              if selected, item.canDelete { store.selection.insert(item.id) }
              else { store.selection.remove(item.id) }
            }))
            .labelsHidden().toggleStyle(.checkbox)
            .disabled(isBusy || !item.canDelete)
            .padding(.top, 9)
            .accessibilityLabel(Text(item.name))
            .accessibilityHint(Text(item.restriction ?? ""))
            .accessibilityIdentifier("cleanup-simulator-item-" + item.id)
            SimulatorCleanupItemLabel(item: item)
          }
          if item.id != items.last?.id { Divider().padding(.leading, 28) }
        }
      }
    }
  }

  private var aiControls: some View {
    Group {
      if aiReady {
        Button("获取模拟器 AI 建议…", systemImage: "sparkles") { confirmingAI = true }
          .disabled(isBusy).accessibilityIdentifier("cleanup-simulator-ai")
      } else {
        Button("配置 AI 助手…", systemImage: "key") { showingSettings = true }.disabled(isBusy)
      }
    }
  }

  private func selectionControls(_ scan: SimulatorCleanupScan) -> some View {
    ViewThatFits(in: .horizontal) {
      HStack {
        selectionSummary
        Spacer(minLength: NativePageLayout.itemSpacing)
        deleteButton(scan)
      }
      VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
        selectionSummary
        deleteButton(scan)
      }
    }
  }

  private var selectionSummary: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(String(format: String(localized: "已选 %lld 项 · 已知估算 %@"), store.selectedItems.count,
                  SystemMetricFormat.bytes(store.selectedBytes, style: .file))).font(.callout).monospacedDigit()
      let unknownCount = store.selectedItems.filter { $0.bytes == nil }.count
      if unknownCount > 0 {
        Text(String(format: String(localized: "另有 %lld 项大小未知，未计入估算。"), unknownCount))
          .font(.caption).foregroundStyle(.secondary)
      }
    }
  }

  private func deleteButton(_ scan: SimulatorCleanupScan) -> some View {
    Button("核对并删除所选项目…", systemImage: "trash") {
      confirmation = SimulatorCleanupConfirmation(scanID: scan.id, items: store.selectedItems)
    }
    .disabled(isBusy || store.selectedItems.isEmpty).accessibilityIdentifier("cleanup-simulator-execute")
  }

  private func receiptSummary(_ receipt: SimulatorCleanupReceipt) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("模拟器清理回执", systemImage: "list.bullet.clipboard").font(.callout.weight(.medium))
      ForEach(Array(receipt.results.enumerated()), id: \.offset) { _, result in
        VStack(alignment: .leading, spacing: 3) {
          Text(result.item.name + " · " + statusTitle(result.status)).font(.callout)
          Text(result.message).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
        }
      }
      if let change = receipt.availableSpaceChange {
        Text(String(format: String(localized: "卷可用空间变化：%@（包含其他应用的并发写入）"),
                    (change >= 0 ? "+" : "−") + SystemMetricFormat.bytes(change.magnitude)))
          .font(.caption).monospacedDigit()
      } else {
        Text("无法读取卷空间变化，请在系统储存空间中核对。").font(.caption).foregroundStyle(.secondary)
      }
      Text("重新扫描可核对系统最终状态；等待系统完成的项目尚未计为已删除。").font(.caption).foregroundStyle(.secondary)
    }
  }

  private func statusTitle(_ status: SimulatorCleanupStatus) -> String {
    switch status {
    case .deleted: String(localized: "已删除")
    case .skipped: String(localized: "已跳过")
    case .failed: String(localized: "失败")
    case .pending: String(localized: "等待系统完成")
    }
  }
}
