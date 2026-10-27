import SwiftUI

struct WorkspaceMenuCommands: Commands {
  @Environment(\.openWindow) private var openWindow
  let appDelegate: HudAppDelegate
  var body: some Commands {
    CommandMenu("日常") {
      Button("快速记录") { setup(); appDelegate.openModule(.notes) }
        .keyboardShortcut("n", modifiers: [.command, .shift])
      Button("打开 Microsoft To Do") { appDelegate.captures.openDestination(.microsoftToDo) }
        .keyboardShortcut("t", modifiers: [.command, .option])
      Button("快捷指令") { setup(); appDelegate.showCommands() }
        .keyboardShortcut("k", modifiers: .command)
      Button("专注计时") { setup(); appDelegate.openModule(.focus) }
        .keyboardShortcut("f", modifiers: [.command, .option])
      Button("悬浮计时") { openWindow(id: "focus-timer") }
      Divider()
      Button("系统监控") { setup(); appDelegate.openModule(.monitor) }
        .keyboardShortcut("m", modifiers: [.command, .option])
      Button("应用市场") { setup(); appDelegate.openModule(.market) }
      Button("天气") { setup(); appDelegate.openModule(.weather) }
    }
  }
  private func setup() { appDelegate.openScene = { openWindow(id: $0) } }
}

struct CommandUtilityView: View {
  @Environment(\.openWindow) private var openWindow
  let appDelegate: HudAppDelegate
  var body: some View {
    WorkspaceCommandView(commands: appDelegate.commands, store: appDelegate.workspace, compact: true)
      .frame(minWidth: 520, minHeight: 420)
      .onAppear { appDelegate.openScene = { openWindow(id: $0) } }
      .onDisappear { appDelegate.commands.cancelVoice() }
  }
}
