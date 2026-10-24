import AVFoundation
import Synchronization

/// A single render thread owns all oscillator/envelope state. The main thread only
/// publishes atomic commands and volume; rendering never hops actors or takes a lock.
final class NativeAudioRenderer: @unchecked Sendable {
  static let sampleRate = 48_000.0
  static let duration = 120.0
  private static let totalFrames = 5_760_000
  private static let fadeFrames = 1_200
  private let command = Atomic<UInt64>(0)
  private let volume = Atomic<Double>(0.35)

  // Everything below this line is exclusively accessed by the render callback.
  private var appliedCommand: UInt64 = 0
  private var pendingCommand: UInt64?
  private var position = 0
  private var active = false
  private var envelope = 0.0
  private var gain = 0.0
  private var phase0 = 0.0, phase1 = 0.0, phase2 = 0.0
  private var increment0 = 0.0, increment1 = 0.0, increment2 = 0.0

  /// One writer (the main actor) packs position, track, play intent and revision in
  /// a single word so the audio callback cannot observe a partially updated seek.
  func request(trackIndex: Int, elapsed: Double, playing: Bool) {
    let safeElapsed = elapsed.isFinite ? min(Self.duration, max(0, elapsed)) : 0
    let frame = UInt64(safeElapsed * Self.sampleRate)
    let safeTrack = min(2, max(0, trackIndex))
    let nextRevision = ((command.load(ordering: .relaxed) >> 32) &+ 1) & 0xffff_ffff
    let value = (nextRevision << 32) | (UInt64(safeTrack) << 24) | frame | (playing ? 1 << 26 : 0)
    command.store(value, ordering: .releasing)
  }

  func setVolume(_ value: Double) { volume.store(value, ordering: .relaxed) }

  func render(_ frameCount: AVAudioFrameCount, into output: UnsafeMutablePointer<AudioBufferList>, silence: UnsafeMutablePointer<ObjCBool>) -> OSStatus {
    let requested = command.load(ordering: .acquiring)
    if requested != appliedCommand { pendingCommand = requested }
    let buffers = UnsafeMutableAudioBufferListPointer(output)
    let targetGain = volume.load(ordering: .relaxed) * 0.065
    let envelopeStep = 1.0 / Double(Self.fadeFrames)
    // Approximately a 50 ms smoothing constant for user volume changes.
    let gainSmoothing = 1.0 - exp(-1.0 / (Self.sampleRate * 0.05))
    var audible = false

    for frame in 0..<Int(frameCount) {
      if let pendingCommand, envelope <= 0 {
        apply(pendingCommand)
        self.pendingCommand = nil
      }
      let targetEnvelope = pendingCommand == nil && active ? 1.0 : 0.0
      envelope += min(envelopeStep, max(-envelopeStep, targetEnvelope - envelope))
      gain += (targetGain - gain) * gainSmoothing
      var sample: Float = 0
      if active, position < Self.totalFrames {
        let remainingEnvelope = min(1, Double(Self.totalFrames - position) / Double(Self.fadeFrames))
        sample = Float((sin(phase0) + sin(phase1) + sin(phase2)) * gain * envelope * remainingEnvelope)
        phase0 = advance(phase0, by: increment0)
        phase1 = advance(phase1, by: increment1)
        phase2 = advance(phase2, by: increment2)
        position += 1
        if position >= Self.totalFrames { active = false }
      }
      if sample != 0 { audible = true }
      for buffer in buffers {
        buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = sample
      }
    }
    silence.pointee = ObjCBool(!audible)
    return noErr
  }

  private func apply(_ value: UInt64) {
    appliedCommand = value
    position = Int(value & 0x00ff_ffff)
    let trackIndex = Int((value >> 24) & 3)
    active = value & (1 << 26) != 0 && position < Self.totalFrames
    // No allocation or library lookup on the real-time thread.
    let notes: (Double, Double, Double)
    switch trackIndex {
    case 1: notes = (196, 246.94, 293.66)
    case 2: notes = (164.81, 207.65, 246.94)
    default: notes = (174.61, 220, 261.63)
    }
    increment0 = 2 * .pi * notes.0 / Self.sampleRate
    increment1 = 2 * .pi * notes.1 * pow(2, 2.0 / 1200) / Self.sampleRate
    increment2 = 2 * .pi * notes.2 * pow(2, 4.0 / 1200) / Self.sampleRate
    phase0 = (Double(position) * increment0).truncatingRemainder(dividingBy: 2 * .pi)
    phase1 = (Double(position) * increment1).truncatingRemainder(dividingBy: 2 * .pi)
    phase2 = (Double(position) * increment2).truncatingRemainder(dividingBy: 2 * .pi)
  }

  private func advance(_ phase: Double, by increment: Double) -> Double {
    let next = phase + increment
    return next >= 2 * .pi ? next - 2 * .pi : next
  }
}
