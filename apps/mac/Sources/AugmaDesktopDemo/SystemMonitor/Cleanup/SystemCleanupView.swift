import AppKit
import SwiftUI

struct SystemCleanupView: View {
  @ObservedObject var monitor: SystemMonitorStore
  @ObservedObject var store: SystemCleanupStore
  @ObservedObject private var homebrew: HomebrewCleanupStore
  @ObservedObject private var simulator: SimulatorCleanupStore
  @Environment(\.dismiss) private var dismiss
  @State private var observerID = "system-cleanup-" + UUID().uuidString
  @State private var confirmingTrash = false
  @State private var pendingTrash: [CleanupCandidate] = []
  @State private var confirmingAI = false
  @State private var showingSettings = false
  @State private var aiReady = false
  @State private var showingAllCandidates = false

  init(monitor: SystemMonitorStore, store: SystemCleanupStore) {
    self.monitor = monitor
    self.store = store
    self.homebrew = store.homebrew
    self.simulator = store.simulator
  }

  private var isBusy: Bool { store.isBusy || homebrew.isBusy }
  private var isCleaning: Bool { store.isCleaning }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Label("清理磁盘与内存", systemImage: "sparkles.rectangle.stack").font(.title2.weight(.semibold))
        Spacer()
        Button("完成") { dismiss() }.keyboardShortcut(.cancelAction).disabled(isCleaning)
          .fixedSize(horizontal: true, vertical: false)
      }
      .padding(NativePageLayout.pagePadding)
      Divider()
      ScrollView {
        VStack(alignment: .leading, spacing: NativePageLayout.sectionSpacing) {
          diskSection
          HomebrewCleanupSection(store: homebrew, disabled: store.isBusy)
          SimulatorCleanupSection(store: simulator, disabled: store.phase != .idle || homebrew.isBusy)
          ApplicationCleanupSection(monitor: monitor, disabled: isBusy)
          aiSection
          if !store.feedback.isEmpty {
            Text(store.feedback).font(.callout).textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .nativePageContent()
      }
    }
    .frame(minWidth: 480, idealWidth: 700, minHeight: 600, idealHeight: 740)
    .controlSize(.regular)
    .interactiveDismissDisabled(isCleaning)
    .onAppear {
      aiReady = AssistantRuntimeSettings.isReady
      monitor.startObserving(observerID, demand: .expanded)
    }
    .onDisappear { monitor.stopObserving(observerID); store.cancel() }
    .onChange(of: homebrew.phase) { _, phase in
      if phase == .idle && homebrew.receipt != nil { Task { await monitor.refresh() } }
    }
    .onChange(of: simulator.phase) { _, phase in
      if phase == .idle && simulator.receipt != nil { Task { await monitor.refresh() } }
    }
    .onReceive(NotificationCenter.default.publisher(for: .augmaDeepSeekConfigChanged)) { _ in
      aiReady = AssistantRuntimeSettings.isReady
      if store.phase == .analyzing { store.cancel() }
    }
    .sheet(isPresented: $showingSettings) { AssistantSettingsView() }
    .confirmationDialog("将所选项目移入废纸篓？", isPresented: $confirmingTrash, titleVisibility: .visible) {
      Button("移入废纸篓", role: .destructive) { store.moveToTrash(ids: Set(pendingTrash.map(\.id))) }
    } message: {
      Text(String(format: String(localized: "共 %lld 项，约 %@。可从废纸篓恢复；清空废纸篓后才会释放磁盘空间。Xcode 缓存需要重新构建。"),
                  pendingTrash.count, SystemMetricFormat.bytes(pendingTrash.reduce(0) { $0 + $1.bytes })))
    }
    .confirmationDialog("将匿名摘要发送给所选 AI 运行时？", isPresented: $confirmingAI, titleVisibility: .visible) {
      Button("发送摘要并分析") {
        guard AssistantRuntimeSettings.isReady else { aiReady = false; return }
        store.analyze(snapshot: monitor.snapshot, homebrew: homebrew.preview)
      }
    } message: {
      Text("仅发送内存、磁盘读数、清理类别和 Homebrew 预览的数量与估算，以及匿名应用占用。不发送文件名、路径、应用名称、工具原始报告或文件内容。API 调用可能收费。AI 只给建议，操作仍需你选择并确认。")
    }

  }

  private var diskSection: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        Text("按需扫描“下载”中的 dmg / pkg / xip 安装包和 Xcode DerivedData，仅列出至少 7 天未修改的项目。不会扫描个人文档或系统目录。")
          .font(.caption).foregroundStyle(.secondary)
        HStack {
          Button(store.scan == nil ? "扫描可清理项目" : "重新扫描", systemImage: "magnifyingglass") {
            showingAllCandidates = false
            store.startScan()
          }
            .disabled(isBusy)
          if store.phase == .scanning {
            ProgressView().controlSize(.small)
            Button("取消") { store.cancel() }
          }
        }
        if let scan = store.scan {
          if scan.incomplete {
            Label("部分目录无法读取或已达到扫描上限，结果不完整；未完整检查的项目不会列出。", systemImage: "info.circle")
              .font(.caption).foregroundStyle(.secondary)
          }
          if scan.candidates.isEmpty {
            Text("本次扫描未发现符合条件的项目。").foregroundStyle(.secondary)
          } else {
            LazyVStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
              ForEach(showingAllCandidates ? scan.candidates : Array(scan.candidates.prefix(10))) { candidate in
                candidateRow(candidate)
              }
            }
            if scan.candidates.count > 10 {
              Button(showingAllCandidates ? "收起清理项目" : "查看全部清理项目") { showingAllCandidates.toggle() }
                .controlSize(.small)
            }
            ViewThatFits(in: .horizontal) {
              HStack {
                selectionSummary.fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: NativePageLayout.itemSpacing)
                trashButton.fixedSize(horizontal: true, vertical: false)
              }
              VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
                selectionSummary
                trashButton
              }
            }
          }
        }
        if store.phase == .cleaning { ProgressView("正在移入废纸篓…").controlSize(.small) }
        Text("移入废纸篓后仍占用磁盘空间；确认不再需要后，可在 Finder 中清空废纸篓。")
          .font(.caption).foregroundStyle(.secondary)
      }
      .padding(NativePageLayout.itemSpacing).frame(maxWidth: .infinity, alignment: .leading)
    } label: { Label("磁盘清理", systemImage: "externaldrive").font(.headline) }
  }

  private var selectionSummary: some View {
    Text(String(format: String(localized: "已选 %lld 项 · %@"), store.selectedCandidates.count,
                SystemMetricFormat.bytes(store.selectedBytes))).font(.callout).monospacedDigit()
  }

  private var trashButton: some View {
    Button("移入废纸篓…", systemImage: "trash") {
      pendingTrash = store.selectedCandidates
      confirmingTrash = true
    }
    .disabled(isBusy || store.selectedCandidates.isEmpty)
  }

  private func candidateRow(_ candidate: CleanupCandidate) -> some View {
    HStack(alignment: .top, spacing: NativePageLayout.itemSpacing) {
      Toggle(isOn: Binding(get: { store.selection.contains(candidate.id) }, set: { selected in
        if selected { store.selection.insert(candidate.id) } else { store.selection.remove(candidate.id) }
      })) {
        VStack(alignment: .leading, spacing: 3) {
          Text(candidate.url.lastPathComponent).lineLimit(1).truncationMode(.middle)
          Text(candidate.category.title + " · " + SystemMetricFormat.bytes(candidate.bytes))
            .font(.caption).foregroundStyle(.secondary)
          Text(candidate.url.deletingLastPathComponent().path).font(.caption2)
            .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
        }
      }
      .toggleStyle(.checkbox).disabled(isBusy)
      .frame(maxWidth: .infinity, alignment: .leading)
      .help(candidate.url.path)
      Button("在 Finder 中显示", systemImage: "folder") { NSWorkspace.shared.activateFileViewerSelecting([candidate.url]) }
        .labelStyle(.iconOnly).help("在 Finder 中显示")
        .controlSize(.small)
    }
  }

  private var aiSection: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        Text("使用已配置的 AI 运行时分析匿名占用摘要，帮助决定先检查哪些项目。建议不会自动勾选文件或退出应用。")
          .font(.caption).foregroundStyle(.secondary)
        HStack {
          if aiReady {
            Button("获取 AI 清理建议…", systemImage: "sparkles") { confirmingAI = true }
              .disabled(isBusy || store.scan == nil)
          } else {
            Button("配置 AI 助手…", systemImage: "key") { showingSettings = true }
          }
          if store.phase == .analyzing {
            ProgressView().controlSize(.small)
            Button("取消") { store.cancel() }
          }
        }
        if store.scan == nil { Text("先完成一次磁盘扫描。").font(.caption).foregroundStyle(.secondary) }
        if let advice = store.advice {
          Text(advice.summary).textSelection(.enabled)
          ForEach(advice.categories, id: \.rawValue) { category in
            Label(category.title, systemImage: "externaldrive")
          }
          ForEach(advice.applications, id: \.self) { id in
            if let usage = store.advisedApplications[id] {
              Label {
                Text(usage.application.name)
              } icon: {
                AppleIconView(request: .application(bundlePath: usage.application.bundlePath), size: 20)
                  .accessibilityHidden(true)
              }
            }
          }
          Text("建议基于本次摘要；请结合当前使用情况决定。").font(.caption).foregroundStyle(.secondary)
        }
      }
      .padding(NativePageLayout.itemSpacing).frame(maxWidth: .infinity, alignment: .leading)
    } label: { Label("AI 清理建议", systemImage: "sparkles").font(.headline) }
  }
}
