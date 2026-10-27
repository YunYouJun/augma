import AppKit
import SwiftUI

struct ApplicationMarketView: View {
  @ObservedObject var store: ApplicationMarketStore
  @State private var observer = UUID()
  @State private var approval: TrashApproval?
  @State private var confirmingAI = false
  @State private var showingSettings = false
  @State private var aiReady = false

  private struct TrashApproval: Identifiable {
    let planID: UUID
    let ids: Set<UUID>
    let bytes: UInt64
    var id: UUID { planID }
  }

  var body: some View {
    NativePage {
      VStack(alignment: .leading, spacing: 5) {
        Label("应用市场", systemImage: "shippingbox").font(.title2.bold())
        Text("按需安装本地工具，让 Augma 按你的目标调用。")
          .font(.callout).foregroundStyle(.secondary)
      }
      moleCard
      cleanupRequest
      if store.isBusy {
        HStack {
          ProgressView().controlSize(.small)
          Text(phaseText).font(.callout)
          Spacer()
          if !store.isMutating {
            Button("取消") { store.cancel() }.fixedSize(horizontal: true, vertical: false)
          }
        }
      }
      if !store.feedback.isEmpty { Text(store.feedback).font(.callout).textSelection(.enabled) }
      if !store.error.isEmpty { Text(store.error).font(.callout).foregroundStyle(.red).textSelection(.enabled) }
      if let plan = store.plan {
        DiskCleanupPlanView(plan: plan, store: store)
        ViewThatFits(in: .horizontal) {
          HStack(spacing: NativePageLayout.itemSpacing) {
            optimizeButton.fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: NativePageLayout.itemSpacing)
            trashButton(for: plan).fixedSize(horizontal: true, vertical: false)
          }
          VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
            optimizeButton
            trashButton(for: plan)
          }
        }
        Text("移入废纸篓后仍占用磁盘空间；确认不再需要后，可在 Finder 中清空废纸篓。")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .onAppear { aiReady = AssistantRuntimeSettings.isReady; store.activate(observer) }
    .onDisappear { store.deactivate(observer) }
    .onReceive(NotificationCenter.default.publisher(for: .augmaDeepSeekConfigChanged)) { _ in
      aiReady = AssistantRuntimeSettings.isReady
      if store.phase == .analyzing { store.cancel() }
    }
    .sheet(isPresented: $showingSettings) { AssistantSettingsView() }
    .confirmationDialog("将所选项目移入废纸篓？", isPresented: Binding(get: { approval != nil }, set: { if !$0 { approval = nil } }),
                        titleVisibility: .visible, presenting: approval) { pending in
      Button("移入废纸篓", role: .destructive) {
        store.moveToTrash(planID: pending.planID, ids: pending.ids)
        approval = nil
      }
    } message: { pending in
      Text(String(format: String(localized: "共 %lld 项，约 %@。仅执行本次勾选项，文件变化或计划过期时将跳过。"),
                  pending.ids.count, SystemMetricFormat.bytes(pending.bytes, style: .file)))
    }
    .confirmationDialog("将匿名摘要发送给所选 AI 运行时？", isPresented: $confirmingAI, titleVisibility: .visible) {
      Button("发送摘要并分析") { if AssistantRuntimeSettings.isReady { store.analyzeWithAI() } }
    } message: {
      Text("仅发送目标容量、保留规则和最多 12 项的匿名编号、类别与大小。不发送文件名、路径、原始指令或文件内容。调用可能收费；AI 只能调整已有候选，执行仍需确认。")
    }
  }

  private var optimizeButton: some View {
    Button(aiReady ? "AI 优化计划…" : "配置 AI 助手…", systemImage: "sparkles") {
      if aiReady { confirmingAI = true } else { showingSettings = true }
    }
    .disabled(store.isBusy)
  }

  private func trashButton(for plan: DiskCleanupPlan) -> some View {
    Button("移入废纸篓…", systemImage: "trash") {
      let candidates = store.selectedCandidates
      approval = TrashApproval(planID: plan.id, ids: Set(candidates.map(\.id)),
                               bytes: candidates.reduce(0) { $0 + $1.bytes })
    }
    .disabled(store.isBusy || store.selectedCandidates.isEmpty)
  }

