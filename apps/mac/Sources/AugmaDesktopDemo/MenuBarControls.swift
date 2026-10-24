import AppKit
import SwiftUI

struct MenuBarControls: View {
  @AppStorage("demoWindowAlwaysOnTop") private var alwaysOnTop = false
  @Environment(\.openWindow) private var openWindow
  @Environment(\.openSettings) private var openSettings
  @ObservedObject var hud: HudModel
  @ObservedObject var sessions: DemoSessionRegistry
  let appDelegate: HudAppDelegate

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text("Augma").font(.headline)
        Spacer()
        Button("快捷指令", systemImage: "command") { appDelegate.showCommands() }
        Button("语音输入", systemImage: "mic") { appDelegate.showCommands(voice: true) }
      }
      WorkspaceMenuContent(store: appDelegate.workspace, commands: appDelegate.commands)
      Divider()
      SystemMonitorMenuSection(store: appDelegate.monitor) { appDelegate.openModule(.monitor) }
      Divider()
      HStack {
        Button("打开主窗口", systemImage: "macwindow") { appDelegate.openModule() }
        Spacer()
        Menu("更多", systemImage: "ellipsis") {
          ForEach(DemoModule.productivity) { module in
            Button(module.title, systemImage: module.symbol) { appDelegate.openModule(module) }
          }
          Button("悬浮计时", systemImage: "pin") { openWindow(id: "focus-timer") }
          Menu("演示应用") {
            ForEach(DemoModule.applications) { module in
              Button(module.title, systemImage: module.symbol) {
                if hud.immersiveActive { appDelegate.selectImmersiveModule(module) }
                else { appDelegate.openModule(module) }
              }
            }
          }
          SessionPlaybackMenu(audio: appDelegate.audio)
          Toggle("始终置顶", isOn: $alwaysOnTop)
          Button(hud.immersiveVisible ? "隐藏沉浸助手" : "唤起沉浸助手") { appDelegate.toggleImmersiveAssistant() }
          if hud.immersiveActive {
            Button(hud.immersiveClickThrough ? "操作 Augma" : "操作桌面") { appDelegate.toggleImmersiveInteraction() }
            Button("退出沉浸模式") { appDelegate.exitImmersive() }
          }
          Button(hud.windowVisible ? "隐藏辅助 HUD" : "显示辅助 HUD") { appDelegate.toggleWindow() }
          if hud.windowVisible {
            Button(hud.clickThrough ? "允许鼠标交互" : "启用鼠标穿透") { appDelegate.toggleClickThrough() }
          }
          Divider()
          Button("设置…") { NSApp.activate(ignoringOtherApps: true); openSettings() }
          Button("退出 Augma") { NSApp.terminate(nil) }
        }
        .menuStyle(.borderlessButton).fixedSize()
      }
    }
    .padding(16).frame(width: 400)
    .onAppear {
      appDelegate.openScene = { openWindow(id: $0) }
      appDelegate.workspace.reconcile()
    }
  }
}

private struct WorkspaceMenuContent: View {
  @ObservedObject var store: WorkspaceStore
  @ObservedObject var commands: WorkspaceCommands
  var body: some View {
    NoteComposer(store: store, commands: commands)
    Divider()
    if store.data.focus != nil {
      FocusTimerReadout(session: store.data.focus)
      FocusTimerControls(store: store, commands: commands)
    }
    if store.data.focus == nil || store.data.focus?.status == .completed {
      HStack {
        Button("专注 25 分钟") { commands.execute(.startFocus(1500), actionID: "focus25") }
        Button("休息 5 分钟") { commands.execute(.startFocus(300), actionID: "focus5") }
      }
      .disabled(!store.writable)
    }
    WorkspaceSaveStatus(store: store)
    WorkspaceResultView(commands: commands, store: store)
  }
}

private struct SessionPlaybackMenu: View {
  @ObservedObject var audio: NativeAudioStore
  var body: some View {
    Button(audio.playing ? String(localized: "暂停声音") : String(localized: "播放声音"), systemImage: audio.playing ? "pause.fill" : "play.fill") {
      if audio.playing { audio.pause() }
      else { audio.play() }
    }
    .disabled(audio.busy)
  }
}
