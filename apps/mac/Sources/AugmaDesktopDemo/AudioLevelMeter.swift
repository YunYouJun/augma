import Accelerate
import AVFoundation

/// Owned by one audio tap, used only on that tap's serial callback queue.
/// No audio buffers escape the callback, and UI delivery is limited to 20 Hz.
final class AudioLevelMeter: @unchecked Sendable {
  private var framesSinceSample: AVAudioFrameCount = 0

  func consume(_ buffer: AVAudioPCMBuffer) -> Double? {
    framesSinceSample += buffer.frameLength
    let interval = AVAudioFrameCount(max(1, buffer.format.sampleRate / 20))
    guard framesSinceSample >= interval else { return nil }
    framesSinceSample %= interval
    guard buffer.frameLength > 0, let channels = buffer.floatChannelData else { return 0 }
    var peakRMS: Float = 0
    for channel in 0..<Int(buffer.format.channelCount) {
      var rms: Float = 0
      vDSP_rmsqv(channels[channel], vDSP_Stride(buffer.stride), &rms, vDSP_Length(buffer.frameLength))
      peakRMS = max(peakRMS, rms)
    }
    return Self.normalizedLevel(rms: Double(peakRMS))
  }

  static func normalizedLevel(rms: Double) -> Double {
    guard rms.isFinite, rms > 0 else { return 0 }
    return min(1, max(0, (20 * log10(rms) + 55) / 55))
  }
}
