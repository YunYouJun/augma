import AppKit
import SwiftUI

@main
struct AugmaDesktopDemoApp: App {
  @NSApplicationDelegateAdaptor(HudAppDelegate.self) private var appDelegate
  @AppStorage(WeChatVoiceShortcut.storageKey) private var weChatVoiceShortcut = WeChatVoiceShortcut.defaultValue

  var body: some Scene {
    WindowGroup("Augma Demo", id: "demo") {
      DemoContentView(appDelegate: appDelegate).appLocalized()
        .environmentObject(appDelegate.sessions)
    }
    .defaultSize(width: 1100, height: 720)
    .commands {
      NativeDemoCommands()
      WorkspaceMenuCommands(appDelegate: appDelegate)
      MenuBarShelfCommands(store: appDelegate.menuBarShelf)
      ImmersiveAssistantCommands(store: appDelegate.immersiveShortcut, toggle: appDelegate.toggleImmersiveAssistant)
      CommandMenu(String(appLocalized: "语音")) {
        Button(VoiceShortcut.title) {
          if appDelegate.model.immersiveActive {
            appDelegate.selectImmersiveModule(.actions)
            appDelegate.commands.toggleVoice(mode: .command)
          } else { appDelegate.showCommands(voice: true) }
        }
        .keyboardShortcut(VoiceShortcut.defaultKey, modifiers: VoiceShortcut.defaultModifiers)
        Button(String(appLocalized: "语音输入")) { appDelegate.startVoiceInput() }
          .keyboardShortcut(weChatVoiceShortcut.keyboardShortcut)
        Button(WeChatVoiceInput.title) { appDelegate.startWeChatVoiceInput() }
      }
    }

    Window(String(appLocalized: "专注计时"), id: "focus-timer") {
      FloatingFocusView(store: appDelegate.workspace, commands: appDelegate.commands).appLocalized()
    }
    .windowResizability(.contentSize)
    .defaultLaunchBehavior(.suppressed)

    Settings {
      NativeAppSettingsView(monitor: appDelegate.monitor, preferences: appDelegate.preferences,
                            immersiveShortcut: appDelegate.immersiveShortcut, menuBarShelf: appDelegate.menuBarShelf,
                            captures: appDelegate.captures,
                            navigation: appDelegate.navigation, sessions: appDelegate.sessions,
                            startVoiceInput: appDelegate.startVoiceInput).appLocalized()
    }

    // Keep the status item static: custom observed labels can loop while macOS
    // rasterizes them. The popup owns the live countdown and editable controls.
    MenuBarExtra("Augma", systemImage: "viewfinder") {
      MenuBarControls(hud: appDelegate.model, sessions: appDelegate.sessions, appDelegate: appDelegate).appLocalized()
    }
    .menuBarExtraStyle(.window)
  }
}
