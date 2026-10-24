import AppKit
import AVFoundation
import Combine
import XCTest
@testable import AugmaDesktopDemo

final class NativeInteractionTests: XCTestCase {
  func testAudioMeterBoundsAndSilence() {
    XCTAssertEqual(AudioLevelMeter.normalizedLevel(rms: 0), 0)
    XCTAssertEqual(AudioLevelMeter.normalizedLevel(rms: .nan), 0)
    XCTAssertEqual(AudioLevelMeter.normalizedLevel(rms: .infinity), 0)
    XCTAssertEqual(AudioLevelMeter.normalizedLevel(rms: 0.001), 0)
    XCTAssertEqual(AudioLevelMeter.normalizedLevel(rms: 1), 1)
    XCTAssertEqual(AudioLevelMeter.normalizedLevel(rms: 2), 1)
    XCTAssertGreaterThan(AudioLevelMeter.normalizedLevel(rms: 0.1), AudioLevelMeter.normalizedLevel(rms: 0.01))
  }

  func testAudioMeterLimitsDeliveryAndIncludesBothChannels() throws {
    let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
    let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1000))
    buffer.frameLength = 1000
    let channels = try XCTUnwrap(buffer.floatChannelData)
    for index in 0..<1000 {
      channels[0][index] = 0
      channels[1][index] = 0.1
    }
    let meter = AudioLevelMeter()
    let readings = (0..<48).compactMap { _ in meter.consume(buffer) }
    XCTAssertEqual(readings.count, 20, "One second of audio delivers 20 readings, regardless of tap buffer size")
    XCTAssertEqual(try XCTUnwrap(readings.last), AudioLevelMeter.normalizedLevel(rms: 0.1), accuracy: 0.001)
  }

  @MainActor
  func testVoiceMeterSmoothsAndStopsOutsideListening() async {
    let voice = VoiceActivityModel()
    voice.receive(level: 1)
    XCTAssertEqual(voice.level, 0)
    voice.setPhase("listening")
    voice.receive(level: 1)
    XCTAssertEqual(voice.level, 0.65, accuracy: 0.001)
    voice.receive(level: .nan)
    XCTAssertEqual(voice.level, 0.65, accuracy: 0.001)
    voice.receive(level: 0)
    XCTAssertEqual(voice.level, 0.455, accuracy: 0.001)
    voice.setPhase("processing")
    voice.receive(level: 1)
    XCTAssertEqual(voice.level, 0)
    voice.setPhase("idle")
    XCTAssertEqual(voice.phase, "idle")
  }

  @MainActor
  func testMenuRoutingReopensAClosedSessionAndTracksMostRecentWindow() async {
    _ = NSApplication.shared
    let registry = DemoSessionRegistry()
    var opened = 0
    registry.perform(.open(.commands)) { opened += 1 }
    XCTAssertEqual(opened, 1)
    let first = NativeDemoModel()
    registry.register(first)
    XCTAssertEqual(first.selection, .commands)
    let second = NativeDemoModel()
    let third = NativeDemoModel()
    registry.register(second)
    registry.register(third)
    registry.activate(first)
    registry.activate(second)
    registry.unregister(second)
    XCTAssertTrue(registry.current === first)
    registry.unregister(first)
    registry.unregister(third)
    XCTAssertNil(registry.current)
  }

}
