import Foundation

enum DemoModule: String, CaseIterable, Identifiable {
  case weather, audio, space, camera, navigation
  case notifications, settings, commands, device

  var id: String { rawValue }

  static let dock: [DemoModule] = [.weather, .audio, .space, .camera, .navigation]
  static let system: [DemoModule] = [.notifications, .settings, .commands, .device]

  var title: String {
    switch self {
    case .weather: "天气"
    case .audio: "声音"
    case .space: "空间"
    case .camera: "摄像头"
    case .navigation: "导航"
    case .notifications: "通知"
    case .settings: "设置"
    case .commands: "语音指令"
    case .device: "设备"
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
