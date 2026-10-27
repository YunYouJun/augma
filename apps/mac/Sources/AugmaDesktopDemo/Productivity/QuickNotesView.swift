import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct QuickNotesView: View {
  @ObservedObject var store: WorkspaceStore
  @ObservedObject var commands: WorkspaceCommands
  @State private var search = ""
  @State private var editing: QuickNote?
  @State private var exportDocument = NotesDocument(text: "")
  @State private var exporting = false

  private var notes: [QuickNote] {
    let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
    return store.data.notes.filter { query.isEmpty || $0.text.localizedStandardContains(query) }
  }

  var body: some View {
    NativePage {
      VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
        NoteComposer(store: store, commands: commands)
        WorkspaceSaveStatus(store: store)
      }
      .nativeCard()
      VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
        Text("待发送与历史记录").font(.headline)
        HStack(spacing: NativePageLayout.itemSpacing) {
          TextField("搜索记录", text: $search).textFieldStyle(.roundedBorder)
            .accessibilityLabel("搜索记录")
          Button("导出记录", systemImage: "square.and.arrow.up") { export(notes) }
            .fixedSize(horizontal: true, vertical: false)
            .disabled(notes.isEmpty)
        }
      }
      LazyVStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
        ForEach(notes) { note in
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text(note.updatedAt, format: .dateTime.year().month().day().hour().minute())
                .font(.caption).foregroundStyle(.secondary)
              Spacer()
              Menu {
                Button("编辑记录", systemImage: "pencil") { editing = note }
                  .disabled(note.delivery?.status == .sending || note.delivery?.status == .uncertain)
                Button("复制", systemImage: "doc.on.doc") {
                  NSPasteboard.general.clearContents()
                  NSPasteboard.general.setString(note.text, forType: .string)
                  commands.feedback(String(localized: "已复制记录。"))
                }
                Button("导出记录", systemImage: "square.and.arrow.up") { export([note]) }
                Divider()
                Button("删除记录", role: .destructive) {
                  store.deleteNote(note.id)
                  commands.feedback(String(localized: "记录已删除，可以撤销。"))
                }
                .disabled(note.delivery?.status == .sending)
              } label: { Image(systemName: "ellipsis") }
              .menuStyle(.borderlessButton).fixedSize()
              .accessibilityLabel("记录操作")
            }
            Text(note.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            if let captures = commands.captures { CaptureDeliveryControls(note: note, captures: captures) }
          }
          .nativeCard()
          .accessibilityElement(children: .contain)
        }
      }
      .frame(minHeight: notes.isEmpty ? 160 : 0)
      .overlay {
        if notes.isEmpty {
          ContentUnavailableView(search.isEmpty ? "没有待发送的记录" : "没有匹配的记录", systemImage: "checkmark.circle")
        }
      }
      WorkspaceResultView(commands: commands, store: store)
    }
    .sheet(item: $editing) { note in NoteEditor(note: note, store: store) }
    .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .plainText, defaultFilename: "Augma Notes.md") { result in
      if case .failure = result { commands.feedback(String(localized: "导出失败，请选择其他保存位置重试。"), error: true) }
    }
  }

  private func export(_ notes: [QuickNote]) {
    exportDocument = NotesDocument(text: notes.map { "## \($0.createdAt.formatted())\n\n\($0.text)" }.joined(separator: "\n\n---\n\n"))
    exporting = true
  }
}

struct NoteComposer: View {
  @ObservedObject var store: WorkspaceStore
  @ObservedObject var commands: WorkspaceCommands
  @State private var showingConnections = false

  var body: some View {
    VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: NativePageLayout.itemSpacing) {
          destinationPicker
          connectionsButton
        }
        .fixedSize(horizontal: true, vertical: false)
        VStack(alignment: .leading, spacing: NativePageLayout.itemSpacing) {
          destinationPicker
          connectionsButton
        }
      }
      TextField("记下想法、待办或一句话…", text: Binding(get: { store.data.noteDraft }, set: store.updateDraft), axis: .vertical)
        .lineLimit(3...6).textFieldStyle(.roundedBorder)
        .multilineTextAlignment(.leading)
        .accessibilityLabel("记下想法、待办或一句话…")
        .disabled(!store.writable)
      HStack(spacing: NativePageLayout.itemSpacing) {
        Text("草稿保存在此 Mac").font(.caption).foregroundStyle(.secondary)
        Spacer()
        Button("发送记录", systemImage: "paperplane") {
          _ = commands.captures?.submit(store.data.noteDraft, clearDraft: true)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .fixedSize(horizontal: true, vertical: false)
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(commands.captures == nil || !store.writable || store.data.noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
      if let captures = commands.captures { CaptureFeedbackView(captures: captures) }
    }
    .sheet(isPresented: $showingConnections) {
      if let captures = commands.captures {
        VStack {
          CaptureConnectionsView(captures: captures)
          Button("完成") { showingConnections = false }.keyboardShortcut(.cancelAction).padding(.bottom)
        }
        .frame(width: 540, height: 560)
      }
    }
  }

  private var destinationPicker: some View {
    Picker("记录类型", selection: Binding(get: { store.data.captureDestination ?? .appleNotes }, set: store.selectCaptureDestination)) {
      Text("笔记 → 备忘录").tag(CaptureDestination.appleNotes)
      Text("待办 → To Do").tag(CaptureDestination.microsoftToDo)
    }
    .labelsHidden()
  }

  private var connectionsButton: some View {
    Button("连接设置") { showingConnections = true }
      .fixedSize(horizontal: true, vertical: false)
  }
}

private struct NoteEditor: View {
  let note: QuickNote
  @ObservedObject var store: WorkspaceStore
  @Environment(\.dismiss) private var dismiss
  @State private var text: String
  @State private var conflict = false

  init(note: QuickNote, store: WorkspaceStore) { self.note = note; self.store = store; _text = State(initialValue: note.text) }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("编辑记录").font(.headline)
      TextEditor(text: $text).font(.body).frame(minHeight: 220)
      if conflict { Text("记录已在其他窗口修改或删除。请复制当前内容后重新打开，避免覆盖。") .foregroundStyle(.red) }
      HStack {
        Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
        Spacer()
        Button("保存") {
          if store.editNote(note.id, text: text, expected: note.text) { dismiss() } else { conflict = true }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 20_000)
      }
    }
    .padding(NativePageLayout.pagePadding).frame(width: 480)
    .controlSize(.regular)
  }
}

struct NotesDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.plainText] }
  var text: String
  init(text: String) { self.text = text }
  init(configuration: ReadConfiguration) throws { text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self) }
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}

struct WorkspaceSaveStatus: View {
  @ObservedObject var store: WorkspaceStore
  var body: some View {
    if let error = store.saveError {
      VStack(alignment: .leading, spacing: 8) {
        Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
        ViewThatFits(in: .horizontal) {
          HStack(spacing: NativePageLayout.itemSpacing) { saveActions }
            .fixedSize(horizontal: true, vertical: false)
          VStack(alignment: .leading, spacing: 8) { saveActions }
        }
      }
      .font(.callout)
    } else {
      Label(store.saving ? "正在保存…" : "已保存在此 Mac", systemImage: store.saving ? "arrow.triangle.2.circlepath" : "checkmark.circle")
        .font(.caption).foregroundStyle(.secondary)
    }
  }

  @ViewBuilder private var saveActions: some View {
    if store.writable { Button("重试保存") { store.retrySave() } }
    else { Button("恢复备份") { Task { await store.restoreBackup() } } }
    Button("显示数据文件") { NSWorkspace.shared.activateFileViewerSelecting([store.fileURL]) }
  }
}
