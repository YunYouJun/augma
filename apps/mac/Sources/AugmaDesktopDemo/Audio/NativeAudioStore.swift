import AppKit
import Combine
import CoreFoundation
import Foundation

/// App-owned audio transport. Every window uses this instance, so changing the
/// visible scene cannot start a second sound engine or interrupt playback.
@MainActor
final class NativeAudioStore: ObservableObject {
  static let tracks = NativeAudioTrack.library
  static let volumeKey = "augma.nativeAudio.volume.v1"
  let duration: TimeInterval = 120

  @Published private(set) var trackIndex = 0
  @Published private(set) var playing = false
  @Published private(set) var busy = false
  @Published private(set) var error: String?
  @Published private(set) var elapsed: TimeInterval = 0
  @Published var volume: Double {
    didSet {
      let clamped = volume.isFinite ? min(100, max(0, volume)) : 35
      if volume != clamped { volume = clamped }
      defaults.set(clamped, forKey: Self.volumeKey)
      engine.setVolume(clamped / 100)
    }
  }

  private let defaults: UserDefaults
  private let engine: any NativeAudioEngineBackend
  private let uptime: () -> TimeInterval
  private let automaticallyTick: Bool
  private var baseElapsed: TimeInterval = 0
  private var startedAt: TimeInterval?
  private var timer: Task<Void, Never>?
  private var lifecycle: [AnyCancellable] = []
  private var sleeping = false
  private var resumeAfterSleep = false
  private var terminated = false

  init(defaults: UserDefaults = .standard, engine: (any NativeAudioEngineBackend)? = nil,
       uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
       observeLifecycle: Bool = true, automaticallyTick: Bool = true) {
    self.defaults = defaults
    self.engine = engine ?? NativeSynthAudioEngine()
    self.uptime = uptime
    self.automaticallyTick = automaticallyTick
    let saved = defaults.object(forKey: Self.volumeKey) as? Double ?? 35
    volume = saved.isFinite ? min(100, max(0, saved)) : 35
    self.engine.setVolume(volume / 100)
    self.engine.onConfigurationChange = { [weak self] in self?.handleAudioConfigurationChange() }
    if observeLifecycle {
      NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in self?.setSleeping(true) }.store(in: &lifecycle)
      NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in self?.setSleeping(false) }.store(in: &lifecycle)
      NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in self?.shutdown() }.store(in: &lifecycle)
    }
  }

  func play() {
    guard !terminated, !playing, !busy else { return }
    if sleeping { resumeAfterSleep = true; return }
    if elapsed >= duration { elapsed = 0 }
    startPlayback()
  }

  func pause() {
    resumeAfterSleep = false
    pausePlayback()
  }

  func selectTrack(_ index: Int) {
    guard Self.tracks.indices.contains(index) else { return }
    let resume = playing
    pausePlayback()
    trackIndex = index
    elapsed = 0
    baseElapsed = 0
    error = nil
    if resume { play() }
  }

  func next() { selectTrack((trackIndex + 1) % Self.tracks.count) }
  func previous() { selectTrack((trackIndex + Self.tracks.count - 1) % Self.tracks.count) }

  /// The web simulator may offer its old setting once. Native edits and an
  /// already persisted native preference always take precedence.
  func importLegacyVolume(_ value: Any) {
    guard defaults.object(forKey: Self.volumeKey) == nil,
          let number = value as? NSNumber,
          CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite else { return }
    volume = min(100, max(0, number.doubleValue))
  }

  func seek(_ seconds: Double) {
    guard seconds.isFinite else { return }
    let target = min(duration, max(0, seconds))
    guard target != elapsed else { return }
    elapsed = target
    baseElapsed = elapsed
    if playing {
      if elapsed >= duration { finishPlayback() }
      else { startPlayback() }
    }
  }

  /// Monotonic time drives UI progress; wall-clock adjustments do not change it.
  func tick() {
    guard playing, let startedAt else { return }
    elapsed = min(duration, max(elapsed, baseElapsed + max(0, uptime() - startedAt)))
    if elapsed >= duration { finishPlayback() }
  }

  func setSleeping(_ value: Bool) {
    guard sleeping != value, !terminated else { return }
    sleeping = value
    if value {
      resumeAfterSleep = playing
      pausePlayback()
      engine.stop()
    } else {
      engine.reset()
      let resume = resumeAfterSleep
      resumeAfterSleep = false
      if resume { play() }
    }
  }

  func handleAudioConfigurationChange() {
    guard !terminated else { return }
    let resume = playing
    pausePlayback()
    engine.reset()
    if resume, !sleeping { play() }
  }

  func shutdown() {
    terminated = true
    resumeAfterSleep = false
    pausePlayback()
    engine.stop()
  }

  private func startPlayback() {
    busy = true
    error = nil
    defer { busy = false }
    do {
      try engine.play(trackIndex: trackIndex, from: elapsed)
      baseElapsed = elapsed
      startedAt = uptime()
      playing = true
      startTimerIfNeeded()
    } catch {
      playing = false
      startedAt = nil
      stopTimer()
      engine.stop()
      self.error = String(localized: "无法播放声音，请检查音频输出设备后重试。")
    }
  }

  private func pausePlayback() {
    if playing { tick() }
    playing = false
    busy = false
    startedAt = nil
    baseElapsed = elapsed
    stopTimer()
    engine.pause()
  }

  private func finishPlayback() {
    elapsed = duration
    baseElapsed = duration
    startedAt = nil
    playing = false
    stopTimer()
    engine.pause()
  }

  private func startTimerIfNeeded() {
    guard automaticallyTick, timer == nil else { return }
    timer = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .milliseconds(250)) }
        catch { return }
        self?.tick()
        if self?.playing != true { return }
      }
    }
  }

  private func stopTimer() { timer?.cancel(); timer = nil }
  deinit { timer?.cancel() }
}
