import AppKit
import SwiftUI

@main
struct AugmaDesktopDemoApp: App {
  @NSApplicationDelegateAdaptor(HudAppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup("Augma Demo", id: "demo") {
      DemoContentView(enterImmersive: appDelegate.enterImmersive)
    }
    .defaultSize(width: 1100, height: 720)
    .commands {
      CommandMenu("语音") {
        Button("开始或结束语音指令") {
          NotificationCenter.default.post(name: .augmaToggleSpeech, object: nil)
        }
        .keyboardShortcut("v", modifiers: [.command, .shift])
      }
    }

    Settings {
      DeepSeekSettingsView()
    }

    MenuBarExtra("Augma", systemImage: "viewfinder") {
      MenuBarControls(model: appDelegate.model, appDelegate: appDelegate)
    }
  }
}

private struct MenuBarControls: View {
  @Environment(\.openWindow) private var openWindow
  @AppStorage("demoWindowAlwaysOnTop") private var demoWindowAlwaysOnTop = false
  @ObservedObject var model: HudModel
  let appDelegate: HudAppDelegate

  var body: some View {
    Button("打开演示") {
      if model.immersiveActive {
        appDelegate.exitImmersive()
      } else {
        openWindow(id: "demo")
      }
      NSApp.activate(ignoringOtherApps: true)
    }
    Toggle("演示窗口始终置顶", isOn: $demoWindowAlwaysOnTop)
    if model.immersiveActive {
      Menu("选择应用") {
        ForEach(DemoModule.allCases) { module in
          Button(module.title, systemImage: module.symbol) {
            appDelegate.selectImmersiveModule(module)
          }
        }
      }
      Button(model.immersiveClickThrough ? "操作悬浮界面" : "操作桌面") {
        appDelegate.toggleImmersiveInteraction()
      }
      Button("退出沉浸模式") {
        appDelegate.exitImmersive()
      }
    }
    Divider()
    Button(model.windowVisible ? "隐藏 HUD" : "显示 HUD") {
      appDelegate.toggleWindow()
    }
    Button(model.clickThrough ? "允许鼠标交互" : "启用鼠标穿透") {
      appDelegate.toggleClickThrough()
    }
    Divider()
    Button("退出 Augma") {
      NSApp.terminate(nil)
    }
  }
}
