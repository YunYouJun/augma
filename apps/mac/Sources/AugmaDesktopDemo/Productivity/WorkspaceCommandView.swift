import AppKit
import SwiftUI

struct WorkspaceCommandView: View {
  @ObservedObject var commands: WorkspaceCommands
  @ObservedObject var store: WorkspaceStore
  var compact = false
  var floating = false
  var expanded = true
  var onClose: (() -> Void)?
  var onToggleResults: (() -> Void)?
  var onRevealResults: (() -> Void)?
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
    Group {
      if floating { paletteContent }
      else {
        GeometryReader { geometry in
          content
            .frame(width: min(NativePageLayout.contentWidth, max(0, geometry.size.width - NativePageLayout.pagePadding * 2)),
                   height: max(0, geometry.size.height - NativePageLayout.pagePadding * 2), alignment: .top)
            .padding(NativePageLayout.pagePadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
      }
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
    .onChange(of: commands.query) { _, _ in
      selection = rowIDs.first
      onRevealResults?()
    }
    .onChange(of: commands.speechPhase) { _, phase in
      if ["idle", "error"].contains(phase) { inputFocused = true }
    }
  }

  private var input: some View {
    TextField("搜索操作，或输入“记下…”、“专注 25 分钟”", text: $commands.query)
      .focused($inputFocused)
      .onSubmit(runSelection)
      .onKeyPress(.downArrow) { navigate(.down) }
      .onKeyPress(.upArrow) { navigate(.up) }
      .disabled(["requesting", "listening", "processing"].contains(commands.speechPhase))
      .accessibilityIdentifier("workspace-command-input")
  }

  private var paletteContent: some View {
    resultsList
      .opacity(expanded ? 1 : 0)
      .scrollDisabled(!expanded)
      .allowsHitTesting(expanded)
      .accessibilityHidden(!expanded)
      // Native scroll-edge effects need the fixed controls in the list's safe
      // area. Keep this hierarchy stable so collapsing preserves the field editor.
      .safeAreaBar(edge: .top, spacing: expanded ? 12 : 0) {
        VStack(spacing: 0) {
          paletteHeader
          if expanded {
            VStack(spacing: 12) {
              Divider().padding(.horizontal, 18)
              NativeVoiceStatus(commands: commands).padding(.horizontal, 18)
            }
            .transition(.opacity)
          }
        }
      }
      .safeAreaBar(edge: .bottom, spacing: expanded ? 12 : 0) {
        if expanded {
          footer.padding(.horizontal, 18).padding(.bottom, 16)
            .transition(.opacity)
        }
      }
      .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }

  private var paletteHeader: some View {
    HStack(spacing: 12) {
      NativeOrbLabel(symbol: "command", tint: .augmaCyan)
        .accessibilityHidden(true)
      input.textFieldStyle(.plain).font(.system(size: 17))
      NativeVoiceButton(commands: commands)
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .font(.system(size: 17))
        .frame(width: 28, height: 32)
      Button(action: { onToggleResults?() }) {
        Image(systemName: expanded ? "chevron.up" : "chevron.down")
          .frame(width: 24, height: 32)
      }
      .buttonStyle(.borderless)
      .help(expanded ? String(appLocalized: "收起操作列表") : String(appLocalized: "展开操作列表"))
      .accessibilityLabel(expanded ? String(appLocalized: "收起操作列表") : String(appLocalized: "展开操作列表"))
      .accessibilityIdentifier("command-palette-toggle-results")
      Button("关闭面板", systemImage: "xmark", action: { onClose?() })
        .labelStyle(.iconOnly).buttonStyle(.borderless)
        .keyboardShortcut("w", modifiers: .command)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("command-palette-close")
    }
    .padding(.horizontal, 18)
    .frame(height: 80)
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
      HStack(spacing: NativePageLayout.itemSpacing) {
        Image(systemName: "command").foregroundStyle(.secondary)
        input.textFieldStyle(.roundedBorder)
        NativeVoiceButton(commands: commands)
          .fixedSize(horizontal: true, vertical: false)
      }
      .layoutPriority(1)
      NativeVoiceStatus(commands: commands)
      resultsList
      footer
        .fixedSize(horizontal: false, vertical: true)
        .layoutPriority(1)
    }
  }

  private var resultsList: some View {
    List(selection: $selection) {
      if parsed != nil {
        Label("执行输入的指令", systemImage: "return").tag("input")
          .listRowSeparator(floating ? .hidden : .automatic)
      }
      ForEach(actions) { action in
        HStack {
          Label(action.title, systemImage: action.symbol)
          Spacer()
          if store.data.recentActions.contains(action.id) { Text("最近使用").font(.caption).foregroundStyle(.secondary) }
        }
        .tag(action.id)
        .foregroundStyle(commands.isAvailable(action.command) ? .primary : .secondary)
        .listRowSeparator(floating ? .hidden : .automatic)
      }
    }
    .listStyle(.inset)
    .scrollContentBackground(floating ? .hidden : .automatic)
    .environment(\.defaultMinListRowHeight, floating ? 38 : compact ? 28 : 32)
    .frame(minHeight: 0, maxHeight: .infinity)
    .onKeyPress(.return) { runSelection(); return .handled }
    .onTapGesture(count: 2, perform: runSelection)
    .overlay {
      if rowIDs.isEmpty { ContentUnavailableView("没有匹配的操作", systemImage: "magnifyingglass") }
    }
  }

  private var footer: some View {
    VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
      HStack(spacing: NativePageLayout.itemSpacing) {
        Text(floating ? String(appLocalized: "↑↓ 选择 · Return 执行 · Esc 关闭") : String(appLocalized: "↑↓ 选择 · Return 执行"))
          .font(.caption).foregroundStyle(.secondary)
        Spacer()
        Button("执行指令", action: runSelection)
          .buttonStyle(.borderedProminent)
          .controlSize(floating ? .regular : .large)
          .fixedSize(horizontal: true, vertical: false)
          .disabled(rowIDs.isEmpty || !["idle", "error"].contains(commands.speechPhase))
      }
      WorkspaceResultView(commands: commands, store: store)
      WorkspaceSaveStatus(store: store)
      if !floating {
        Text("例如：记下 明天买咖啡豆 · 专注二十五分钟 · 暂停计时 · 继续计时 · 撤销")
          .font(.caption).foregroundStyle(.secondary)
      }
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

  private func navigate(_ direction: MoveCommandDirection) -> KeyPress.Result {
    let handled = NativeCommandInputRouting.navigate(editor: NSApp.keyWindow?.firstResponder as? any NSTextInputClient) {
      if direction == .down { onRevealResults?() }
      moveSelection(direction)
    }
    return handled ? .handled : .ignored
  }
}

struct NativeVoiceButton: View {
  @ObservedObject var commands: WorkspaceCommands
  var body: some View {
    VoiceButtonContent(voice: commands.voice, dictating: commands.speechMode == .dictation, toggle: commands.toggleVoice)
  }
}

private struct VoiceButtonContent: View {
  @ObservedObject var voice: VoiceActivityModel
  let dictating: Bool
  let toggle: () -> Void
  var body: some View {
    Button(action: toggle) {
      Label(voice.phase == "listening" ? (dictating ? String(appLocalized: "结束输入") : String(appLocalized: "结束并执行"))
            : ["requesting", "processing"].contains(voice.phase) ? String(appLocalized: "取消语音") : String(appLocalized: "语音输入"),
            systemImage: voice.phase == "listening" ? "stop.fill" : "mic")
    }
    .help(dictating ? String(appLocalized: "开始或结束语音输入") : String(appLocalized: "开始或结束语音指令"))
  }
}

struct NativeVoiceStatus: View {
  @ObservedObject var commands: WorkspaceCommands
  var body: some View {
    VoiceStatusContent(voice: commands.voice, dictating: commands.speechMode == .dictation, cancel: commands.cancelVoice)
  }
}

private struct VoiceStatusContent: View {
  @ObservedObject var voice: VoiceActivityModel
  let dictating: Bool
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
      Text(voice.phase == "listening"
           ? (dictating ? String(appLocalized: "正在聆听，再点一次结束输入") : String(appLocalized: "正在聆听，再点一次结束并执行"))
           : voice.phase == "requesting" ? String(appLocalized: "正在等待语音权限…") : String(appLocalized: "正在识别…"))
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
