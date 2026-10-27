import SwiftUI

struct HomebrewCleanupSection: View {
  @ObservedObject var store: HomebrewCleanupStore
  var disabled = false
  @State private var confirming = false
  @State private var pendingID: UUID?

  var body: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        Text("由 Homebrew 管理旧版本、过期下载和日志的清理。先预览，再单独确认永久移除；不会自动卸载不再需要的依赖。")
          .font(.caption).foregroundStyle(.secondary)
        ViewThatFits(in: .horizontal) {
          HStack(spacing: NativePageLayout.itemSpacing) {
            previewButton.fixedSize(horizontal: true, vertical: false)
            previewProgress
          }
          VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
            previewButton
            previewProgress
          }
        }
        if let preview = store.preview {
          HStack {
            Text(preview.version).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(preview.createdAt, format: .dateTime.hour().minute()).font(.caption).foregroundStyle(.secondary)
          }
          Text(String(format: String(localized: "预览 %lld 项 · Homebrew 估算 %@"), preview.itemCount,
                      preview.estimatedBytes.map { SystemMetricFormat.bytes($0, style: .file) } ?? String(localized: "暂不可用")))
            .font(.callout).monospacedDigit()
          report(preview.report)
          if preview.canExecute {
            Button("按 Homebrew 规则清理…", systemImage: "trash") {
              pendingID = preview.id
              confirming = true
            }
            .disabled(disabled || store.isBusy)
            .accessibilityIdentifier("cleanup-homebrew-execute")
          } else if let restriction = preview.executionRestriction {
            Text(restriction).font(.caption).foregroundStyle(.secondary)
          } else {
            Text("本次预览未发现可清理项目。").font(.caption).foregroundStyle(.secondary)
          }
          Text("预览不是完整的删除清单。执行时 Homebrew 会重新判断，也可能清理未在预览中列出的失效缓存。")
            .font(.caption).foregroundStyle(.secondary)
        }
        if store.phase == .cleaning { Text("正在核对预览并清理 Homebrew…").font(.caption) }
        if let receipt = store.receipt {
          Label(receipt.succeeded ? "Homebrew 清理已完成。" : "Homebrew 报告操作失败，部分项目可能已移除。",
                systemImage: receipt.succeeded ? "checkmark.circle" : "exclamationmark.triangle")
          if let change = receipt.availableSpaceChange {
            Text(String(format: String(localized: "卷可用空间变化：%@（包含其他应用的并发写入）"),
                        (change >= 0 ? "+" : "−") + SystemMetricFormat.bytes(change.magnitude)))
              .font(.caption).monospacedDigit()
          } else {
            Text("无法读取卷空间变化，请在系统储存空间中核对。").font(.caption).foregroundStyle(.secondary)
          }
          report(receipt.report)
        }
        if let error = store.error { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
      }
      .padding(NativePageLayout.itemSpacing).frame(maxWidth: .infinity, alignment: .leading)
    } label: { Label("Homebrew 清理", systemImage: "shippingbox").font(.headline) }
    .confirmationDialog("永久清理 Homebrew 项目？", isPresented: $confirming, titleVisibility: .visible) {
      Button("永久清理", role: .destructive) {
        if let pendingID { store.cleanup(previewID: pendingID) }
        pendingID = nil
      }
    } message: {
      Text("旧版本、过期下载、日志及失效缓存会由 Homebrew 直接移除，无法从废纸篓恢复，之后可能需要重新下载。执行前会重新核对预览；实际范围由 Homebrew 规则决定，不会自动卸载闲置依赖。")
    }
  }

  private var previewButton: some View {
    Button("预览 Homebrew 清理", systemImage: "magnifyingglass") { store.startPreview() }
      .disabled(disabled || store.isBusy)
      .accessibilityIdentifier("cleanup-homebrew-preview")
  }

  @ViewBuilder private var previewProgress: some View {
    if store.isBusy {
      HStack(spacing: NativePageLayout.itemSpacing) {
        ProgressView().controlSize(.small)
        if store.phase == .previewing {
          Button("取消") { store.cancelPreview() }
            .fixedSize(horizontal: true, vertical: false)
        }
      }
    }
  }

  private func report(_ text: String) -> some View {
    DisclosureGroup("查看 Homebrew 原始报告") {
      ScrollView {
        Text(text.isEmpty ? String(localized: "本次预览未发现可清理项目。") : text)
          .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxHeight: 180)
    }
    .font(.caption)
  }
}
