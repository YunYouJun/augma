import SwiftUI

struct CodexStorageSection: View {
  @ObservedObject var store: CodexStorageStore
  var disabled = false
  @State private var showingCandidates = false
  @State private var selectedMoleScope = ""
  @State private var confirmation: CodexStoragePreview?

  var body: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        Text("仅统计已知 Codex 缓存目录与诊断日志的文件信息。会话、历史数据库、工作树和生成成果不在本次扫描范围。")
          .font(.caption).foregroundStyle(.secondary)
        HStack(spacing: NativePageLayout.itemSpacing) {
          Button(store.scan == nil ? "分析 Codex 占用" : "重新分析 Codex", systemImage: "magnifyingglass") {
            selectedMoleScope = ""
            store.startScan()
          }
          .disabled(disabled || store.isBusy)
          .accessibilityIdentifier("codex-storage-scan")
          if store.isBusy {
            ProgressView().controlSize(.small)
            if store.phase != .cleaning {
              Button("取消") { store.cancelReadOnly() }.fixedSize(horizontal: true, vertical: false)
                .accessibilityIdentifier("codex-storage-cancel")
            }
          }
        }
        if let scan = store.scan {
          scanSummary(scan)
          if !scan.candidates.isEmpty {
            candidates(scan)
          } else {
            Text("已统计范围内没有符合预览条件的旧缓存或日志。").font(.caption).foregroundStyle(.secondary)
          }
          optionalMole(scan)
        }
        if let error = store.error {
          Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            .accessibilityIdentifier("codex-storage-error")
        }
        if let receipt = store.receipt { receiptView(receipt) }
        Text("确认后仅将所选文件移入废纸篓，不自动清空；Mole 始终仅用于只读复核。")
          .font(.caption).foregroundStyle(.secondary)
      }
      .padding(NativePageLayout.itemSpacing).frame(maxWidth: .infinity, alignment: .leading)
    } label: {
      Label("Codex 占用与清理", systemImage: "externaldrive.badge.magnifyingglass").font(.headline)
    }
    .accessibilityIdentifier("codex-storage-section")
    .onChange(of: store.scan?.id) { _, _ in selectedMoleScope = "" }
    .task { await store.restoreReceipt() }
    .sheet(item: $confirmation) { review in confirmationView(review) }
  }

  private func scanSummary(_ scan: CodexStorageScan) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(
          String(
            format: String(localized: "已统计缓存与日志：%@"), SystemMetricFormat.bytes(scan.measuredBytes))
        )
        .font(.callout).monospacedDigit()
        Spacer()
        Text(scan.checkedAt, format: .dateTime.hour().minute()).font(.caption).foregroundStyle(
          .secondary)
      }
      Text("统计文件逻辑大小，不是整个 Codex 的占用或预计可释放空间；硬链接重复文件仅计一次。")
        .font(.caption).foregroundStyle(.secondary)
      if scan.incomplete {
        Label("部分范围无法读取或达到扫描预算；未完整检查的范围不会生成清理候选。", systemImage: "info.circle")
          .font(.caption).foregroundStyle(.secondary)
      }
      let visible = scan.scopes.filter { $0.status != .missing }
      if visible.isEmpty {
        Text("未发现受支持的 Codex 缓存或日志目录。").font(.caption).foregroundStyle(.secondary)
      }
      ForEach(visible) { scope in
        VStack(alignment: .leading, spacing: 3) {
          HStack(alignment: .firstTextBaseline) {
            Text(scope.category.title).font(.callout)
            Spacer()
            Text(
              scope.status == .unavailable
                ? String(localized: "未统计") : SystemMetricFormat.bytes(scope.bytes)
            )
            .font(.callout).monospacedDigit()
          }
          Text(scope.displayPath).font(.caption2).foregroundStyle(.secondary).textSelection(
            .enabled)
          if let issue = scope.issue { Text(issue).font(.caption).foregroundStyle(.secondary) }
          if scope.skippedLinks + scope.skippedProtected > 0 {
            Text("已跳过符号链接或受保护内容；这些内容未计入大小。").font(.caption).foregroundStyle(.secondary)
          }
        }
        .padding(.vertical, 3)
      }
    }
    .accessibilityIdentifier("codex-storage-summary")
  }

  private func candidates(_ scan: CodexStorageScan) -> some View {
    DisclosureGroup("查看清理候选", isExpanded: $showingCandidates) {
      VStack(alignment: .leading, spacing: 10) {
        Text("仅列出至少 7 天未更新、无硬链接的普通缓存文件与 .log 诊断日志。默认不选中；目录名称不代表内容一定可以删除。")
          .font(.caption).foregroundStyle(.secondary)
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 9) {
            ForEach(scan.candidates) { item in
              Toggle(
                isOn: Binding(
                  get: { store.selection.contains(item.id) },
                  set: { selected in
                    if selected {
                      store.selection.insert(item.id)
                    } else {
                      store.selection.remove(item.id)
                    }
                  })
              ) {
                VStack(alignment: .leading, spacing: 3) {
                  Text(item.relativePath).font(.callout).lineLimit(2).truncationMode(.middle)
                  Text(item.category.title + " · " + SystemMetricFormat.bytes(item.bytes))
                    .font(.caption).foregroundStyle(.secondary)
                  if let scope = scan.scopes.first(where: { $0.id == item.scopeID }) {
                    Text(scope.displayPath).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                      .truncationMode(.middle)
                  }
                }
              }
              .toggleStyle(.checkbox).disabled(disabled || store.isBusy)
              .accessibilityIdentifier("codex-storage-candidate-" + item.id.uuidString)
            }
          }
        }
        .frame(maxHeight: 220)
        if scan.scopes.contains(where: { $0.omittedCandidates > 0 }) {
          Text("每个范围仅展示体积最大的 100 个候选；未展示的文件不会加入预览。")
            .font(.caption).foregroundStyle(.secondary)
        }
        Button("生成 Codex 清理预览", systemImage: "doc.text.magnifyingglass") { store.buildPreview() }
          .disabled(disabled || store.isBusy || store.selection.isEmpty)
          .accessibilityIdentifier("codex-storage-preview")
        if let preview = store.preview {
          Text(
            String(
              format: String(localized: "清理预览：%lld 项 · 逻辑大小 %@"), preview.items.count,
              SystemMetricFormat.bytes(preview.bytes))
          ).font(.callout).monospacedDigit()
            .accessibilityIdentifier("codex-storage-preview-result")
          Text("已重新核对所选文件的信息。请逐项审阅，再确认移入废纸篓；空间尚未释放。")
            .font(.caption).foregroundStyle(.secondary)
          Button("审阅并清理所选项", systemImage: "trash") { confirmation = preview }
            .disabled(disabled || store.isBusy)
            .accessibilityIdentifier("codex-storage-review")
        }
      }
      .padding(.top, 6)
    }
  }

  private func confirmationView(_ review: CodexStoragePreview) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("确认 Codex 清理清单").font(.headline)
      Text("请先退出 Codex 桌面应用和 CLI。执行前会再次核对文件；已变化的文件会跳过。仅移入废纸篓，可恢复，不自动清空。")
        .font(.callout)
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          ForEach(review.items) { item in
            VStack(alignment: .leading, spacing: 4) {
              Text(item.relativePath).font(.callout).textSelection(.enabled)
              if let scope = store.scan?.scopes.first(where: { $0.id == item.scopeID }) {
                Text(scope.displayPath).font(.caption).foregroundStyle(.secondary)
              }
              Text(SystemMetricFormat.bytes(item.bytes)).font(.caption).monospacedDigit()
            }
          }
        }.frame(maxWidth: .infinity, alignment: .leading)
      }.frame(maxHeight: 300)
      Text(
        String(
          format: String(localized: "清理预览：%lld 项 · 逻辑大小 %@"), review.items.count,
          SystemMetricFormat.bytes(review.bytes))
      ).font(.callout)
      HStack {
        Button("返回") { confirmation = nil }.keyboardShortcut(.cancelAction)
        Spacer()
        Button("确认移入废纸篓", role: .destructive) {
          confirmation = nil
          store.execute(review)
        }.disabled(disabled || store.isBusy || store.preview?.id != review.id)
          .accessibilityIdentifier("codex-storage-confirm")
      }
    }.padding(24).frame(width: 520)
  }

  private func receiptView(_ receipt: CodexStorageReceipt) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("最近一次 Codex 清理回执").font(.headline)
      Text(receipt.startedAt, format: .dateTime.year().month().day().hour().minute())
        .font(.caption).foregroundStyle(.secondary)
      Text(
        String(
          format: String(localized: "移入废纸篓的逻辑大小：%@（不等于已释放空间）"),
          SystemMetricFormat.bytes(receipt.trashedBytes))
      ).font(.callout)
      if let warning = receipt.warning { Text(warning).font(.caption).foregroundStyle(.orange) }
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          ForEach(receipt.items) { item in
            VStack(alignment: .leading, spacing: 3) {
              Text(item.status.title + " · " + item.candidate.relativePath).font(.callout)
              Text(item.displayPath).font(.caption2).foregroundStyle(.secondary).textSelection(
                .enabled)
              Text(item.detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
          }
        }.frame(maxWidth: .infinity, alignment: .leading)
      }.frame(maxHeight: 220)
    }.accessibilityIdentifier("codex-storage-receipt")
  }

  private func optionalMole(_ scan: CodexStorageScan) -> some View {
    DisclosureGroup("Mole 占用复核（可选）") {
      VStack(alignment: .leading, spacing: 8) {
        Text("原生分析无需安装 Mole。可在应用市场自行安装受支持版本，再只读复核一个已完整扫描的范围；结果不加入清理候选或容量合计。")
          .font(.caption).foregroundStyle(.secondary)
        let scopes = scan.scopes.filter(\.canAnalyzeWithMole)
        if !scopes.isEmpty {
          Picker("复核范围", selection: $selectedMoleScope) {
            Text("选择范围").tag("")
            ForEach(scopes) { scope in Text(scope.displayPath).tag(scope.id) }
          }
          .disabled(disabled || store.isBusy)
          Button("使用 Mole 只读分析", systemImage: "chart.bar.doc.horizontal") {
            store.analyzeWithMole(scopeID: selectedMoleScope)
          }
          .disabled(disabled || store.isBusy || selectedMoleScope.isEmpty)
          .accessibilityIdentifier("codex-storage-mole")
        }
        if let report = store.moleReport, let scopeID = store.moleScopeID,
          let scope = scan.scopes.first(where: { $0.id == scopeID })
        {
          Text(scope.displayPath).font(.caption2).foregroundStyle(.secondary).textSelection(
            .enabled)
          if let checked = store.moleCheckedAt {
            Text(checked, format: .dateTime.hour().minute()).font(.caption).foregroundStyle(
              .secondary)
          }
          if report.incomplete {
            Text("Mole 未完整读取此范围；未读取内容不视为空。").font(.caption).foregroundStyle(.secondary)
          }
          ForEach(report.entries) { entry in
            HStack {
              Text(entry.name).lineLimit(1).truncationMode(.middle)
              Spacer()
              Text(
                entry.complete ? SystemMetricFormat.bytes(entry.size) : String(localized: "未完整统计")
              )
              .monospacedDigit()
            }
            .font(.caption)
          }
        }
      }
      .padding(.top, 6)
    }
    .font(.callout)
  }
}
