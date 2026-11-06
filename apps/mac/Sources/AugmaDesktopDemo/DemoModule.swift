import Foundation

enum DemoModule: String, CaseIterable, Identifiable {
  case notes, focus, actions, monitor
  case weather, audio, space, camera, navigation, browser
  case notifications, settings, commands, device, market, library, plugin

  var id: String { rawValue }

  static let dock: [DemoModule] = [.weather, .audio, .space, .camera, .navigation, .browser]
  static let system: [DemoModule] = [.monitor, .market, .library, .notifications, .settings, .commands, .device]
  static let productivity: [DemoModule] = [.notes, .focus, .actions]
  // Keep existing Command-1…9 destinations stable when adding discovery entries.
  static let applications = dock + system.filter { ![.monitor, .market, .library].contains($0) } + [.market, .library]
  var isProductivity: Bool { Self.productivity.contains(self) }

  var title: String { NativeLocalization.string(localizationKey) }

  var localizationKey: String {
    switch self {
    case .notes: "快速记录"
    case .focus: "专注计时"
    case .actions: "快捷指令"
    case .monitor: "系统监控"
    case .market: "Augma Link · 扩展中心"
    case .library: "应用列表"
    case .plugin: "插件"
    case .weather: "天气"
    case .audio: "声音"
    case .space: "空间"
    case .camera: "摄像头"
    case .navigation: "导航"
    case .browser: "网页"
    case .notifications: "通知"
    case .settings: "设置"
    case .commands: "语音指令"
    case .device: "设备"
    }
  }

  var symbol: String {
    switch self {
    case .notes: "square.and.pencil"
    case .focus: "timer"
    case .actions: "command"
    case .monitor: "gauge.with.dots.needle.50percent"
    case .market: "puzzlepiece.extension"
    case .library: "square.grid.2x2"
    case .plugin: "puzzlepiece.extension"
    case .weather: "cloud.sun"
    case .audio: "waveform"
    case .space: "viewfinder"
    case .camera: "camera"
    case .navigation: "location"
    case .browser: "globe"
    case .notifications: "bell"
    case .settings: "gearshape"
    case .commands: "mic"
    case .device: "macbook"
    }
  }
}
