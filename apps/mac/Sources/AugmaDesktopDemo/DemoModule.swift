import Foundation

enum DemoModule: String, CaseIterable, Identifiable {
  case notes, focus, actions, monitor
  case weather, audio, space, camera, navigation, browser
  case notifications, settings, commands, device

  var id: String { rawValue }

  static let dock: [DemoModule] = [.weather, .audio, .space, .camera, .navigation, .browser]
  static let system: [DemoModule] = [.monitor, .notifications, .settings, .commands, .device]
  static let productivity: [DemoModule] = [.notes, .focus, .actions]
  static let applications = dock + system.filter { $0 != .monitor }
  var isProductivity: Bool { Self.productivity.contains(self) }

  var title: String { NSLocalizedString(localizationKey, comment: "") }

  var localizationKey: String {
    switch self {
    case .notes: "快速记录"
    case .focus: "专注计时"
    case .actions: "快捷指令"
    case .monitor: "系统监控"
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
