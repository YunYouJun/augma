import AppKit
import SwiftUI

@main
struct AugmaDesktopDemoApp: App {
  @NSApplicationDelegateAdaptor(HudAppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup("Augma Demo", id: "demo") {
      DemoContentView(appDelegate: appDelegate)
        .environmentObject(appDelegate.sessions)
    }
    .defaultSize(width: 1100, height: 720)
    .commands {
      NativeDemoCommands()
      WorkspaceMenuCommands(appDelegate: appDelegate)
      ImmersiveAssistantCommands(store: appDelegate.immersiveShortcut, toggle: appDelegate.toggleImmersiveAssistant)
      CommandMenu("语音") {
        Button(VoiceShortcut.title) {
          if appDelegate.model.immersiveActive {
            appDelegate.selectImmersiveModule(.actions)
            appDelegate.commands.toggleVoice()
          } else { appDelegate.showCommands(voice: true) }
        }
        .keyboardShortcut(VoiceShortcut.defaultKey, modifiers: VoiceShortcut.defaultModifiers)
      }
    }

    Window("快捷指令", id: "quick-command") {
      CommandUtilityView(appDelegate: appDelegate)
    }
    .defaultSize(width: 560, height: 520)
    .windowResizability(.contentMinSize)
    .defaultLaunchBehavior(.suppressed)
    .restorationBehavior(.disabled)

    Window("专注计时", id: "focus-timer") {
      FloatingFocusView(store: appDelegate.workspace, commands: appDelegate.commands)
    }
    .windowResizability(.contentSize)
    .defaultLaunchBehavior(.suppressed)

    Settings {
      NativeAppSettingsView(monitor: appDelegate.monitor, preferences: appDelegate.preferences,
                            immersiveShortcut: appDelegate.immersiveShortcut, captures: appDelegate.captures)
    }

    // Keep the status item static: custom observed labels can loop while macOS
    // rasterizes them. The popup owns the live countdown and editable controls.
    MenuBarExtra("Augma", systemImage: "viewfinder") {
      MenuBarControls(hud: appDelegate.model, sessions: appDelegate.sessions, appDelegate: appDelegate)
    }
    .menuBarExtraStyle(.window)
  }
}
