import AVFoundation
import Darwin
import XCTest
@testable import AugmaDesktopDemo

@MainActor
final class NativeAudioTests: XCTestCase {
  func testAudioRemainsIdleUntilExplicitPlaybackAndVolumeIsPersistent() {
    withStore { store, engine, defaults, _ in
      XCTAssertFalse(store.playing)
      XCTAssertFalse(store.busy)
      XCTAssertEqual(engine.plays.count, 0)
      XCTAssertEqual(store.volume, 35)
      store.volume = 78
      XCTAssertEqual(engine.volume, 0.78)
      let restored = NativeAudioStore(defaults: defaults, engine: RecordingAudioEngine(), observeLifecycle: false, automaticallyTick: false)
      XCTAssertEqual(restored.volume, 78)
      store.volume = .infinity
      XCTAssertEqual(store.volume, 35)
      XCTAssertEqual(engine.volume, 0.35)
      store.volume = -40
      XCTAssertEqual(store.volume, 0)
      XCTAssertEqual(engine.volume, 0)
      store.volume = 130
      XCTAssertEqual(store.volume, 100)
      XCTAssertEqual(defaults.double(forKey: NativeAudioStore.volumeKey), 100)
    }
  }

  func testPauseResumeUsesMonotonicElapsedTimeAndDoesNotDuplicatePlayRequests() {
    withStore { store, engine, _, clock in
      store.play()
      store.play()
      XCTAssertEqual(engine.plays.count, 1)
      clock.value += 11.25
      store.tick()
      XCTAssertEqual(store.elapsed, 11.25)
      store.pause()
      clock.value += 30
      store.tick()
      XCTAssertEqual(store.elapsed, 11.25)
      store.play()
      XCTAssertEqual(engine.plays.last?.elapsed, 11.25)
      clock.value += 3.5
      store.tick()
      XCTAssertEqual(store.elapsed, 14.75)
      XCTAssertTrue(store.playing)
    }
  }

  func testLegacyVolumeImportsOnlyBeforeNativePreferenceExists() {
    withStore { store, engine, _, _ in
      store.importLegacyVolume(true)
      XCTAssertEqual(store.volume, 35)
      store.importLegacyVolume(NSNumber(value: 64))
      XCTAssertEqual(store.volume, 64)
      XCTAssertEqual(engine.volume, 0.64)
      store.importLegacyVolume(NSNumber(value: 80))
      XCTAssertEqual(store.volume, 64)
    }
    withStore { store, _, _, _ in
      store.volume = 40
      store.importLegacyVolume(NSNumber(value: 80))
      XCTAssertEqual(store.volume, 40)
    }
  }

  func testSeekWhilePlayingRestartsAtTargetAndPausedSeekDoesNotStartAudio() {
    withStore { store, engine, _, clock in
      store.seek(20)
      XCTAssertFalse(store.playing)
      XCTAssertEqual(engine.plays.count, 0)
      store.play()
      XCTAssertEqual(engine.plays.last?.elapsed, 20)
      clock.value += 5
      store.seek(60)
      XCTAssertEqual(engine.plays.last?.elapsed, 60)
      clock.value += 2
      store.tick()
      XCTAssertEqual(store.elapsed, 62)
      store.seek(.nan)
      XCTAssertEqual(store.elapsed, 62)
      store.seek(-1)
      XCTAssertEqual(store.elapsed, 0)
      store.seek(200)
      XCTAssertEqual(store.elapsed, store.duration)
      XCTAssertFalse(store.playing)
    }
  }

  func testTrackChangesKeepPlayingIntentAndWrapAtLibraryBoundaries() {
    withStore { store, engine, _, clock in
      store.play()
      clock.value += 20
      store.next()
      XCTAssertEqual(store.trackIndex, 1)
      XCTAssertEqual(store.elapsed, 0)
      XCTAssertTrue(store.playing)
      XCTAssertEqual(engine.plays.last?.trackIndex, 1)
      store.selectTrack(99)
      XCTAssertEqual(store.trackIndex, 1)
      store.selectTrack(0)
      store.previous()
      XCTAssertEqual(store.trackIndex, 2)
      store.next()
      XCTAssertEqual(store.trackIndex, 0)
      store.pause()
      let playCount = engine.plays.count
      store.next()
      XCTAssertEqual(engine.plays.count, playCount)
      XCTAssertFalse(store.playing)
    }
  }

