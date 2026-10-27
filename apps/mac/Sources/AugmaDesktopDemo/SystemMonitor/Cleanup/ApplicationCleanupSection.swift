import AppKit
import SwiftUI

/// Shared application memory review and normal-quit confirmation for cleanup panels.
struct ApplicationCleanupSection: View {
  @ObservedObject var monitor: SystemMonitorStore
  var disabled = false
  @State private var pendingQuit: ApplicationMemoryIdentity?
  @State private var quitFeedback = ""

  var body: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        Text("结合内存压力判断是否需要退出应用。正常退出闲置应用可减少占用；macOS 会自动管理可回收缓存。")
          .font(.caption).foregroundStyle(.secondary)
        if let memory = monitor.snapshot.memory {
          VStack(alignment: .leading, spacing: 8) {
            LabeledContent("内存压力") {
              Text(SystemMetricFormat.pressure(memory.pressure)).foregroundStyle(SystemMetricFormat.pressureColor(memory.pressure))
            }
            Text(SystemMetricFormat.bytes(memory.used) + " / " + SystemMetricFormat.bytes(memory.total))
              .monospacedDigit().foregroundStyle(.secondary)
          }
        }
        if let applications = monitor.snapshot.applicationMemory?.applications {
          ForEach(applications.prefix(10)) { usage in
            ViewThatFits(in: .horizontal) {
              HStack(spacing: NativePageLayout.itemSpacing) {
                memoryUsage(usage).frame(minWidth: 140)
                quitButton(usage.application).fixedSize(horizontal: true, vertical: false)
              }
              VStack(alignment: .leading, spacing: 8) {
                memoryUsage(usage)
                quitButton(usage.application)
              }
            }
          }
        } else {
          Text("启用系统监控与应用内存排行后，可查看并退出高占用应用。").font(.caption).foregroundStyle(.secondary)
        }
        if !quitFeedback.isEmpty { Text(quitFeedback).font(.caption) }
        Button("打开活动监视器", systemImage: "waveform.path.ecg") {
          NSWorkspace.shared.open(URL(filePath: "/System/Applications/Utilities/Activity Monitor.app"))
        }
      }
      .padding(NativePageLayout.itemSpacing).frame(maxWidth: .infinity, alignment: .leading)
    } label: { Label("内存整理", systemImage: "memorychip").font(.headline) }
    .alert("请求退出应用？", isPresented: Binding(get: { pendingQuit != nil }, set: { if !$0 { pendingQuit = nil } }),
           presenting: pendingQuit) { identity in
      Button("请求退出", role: .destructive) {
        guard !disabled else { pendingQuit = nil; return }
        quitFeedback = ApplicationCleanup.requestQuit(identity)
          ? String(localized: "已请求正常退出；应用可能等待保存或拒绝退出。请稍后刷新占用。")
          : String(localized: "应用已退出、状态已变化或无法正常退出，请在活动监视器中检查。")
        pendingQuit = nil
      }
      Button("取消", role: .cancel) { pendingQuit = nil }
    } message: { identity in
      Text(String(format: String(localized: "将请求 %@ 正常退出，请先保存工作。释放的内存以系统后续读数为准。"), identity.name))
    }
  }

  private func memoryUsage(_ usage: ApplicationMemoryUsage) -> some View {
    HStack(spacing: NativePageLayout.itemSpacing) {
      AppleIconView(request: .application(bundlePath: usage.application.bundlePath), size: 24)
        .accessibilityHidden(true)
      Text(usage.application.name).lineLimit(1).truncationMode(.middle)
        .help(usage.application.name)
      Spacer(minLength: 0)
      Text(usage.measuredProcessCount > 0 ? SystemMetricFormat.bytes(usage.physicalFootprint) : "—")
        .monospacedDigit().fixedSize(horizontal: true, vertical: false)
    }
  }

  private func quitButton(_ identity: ApplicationMemoryIdentity) -> some View {
    Button("请求退出…") { pendingQuit = identity }
      .controlSize(.small)
      .accessibilityLabel(Text(String(format: String(localized: "请求退出 %@"), identity.name)))
      .disabled(disabled || !ApplicationCleanup.canRequestQuit(identity))
  }

}
