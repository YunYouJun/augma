import Foundation

extension NativeDemoModel {
  func performAssistantWorkspaceCommand(_ command: WorkspaceCommand) -> NativeAssistantResult {
    performingAssistantAction = true
    defer { performingAssistantAction = false }
    switch command {
    case .open(let module):
      selection = module
      if module == .space { preferences.value.showHud = true }
      return .init(message: String(format: assistant.text("已打开 %@。"), assistant.text(module.localizationKey)))
    case .space(let action):
      performSpaceAction(action)
      return .init(message: assistant.text("已将操作交给原生空间。"))
    default:
      guard let commands else { return .init(message: assistant.text("当前无法执行。请检查已有计时、输入内容或操作状态。"), isError: true) }
      let success = commands.execute(command)
      if !success { return .init(message: commands.result ?? assistant.text("当前无法执行这条指令。"), isError: true) }
      let key: String
      switch command {
      case .note, .task: key = "已加入待发送列表，可在快速记录中查看结果。"
      case .startFocus: key = "计时已开始，关闭主窗口后仍会继续。"
      case .pause: key = "计时已暂停。"
      case .resume: key = "计时已继续。"
      case .extend: key = "已延长 5 分钟。"
      case .cancel: key = "计时已结束。"
      case .undo: key = "已撤销上一步。"
      case .audio(.play): key = "已开始播放。"
      case .audio(.pause): key = "已暂停播放。"
      case .audio(.next): key = "已切换到下一首。"
      case .audio(.previous): key = "已切换到上一首。"
      default: key = commands.result ?? ""
      }
      return .init(message: assistant.text(key))
    }
  }

  func performAssistantAction(_ action: NativeAssistantAction) -> NativeAssistantResult {
    performingAssistantAction = true
    defer { performingAssistantAction = false }
    let destination: DemoModule?
    switch action {
    case .map: destination = .navigation
    case .weather: destination = .weather
    case .notifications: destination = .notifications
    case .settings: destination = .settings
    case .camera: destination = .camera
    case .browser: destination = .browser
    default: destination = nil
    }
    if let destination {
      selection = destination
      return .init(message: String(format: assistant.text("已打开 %@。"), assistant.text(destination.localizationKey)))
    }
    switch action {
    case .scan: performSpaceAction(.scan)
    case .routeStart: performSpaceAction(.routeStart)
    case .routeNext: performSpaceAction(.routeNext)
    case .routeStop: performSpaceAction(.routeStop)
    case .audio, .audioPause:
      guard let audio else { return .init(message: assistant.text("声音暂不可用。"), isError: true) }
      if action == .audio { audio.play() } else { audio.pause() }
      if let error = audio.error { return .init(message: error, isError: true) }
      return .init(message: action == .audio ? assistant.text("已开始播放。") : assistant.text("已暂停播放。"))
    case .hide, .show:
      preferences.value.showHud = action == .show
      selection = .space
      return .init(message: action == .show ? assistant.text("显示 HUD") : assistant.text("隐藏 HUD"))
    case .dark, .light:
      preferences.value.dark = action == .dark
      return .init(message: action == .dark ? assistant.text("深色视界") : assistant.text("浅色视界"))
    default: break
    }
    return .init(message: assistant.text("已将操作交给原生空间。"))
  }
}
