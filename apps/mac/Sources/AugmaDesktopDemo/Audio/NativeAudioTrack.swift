import Foundation

struct NativeAudioTrack: Identifiable, Equatable, Sendable {
  let id: String
  let name: String
  let subtitle: String
  let frequencies: [Double]

  static let library = [
    NativeAudioTrack(id: "echo", name: String(localized: "光的回声"), subtitle: String(localized: "柔和的正弦和弦"), frequencies: [174.61, 220, 261.63]),
    NativeAudioTrack(id: "drift", name: String(localized: "浮游时刻"), subtitle: String(localized: "缓慢漂浮的泛音"), frequencies: [196, 246.94, 293.66]),
    NativeAudioTrack(id: "letter", name: String(localized: "远方来信"), subtitle: String(localized: "留一点空间给自己"), frequencies: [164.81, 207.65, 246.94]),
  ]
}

/// UI-independent transport operations make the store testable without opening an audio device.
@MainActor
protocol NativeAudioEngineBackend: AnyObject {
  var onConfigurationChange: (() -> Void)? { get set }
  func play(trackIndex: Int, from elapsed: TimeInterval) throws
  func pause()
  func setVolume(_ fraction: Double)
  func reset()
  func stop()
}