  private var moleCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "externaldrive").font(.system(size: 30)).foregroundStyle(.cyan)
        VStack(alignment: .leading, spacing: 4) {
          Text("Mole CLI").font(.headline)
          Text("免费开源 · 本地磁盘占用分析").font(.caption).foregroundStyle(.secondary)
          Text("GPL-3.0-or-later").font(.caption2).foregroundStyle(.secondary)
          if let version = store.installation?.version {
            Text("v" + version).font(.caption.monospaced()).foregroundStyle(.secondary)
          }
        }
        Spacer(minLength: 0)
      }
      Text("通过 Homebrew 安装命令行版。Mole 分析占用，Augma 按保留规则生成计划并执行你确认的项目。")
        .font(.callout)
      ViewThatFits(in: .horizontal) {
        HStack(spacing: NativePageLayout.itemSpacing) {
          installationStatus.fixedSize(horizontal: true, vertical: false)
          refreshButton.fixedSize(horizontal: true, vertical: false)
          Spacer(minLength: 0)
          projectLink.fixedSize(horizontal: true, vertical: false)
        }
        VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
          installationStatus
          HStack {
            refreshButton
            Spacer(minLength: NativePageLayout.itemSpacing)
            projectLink
          }
        }
      }
      if store.installation?.homebrewAvailable == false && store.installation?.version == nil {
        Text("需要已安装的 Homebrew；Augma 不会自动安装包管理器。")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .nativeCard()
  }

  @ViewBuilder private var installationStatus: some View {
    if store.installation?.version != nil {
      Label(store.installation?.supported == true ? "已安装，可分析" : "版本尚未适配",
            systemImage: store.installation?.supported == true ? "checkmark.circle" : "info.circle")
        .font(.callout)
    } else {
      Button("安装 Mole CLI", systemImage: "arrow.down.circle") { store.installMole() }
        .disabled(store.isBusy || store.installation?.homebrewAvailable != true)
    }
  }

  private var refreshButton: some View {
    Button("刷新", systemImage: "arrow.clockwise") { store.refresh() }.disabled(store.isBusy)
  }

  private var projectLink: some View {
    Link("项目主页", destination: URL(string: "https://github.com/tw93/Mole")!).font(.caption)
  }

  private var cleanupRequest: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        TextEditor(text: $store.draft).font(.body).frame(height: 62)
          .padding(6).background(.background, in: RoundedRectangle(cornerRadius: 6))
          .accessibilityLabel("清理目标").disabled(store.isBusy)
        Text("默认保留模型目录和项目源码；最近项目暂按保留全部 Xcode 构建缓存处理。")
          .font(.caption).foregroundStyle(.secondary)
        ViewThatFits(in: .horizontal) {
          HStack(spacing: NativePageLayout.itemSpacing) {
            scopePath.frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
            scopeButton.fixedSize(horizontal: true, vertical: false)
          }
          VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
            scopePath
            scopeButton
          }
        }
        VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
          Button("生成清理计划", systemImage: "magnifyingglass") {
            if !store.requestCleanup(store.draft) {
              store.showInvalidRequest()
            }
          }
          .controlSize(.large)
          .buttonStyle(.borderedProminent)
          .disabled(store.isBusy || store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          Text("先扫描和预览，再选择执行。容量目标会显示差额。")
            .font(.caption).foregroundStyle(.secondary)
        }
      }.padding(NativePageLayout.itemSpacing).frame(maxWidth: .infinity, alignment: .leading)
    } label: { Label("AI 清理", systemImage: "sparkles").font(.headline) }
  }

  private var scopePath: some View {
    Text(store.scope.path).font(.caption).foregroundStyle(.secondary)
      .lineLimit(1).truncationMode(.middle).help(store.scope.path)
  }

  private var scopeButton: some View {
    Button("选择扫描目录…") { chooseScope() }.disabled(store.isBusy)
  }

  private var phaseText: String {
    switch store.phase {
    case .idle: ""
    case .checking: String(localized: "正在检测本地工具…")
    case .installing: String(localized: "正在安装 Mole CLI…")
    case .scanning: String(localized: "正在分析磁盘占用并检查清理候选…")
    case .analyzing: String(localized: "正在优化计划…")
    case .cleaning: String(localized: "正在移入废纸篓…")
    }
  }

  private func chooseScope() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
    panel.directoryURL = store.scope
    panel.begin { response in
      if response == .OK, let url = panel.url { store.changeScope(url) }
    }
  }
}
