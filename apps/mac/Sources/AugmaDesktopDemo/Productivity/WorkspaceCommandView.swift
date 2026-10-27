import SwiftUI

struct WorkspaceCommandView: View {
  @ObservedObject var commands: WorkspaceCommands
  @ObservedObject var store: WorkspaceStore
  var compact = false
  @State private var selection: String?
  @FocusState private var inputFocused: Bool

  private var actions: [WorkspaceAction] {
    let query = commands.query.trimmingCharacters(in: .whitespacesAndNewlines)
    let all = WorkspaceAction.all.filter { query.isEmpty || $0.title.localizedStandardContains(query) || $0.id.localizedStandardContains(query) }
    return all.sorted {
      (store.data.recentActions.firstIndex(of: $0.id) ?? 99) < (store.data.recentActions.firstIndex(of: $1.id) ?? 99)
    }
  }
  private var parsed: WorkspaceCommand? { WorkspaceCommand.parse(commands.query) }
  private var rowIDs: [String] { (parsed == nil ? [] : ["input"]) + actions.map(\.id) }

  var body: some View {
    GeometryReader { geometry in
      content
        .frame(width: min(NativePageLayout.contentWidth, max(0, geometry.size.width - NativePageLayout.pagePadding * 2)),
               height: max(0, geometry.size.height - NativePageLayout.pagePadding * 2), alignment: .top)
        .padding(NativePageLayout.pagePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    .controlSize(.regular)
    .defaultFocus($inputFocused, true)
    .onAppear {
      selection = rowIDs.first
      commands.startPendingVoice()
    }
    .task {
      // Wait until the new utility window has installed its field editor.
      await Task.yield()
      inputFocused = true
    }
    .onChange(of: commands.query) { _, _ in selection = rowIDs.first }
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
      HStack(spacing: NativePageLayout.itemSpacing) {
        Image(systemName: "command").foregroundStyle(.secondary)
        TextField("搜索操作，或输入“记下…”、“专注 25 分钟”", text: $commands.query)
          .textFieldStyle(.roundedBorder).focused($inputFocused)
          .onSubmit(runSelection)
          .onKeyPress(.downArrow) { moveSelection(.down); return .handled }
          .onKeyPress(.upArrow) { moveSelection(.up); return .handled }
          .disabled(["requesting", "listening", "processing"].contains(commands.speechPhase))
        NativeVoiceButton(commands: commands)
          .fixedSize(horizontal: true, vertical: false)
      }
      .layoutPriority(1)
      NativeVoiceStatus(commands: commands)
      List(selection: $selection) {
        if parsed != nil {
          Label("执行输入的指令", systemImage: "return").tag("input")
        }
        ForEach(actions) { action in
          HStack {
            Label(action.title, systemImage: action.symbol)
            Spacer()
            if store.data.recentActions.contains(action.id) { Text("最近使用").font(.caption).foregroundStyle(.secondary) }
          }
          .tag(action.id)
          .foregroundStyle(commands.isAvailable(action.command) ? .primary : .secondary)
        }
      }
      .listStyle(.inset)
      .environment(\.defaultMinListRowHeight, compact ? 28 : 32)
      .frame(minHeight: 0, maxHeight: .infinity)
      .onKeyPress(.return) { runSelection(); return .handled }
      .onTapGesture(count: 2, perform: runSelection)
      .overlay {
        if rowIDs.isEmpty { ContentUnavailableView("没有匹配的操作", systemImage: "magnifyingglass") }
      }
      footer
        .fixedSize(horizontal: false, vertical: true)
        .layoutPriority(1)
    }
  }

  private var footer: some View {
    VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
      HStack(spacing: NativePageLayout.itemSpacing) {
        Text("↑↓ 选择 · Return 执行").font(.caption).foregroundStyle(.secondary)
        Spacer()
        Button("执行指令", action: runSelection)
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .fixedSize(horizontal: true, vertical: false)
          .disabled(rowIDs.isEmpty || !["idle", "error"].contains(commands.speechPhase))
      }
      WorkspaceResultView(commands: commands, store: store)
      WorkspaceSaveStatus(store: store)
      Text("例如：记下 明天买咖啡豆 · 专注二十五分钟 · 暂停计时 · 继续计时 · 撤销")
        .font(.caption).foregroundStyle(.secondary)
    }
  }

  private func runSelection() {
    guard ["idle", "error"].contains(commands.speechPhase) else { return }
    if selection == "input" || (selection == nil && parsed != nil) { commands.submit() }
    else if let action = actions.first(where: { $0.id == (selection ?? rowIDs.first) }) {
      commands.execute(action.command, actionID: action.id)
    }
  }

  private func moveSelection(_ direction: MoveCommandDirection) {
    guard !rowIDs.isEmpty else { return }
    let index = rowIDs.firstIndex(of: selection ?? "") ?? 0
    if direction == .down { selection = rowIDs[min(index + 1, rowIDs.count - 1)] }
    if direction == .up { selection = rowIDs[max(index - 1, 0)] }
  }
}

struct NativeVoiceButton: View {
  @ObservedObject var commands: WorkspaceCommands
  var body: some View { VoiceButtonContent(voice: commands.voice, toggle: commands.toggleVoice) }
}

private struct VoiceButtonContent: View {
  @ObservedObject var voice: VoiceActivityModel
  let toggle: () -> Void
  var body: some View {
    Button(action: toggle) {
      Label(voice.phase == "listening" ? "结束并执行" : ["requesting", "processing"].contains(voice.phase) ? "取消语音" : "语音输入",
            systemImage: voice.phase == "listening" ? "stop.fill" : "mic")
    }
    .help("开始或结束语音指令")
  }
}

struct NativeVoiceStatus: View {
  @ObservedObject var commands: WorkspaceCommands
  var body: some View { VoiceStatusContent(voice: commands.voice, cancel: commands.cancelVoice) }
}

private struct VoiceStatusContent: View {
  @ObservedObject var voice: VoiceActivityModel
  let cancel: () -> Void
  var body: some View {
    if !["idle", "error"].contains(voice.phase) {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: NativePageLayout.itemSpacing) {
          status
            .frame(minWidth: 200, maxWidth: .infinity, alignment: .leading)
          VoiceActivityView(activity: voice).frame(width: 160)
        }
        VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
          status
          VoiceActivityView(activity: voice)
        }
      }
    }
  }

  private var status: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(voice.phase == "listening" ? "正在聆听，再点一次结束并执行" : voice.phase == "requesting" ? "正在等待语音权限…" : "正在识别…")
      Text("语音文字会显示在输入框中。").font(.caption).foregroundStyle(.secondary)
      Button("取消语音", action: cancel)
    }
  }
}

struct WorkspaceResultView: View {
  @ObservedObject var commands: WorkspaceCommands
  @ObservedObject var store: WorkspaceStore
  var body: some View {
    if let result = commands.result {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: commands.resultIsError ? "exclamationmark.circle" : "checkmark.circle")
          .foregroundStyle(commands.resultIsError ? Color.red : Color.accentColor)
        Text(result).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 8) { resultActions }
            .fixedSize(horizontal: true, vertical: false)
          VStack(alignment: .trailing, spacing: 8) { resultActions }
        }
      }
      .padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
  }

  @ViewBuilder private var resultActions: some View {
    if let destination = commands.resultDestination, !commands.resultIsError {
      Button("查看") { commands.navigate?(destination) }
    }
    if store.canUndo { Button("撤销") { commands.execute(.undo) } }
  }
}
