import Foundation

enum AugmaLinkSection: String, CaseIterable, Identifiable {
  case plugins, extensions, tools
  var id: String { rawValue }
  var title: String {
    switch self {
    case .plugins: String(appLocalized: "插件")
    case .extensions: String(appLocalized: "内置功能")
    case .tools: String(appLocalized: "本地工具")
    }
  }
}

/// Available Augma capabilities. Native features ship with the host and need no separate download.
struct AugmaExtension: Identifiable {
  let module: DemoModule
  var id: String { module.rawValue }
  var title: String { module.title }

  static let catalog: [Self] = ([.notes, .focus, .actions, .monitor, .space, .weather, .audio,
    .navigation, .camera, .browser, .commands, .device, .notifications, .settings] as [DemoModule])
    .map { Self(module: $0) }

  var detail: String {
    switch module {
    case .notes: String(appLocalized: "快速捕获笔记和待办。")
    case .focus: String(appLocalized: "专注计时、暂停和延长。")
    case .actions: String(appLocalized: "用文字或快捷入口执行日常操作。")
    case .monitor: String(appLocalized: "查看内存、CPU、磁盘和网络状态。")
    case .space: String(appLocalized: "在空间中组织应用和项目入口。")
    case .weather: String(appLocalized: "查看天气和预报。")
    case .audio: String(appLocalized: "查看正在播放和同步歌词。")
    case .navigation: String(appLocalized: "搜索地点并查看地图路线。")
    case .camera: String(appLocalized: "预览摄像头并拍照。")
    case .browser: String(appLocalized: "在 Augma 中浏览网站。")
    case .commands: String(appLocalized: "通过语音与 Augma 助手交互。")
    case .device: String(appLocalized: "查看设备和连接状态。")
    case .notifications: String(appLocalized: "查看 Augma 通知。")
    case .settings: String(appLocalized: "调整 Augma 的显示和交互。")
    case .market, .library, .plugin: ""
    }
  }

  func matches(_ query: String) -> Bool {
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return query.isEmpty || title.localizedStandardContains(query) || detail.localizedStandardContains(query)
      || id.localizedStandardContains(query)
  }
}
