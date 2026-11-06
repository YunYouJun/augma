import SwiftUI

/// Shared by the popup and Settings so edits apply immediately and survive relaunches.
struct NativeMenuBarPreferences: DynamicProperty {
  @AppStorage("augma.menu-bar-content.commands") var commands = true
  @AppStorage("augma.menu-bar-content.voice-input") var voiceInput = true
  @AppStorage("augma.menu-bar-content.quick-capture") var quickCapture = true
  @AppStorage("augma.menu-bar-content.focus-timer") var focusTimer = true
  @AppStorage("augma.menu-bar-content.craft-hub") var craftHub = true
  @AppStorage("augma.menu-bar-content.system-monitor") var systemMonitor = true
}

struct NativeMenuBarContentSettings: View {
  private var preferences = NativeMenuBarPreferences()

  var body: some View {
    Section("菜单显示内容") {
      Toggle("快捷指令", isOn: preferences.$commands)
      Toggle("语音输入", isOn: preferences.$voiceInput)
      Toggle("快速记录", isOn: preferences.$quickCapture)
      Toggle("专注计时", isOn: preferences.$focusTimer)
      Toggle("Craft Hub · 今日重点", isOn: preferences.$craftHub)
      Toggle("系统监控", isOn: preferences.$systemMonitor)
      Text("选择在 Augma 菜单栏面板中显示的内容，修改立即生效并在重启后保留。隐藏快速记录会保留草稿；仍可从主窗口或快捷键打开各项功能。")
        .font(.caption).foregroundStyle(.secondary)
    }
  }
}