  func testNaturalEndStopsAndPlayingAgainStartsAtBeginning() {
    withStore { store, engine, _, clock in
      store.play()
      clock.value += 121
      store.tick()
      XCTAssertEqual(store.elapsed, 120)
      XCTAssertFalse(store.playing)
      XCTAssertGreaterThan(engine.pauseCount, 0)
      clock.value += 80
      store.tick()
      XCTAssertEqual(store.elapsed, 120)
      store.play()
      XCTAssertTrue(store.playing)
      XCTAssertEqual(engine.plays.last?.elapsed, 0)
    }
  }

  func testAudioFailureCanBeRetriedWithoutAdvancingOrLeavingBusyState() {
    withStore { store, engine, _, clock in
      engine.shouldFail = true
      store.seek(25)
      store.play()
      XCTAssertFalse(store.playing)
      XCTAssertFalse(store.busy)
      XCTAssertNotNil(store.error)
      XCTAssertEqual(store.elapsed, 25)
      clock.value += 100
      store.tick()
      XCTAssertEqual(store.elapsed, 25)
      engine.shouldFail = false
      store.play()
      XCTAssertTrue(store.playing)
      XCTAssertNil(store.error)
      XCTAssertEqual(engine.plays.last?.elapsed, 25)
    }
  }

  func testSleepAndAudioReconfigurationResumeOnlyPreviousPlaybackIntent() {
    withStore { store, engine, _, clock in
      store.play()
      clock.value += 8
      store.setSleeping(true)
      XCTAssertFalse(store.playing)
      XCTAssertEqual(store.elapsed, 8)
      clock.value += 300
      store.setSleeping(false)
      XCTAssertTrue(store.playing)
      XCTAssertEqual(engine.plays.last?.elapsed, 8)
      clock.value += 4
      engine.onConfigurationChange?()
      XCTAssertEqual(store.elapsed, 12)
      XCTAssertEqual(engine.plays.last?.elapsed, 12)
      XCTAssertTrue(store.playing)
      store.setSleeping(true)
      store.pause()
      store.setSleeping(false)
      XCTAssertFalse(store.playing)
      let playCount = engine.plays.count
      engine.onConfigurationChange?()
      XCTAssertEqual(engine.plays.count, playCount)
    }
  }

  func testShutdownStopsOutputAndPreventsFurtherPlayback() {
    withStore { store, engine, _, clock in
      store.play()
      clock.value += 3
      store.shutdown()
      XCTAssertFalse(store.playing)
      XCTAssertEqual(store.elapsed, 3)
      let playCount = engine.plays.count
      store.play()
      store.setSleeping(false)
      XCTAssertEqual(engine.plays.count, playCount)
      XCTAssertGreaterThan(engine.stopCount, 0)
    }
  }

  func testRendererProducesBoundedStereoSignalAndFadesToSilenceOnPause() throws {
    let renderer = NativeAudioRenderer()
    renderer.setVolume(1)
    renderer.request(trackIndex: 0, elapsed: 0, playing: true)
    let playing = try render(renderer, frames: 4_800)
    XCTAssertEqual(playing.first, 0)
    XCTAssertTrue(playing.contains { abs($0) > 0.01 })
    XCTAssertTrue(playing.allSatisfy { $0.isFinite && abs($0) <= 0.1951 })
    renderer.request(trackIndex: 0, elapsed: 0.1, playing: false)
    let paused = try render(renderer, frames: 4_800)
    XCTAssertTrue(paused.suffix(2_400).allSatisfy { $0 == 0 })
  }

