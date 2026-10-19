import Foundation

enum DemoModule: String, CaseIterable, Identifiable {
  case weather, audio, space, camera, navigation
  case notifications, settings, commands, device

  var id: String { rawValue }

  static let dock: [DemoModule] = [.weather, .audio, .space, .camera, .navigation]
  static let system: [DemoModule] = [.notifications, .settings, .commands, .device]

  var title: String {
    switch self {
    case .weather: String(localized: "天气")
    case .audio: String(localized: "声音")
    case .space: String(localized: "空间")
    case .camera: String(localized: "摄像头")
    case .navigation: String(localized: "导航")
    case .notifications: String(localized: "通知")
    case .settings: String(localized: "设置")
    case .commands: String(localized: "语音指令")
    case .device: String(localized: "设备")
    }
  }

  var symbol: String {
    switch self {
    case .weather: "cloud.sun"
    case .audio: "waveform"
    case .space: "viewfinder"
    case .camera: "camera"
    case .navigation: "location"
    case .notifications: "bell"
    case .settings: "gearshape"
    case .commands: "mic"
    case .device: "macbook"
    }
  }
}
