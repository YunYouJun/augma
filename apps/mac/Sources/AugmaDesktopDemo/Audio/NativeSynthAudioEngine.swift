import AVFoundation
import Combine

@MainActor
final class NativeSynthAudioEngine: NativeAudioEngineBackend {
  var onConfigurationChange: (() -> Void)?
  private var engine: AVAudioEngine?
  private var renderer: NativeAudioRenderer?
  private var configurationObserver: AnyCancellable?
  private var pauseTask: Task<Void, Never>?
  private var volume = 0.35
  private var trackIndex = 0
  private var elapsed = 0.0

  func play(trackIndex: Int, from elapsed: TimeInterval) throws {
    pauseTask?.cancel()
    pauseTask = nil
    if engine == nil { configure() }
    self.trackIndex = trackIndex
    self.elapsed = elapsed
    renderer?.request(trackIndex: trackIndex, elapsed: elapsed, playing: true)
    try engine?.start()
  }

  func pause() {
    pauseTask?.cancel()
    guard engine != nil else { pauseTask = nil; return }
    renderer?.request(trackIndex: trackIndex, elapsed: elapsed, playing: false)
    // Give the audio callback time to fade to zero before suspending the engine.
    // This task runs only during the transition, never as a background polling loop.
    pauseTask = Task { [weak self] in
      do { try await Task.sleep(for: .milliseconds(60)) }
      catch { return }
      self?.engine?.pause()
      self?.pauseTask = nil
    }
  }

  func setVolume(_ fraction: Double) {
    volume = fraction
    renderer?.setVolume(fraction)
  }

  func reset() { stop() }

  func stop() {
    pauseTask?.cancel()
    pauseTask = nil
    configurationObserver = nil
    engine?.stop()
    engine = nil
    renderer = nil
  }

  private func configure() {
    let engine = AVAudioEngine()
    let renderer = NativeAudioRenderer()
    renderer.setVolume(volume)
    let format = AVAudioFormat(standardFormatWithSampleRate: NativeAudioRenderer.sampleRate, channels: 2)!
    let source = Self.makeSource(renderer: renderer, format: format)
    engine.attach(source)
    engine.connect(source, to: engine.mainMixerNode, format: format)
    engine.prepare()
    self.engine = engine
    self.renderer = renderer
    configurationObserver = NotificationCenter.default.publisher(for: .AVAudioEngineConfigurationChange, object: engine)
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in self?.onConfigurationChange?() }
  }

  /// AVFoundation's callback type is non-Sendable. Defining its closure inside
  /// `configure()` would inherit MainActor and crash on the actual audio thread.
  /// Keep its creation outside actor isolation; only the render-owned state is captured.
  nonisolated static func makeSource(renderer: NativeAudioRenderer, format: AVAudioFormat) -> AVAudioSourceNode {
    AVAudioSourceNode(format: format) { silence, _, frames, buffers in
      renderer.render(frames, into: buffers, silence: silence)
    }
  }

  deinit { pauseTask?.cancel() }
}
