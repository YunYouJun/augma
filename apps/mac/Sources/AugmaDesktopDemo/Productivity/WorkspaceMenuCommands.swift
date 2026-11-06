import SwiftUI

struct WorkspaceMenuCommands: Commands {
  @Environment(\.openWindow) private var openWindow
  let appDelegate: HudAppDelegate
  var body: some Commands {
    CommandMenu(String(appLocalized: "日常")) {
      Button(String(appLocalized: "快速记录")) { setup(); appDelegate.showQuickCapture() }
        .keyboardShortcut("n", modifiers: [.command, .shift])
      Button(String(appLocalized: "打开 Microsoft To Do")) { appDelegate.captures.openDestination(.microsoftToDo) }
        .keyboardShortcut("t", modifiers: [.command, .option])
      Button(String(appLocalized: "快捷指令")) { setup(); appDelegate.showCommands() }
        .keyboardShortcut("k", modifiers: .command)
      Button(String(appLocalized: "专注计时")) { setup(); appDelegate.openModule(.focus) }
        .keyboardShortcut("f", modifiers: [.command, .option])
      Button(String(appLocalized: "悬浮计时")) { openWindow(id: "focus-timer") }
      Divider()
      Button(String(appLocalized: "系统监控")) { setup(); appDelegate.openModule(.monitor) }
        .keyboardShortcut("m", modifiers: [.command, .option])
      Button(String(appLocalized: "Augma Link · 扩展中心")) { setup(); appDelegate.openModule(.market) }
      Button(String(appLocalized: "应用列表")) { setup(); appDelegate.openModule(.library) }
      Button(String(appLocalized: "天气")) { setup(); appDelegate.openModule(.weather) }
    }
  }
  private func setup() { appDelegate.openScene = { openWindow(id: $0) } }
}
