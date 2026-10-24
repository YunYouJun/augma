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
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Image(systemName: "command").foregroundStyle(.secondary)
        TextField("搜索操作，或输入“记下…”、“专注 25 分钟”", text: $commands.query)
          .textFieldStyle(.roundedBorder).focused($inputFocused)
          .onSubmit(runSelection)
          .onKeyPress(.downArrow) { moveSelection(.down); return .handled }
          .onKeyPress(.upArrow) { moveSelection(.up); return .handled }
          .disabled(["requesting", "listening", "processing"].contains(commands.speechPhase))
        NativeVoiceButton(commands: commands)
      }
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
      .listStyle(.inset).frame(minHeight: compact ? 160 : 220)
      .onKeyPress(.return) { runSelection(); return .handled }
      .onTapGesture(count: 2, perform: runSelection)
      .overlay {
        if rowIDs.isEmpty { ContentUnavailableView("没有匹配的操作", systemImage: "magnifyingglass") }
      }
      HStack {
        Text("↑↓ 选择 · Return 执行").font(.caption).foregroundStyle(.secondary)
        Spacer()
        Button("执行指令", action: runSelection)
          .buttonStyle(.borderedProminent)
          .disabled(rowIDs.isEmpty || !["idle", "error"].contains(commands.speechPhase))
      }
      WorkspaceResultView(commands: commands, store: store)
      WorkspaceSaveStatus(store: store)
      Text("例如：记下 明天买咖啡豆 · 专注二十五分钟 · 暂停计时 · 继续计时 · 撤销")
        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
    .padding(20)
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
      HStack {
        VStack(alignment: .leading, spacing: 6) {
          Text(voice.phase == "listening" ? "正在聆听，再点一次结束并执行" : voice.phase == "requesting" ? "正在等待语音权限…" : "正在识别…")
          Text("语音文字会显示在输入框中。").font(.caption).foregroundStyle(.secondary)
          Button("取消语音", action: cancel)
        }
        Spacer()
        VoiceActivityView(activity: voice).frame(width: 160)
      }
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
        if let destination = commands.resultDestination, !commands.resultIsError {
          Button("查看") { commands.navigate?(destination) }
        }
        if store.canUndo { Button("撤销") { commands.execute(.undo) } }
      }
      .padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
  }
}
