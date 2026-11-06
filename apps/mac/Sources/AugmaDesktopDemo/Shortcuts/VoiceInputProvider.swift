import Foundation

enum VoiceInputProvider: String, CaseIterable, Identifiable {
  case apple, weChat

  static let storageKey = "augma.voice-input.provider"
  static var current: Self { read(from: .standard) }
  static func read(from defaults: UserDefaults) -> Self {
    Self(rawValue: defaults.string(forKey: storageKey) ?? "") ?? .apple
  }
  var id: Self { self }
  var title: String {
    switch self {
    case .apple: String(appLocalized: "Apple 原生识别")
    case .weChat: String(appLocalized: "微信语音输入")
    }
  }
}