  func testRealSourceCallbackRendersOffMainActorWithoutOpeningAnAudioDevice() async throws {
    let output = try await Task.detached {
      let engine = AVAudioEngine()
      defer { engine.stop() }
      let renderer = NativeAudioRenderer()
      renderer.request(trackIndex: 0, elapsed: 0, playing: true)
      let format = AVAudioFormat(standardFormatWithSampleRate: NativeAudioRenderer.sampleRate, channels: 2)!
      // Exercise the exact source factory used by the production engine. Calling
      // only renderer.render() would miss an actor-isolated AVFoundation closure.
      let source = NativeSynthAudioEngine.makeSource(renderer: renderer, format: format)
      engine.attach(source)
      engine.connect(source, to: engine.mainMixerNode, format: format)
      try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4_800)
      try engine.start()
      let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_800)!
      let status = try engine.renderOffline(4_800, to: buffer)
      let samples = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
      return (onMainThread: pthread_main_np() != 0, status: status.rawValue, samples: samples)
    }.value
    XCTAssertFalse(output.onMainThread)
    XCTAssertEqual(output.status, AVAudioEngineManualRenderingStatus.success.rawValue)
    XCTAssertTrue(output.samples.contains { abs($0) > 0.001 })
  }

  func testRendererEndsAtDurationAndAllThreeChordsAreDistinct() throws {
    var signals: [[Float]] = []
    for track in 0..<3 {
      let renderer = NativeAudioRenderer()
      renderer.setVolume(1)
      renderer.request(trackIndex: track, elapsed: 119.9, playing: true)
      let signal = try render(renderer, frames: 9_600)
      XCTAssertTrue(signal.prefix(4_000).contains { abs($0) > 0.01 })
      XCTAssertTrue(signal.suffix(4_800).allSatisfy { $0 == 0 })
      signals.append(signal)
    }
    XCTAssertNotEqual(signals[0], signals[1])
    XCTAssertNotEqual(signals[1], signals[2])
  }

  private func withStore(_ check: (NativeAudioStore, RecordingAudioEngine, UserDefaults, AudioTestClock) -> Void) {
    let suite = "augma-audio-tests-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let engine = RecordingAudioEngine()
    let clock = AudioTestClock()
    let store = NativeAudioStore(defaults: defaults, engine: engine, uptime: { clock.value }, observeLifecycle: false, automaticallyTick: false)
    defer { store.shutdown() }
    check(store, engine, defaults, clock)
  }

  private func render(_ renderer: NativeAudioRenderer, frames: AVAudioFrameCount) throws -> [Float] {
    let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: NativeAudioRenderer.sampleRate, channels: 2))
    let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
    buffer.frameLength = frames
    var silent = ObjCBool(true)
    XCTAssertEqual(renderer.render(frames, into: buffer.mutableAudioBufferList, silence: &silent), noErr)
    let channels = try XCTUnwrap(buffer.floatChannelData)
    let left = Array(UnsafeBufferPointer(start: channels[0], count: Int(frames)))
    let right = Array(UnsafeBufferPointer(start: channels[1], count: Int(frames)))
    XCTAssertEqual(left, right)
    return left
  }
}

@MainActor
private final class AudioTestClock { var value: TimeInterval = 1_000 }

@MainActor
private final class RecordingAudioEngine: NativeAudioEngineBackend {
  var onConfigurationChange: (() -> Void)?
  var plays: [(trackIndex: Int, elapsed: TimeInterval)] = []
  var shouldFail = false
  var pauseCount = 0
  var stopCount = 0
  var volume = 0.0

  func play(trackIndex: Int, from elapsed: TimeInterval) throws {
    if shouldFail { throw NSError(domain: "AugmaAudioTests", code: 1) }
    plays.append((trackIndex, elapsed))
  }
  func pause() { pauseCount += 1 }
  func setVolume(_ fraction: Double) { volume = fraction }
  func reset() { stopCount += 1 }
  func stop() { stopCount += 1 }
}
