import AppKit
import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechCommandRecognizer {
  /// Event type, optional text (transcript or error detail) and, for errors, a code the page translates.
  var onEvent: (_ type: String, _ text: String?, _ code: String?) -> Void
  var isRecording: Bool { engine != nil && !processing }

  private var engine: AVAudioEngine?
  private var recognizer: SFSpeechRecognizer?
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?
  private var timeout: Task<Void, Never>?
  private var generation = 0
  private var starting = false
  private var processing = false
  private var tapInstalled = false
  private var lastText = ""

  init(onEvent: @escaping (_ type: String, _ text: String?, _ code: String?) -> Void) {
    self.onEvent = onEvent
  }

  /// Phrases that bias recognition toward the demo's commands in each supported language.
  private static let contextualStrings: [String: [String]] = [
    "zh": ["打开地图", "扫描空间", "播放声音", "隐藏 HUD"],
    "en": ["open the map", "scan the space", "play sound", "hide the HUD"],
    "ja": ["地図を開いて", "空間をスキャンして", "サウンドを再生して", "HUDを隠して"],
  ]

  /// Normalizes the page's locale to one this demo supports, falling back to Simplified Chinese.
  static func recognitionLocale(for identifier: String?) -> Locale {
    switch identifier?.lowercased().prefix(2) {
    case "en": Locale(identifier: "en-US")
    case "ja": Locale(identifier: "ja-JP")
    default: Locale(identifier: "zh-CN")
    }
  }

  func start(localeIdentifier: String? = nil) async {
    guard !starting, engine == nil, !processing else { return }
    generation += 1
    let session = generation
    starting = true
    lastText = ""

    let speechPermission = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
      SFSpeechRecognizer.requestAuthorization { status in
        continuation.resume(returning: status)
      }
    }
    guard generation == session else { return }
    guard speechPermission == .authorized else {
      fail("speechPermission")
      return
    }

    let microphonePermission = await AVCaptureDevice.requestAccess(for: .audio)
    guard generation == session else { return }
    guard microphonePermission else {
      fail("microphonePermission")
      return
    }
    guard NSApp.isActive else {
      fail("appInactive")
      return
    }

    let locale = Self.recognitionLocale(for: localeIdentifier)
    guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
      fail("recognizerUnavailable")
      return
    }

    let engine = AVAudioEngine()
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0 else {
      fail("noMicrophone")
      return
    }

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    request.contextualStrings = Self.contextualStrings[locale.language.languageCode?.identifier ?? "zh"] ?? []
    request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
    self.engine = engine
    self.recognizer = recognizer
    self.request = request
    task = recognizer.recognitionTask(with: request) { [weak self] result, error in
      Task { @MainActor [weak self] in
        self?.handle(result: result, error: error, session: session)
      }
    }
    input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
      request.append(buffer)
    }
    tapInstalled = true

    do {
      engine.prepare()
      try engine.start()
    } catch {
      fail("microphoneStart", detail: error.localizedDescription)
      return
    }

    starting = false
    onEvent("listening", nil, nil)
    timeout = Task { [weak self] in
      do { try await Task.sleep(for: .seconds(12)) } catch { return }
      guard self?.generation == session else { return }
      self?.stop()
    }
  }

  func stop() {
    guard engine != nil, !processing else { return }
    processing = true
    timeout?.cancel()
    timeout = nil
    engine?.stop()
    if tapInstalled {
      engine?.inputNode.removeTap(onBus: 0)
      tapInstalled = false
    }
    request?.endAudio()
    onEvent("processing", nil, nil)
    let session = generation
    timeout = Task { [weak self] in
      do { try await Task.sleep(for: .seconds(3)) } catch { return }
      self?.finishFromTimeout(session: session)
    }
  }

  func cancel() {
    generation += 1
    timeout?.cancel()
    timeout = nil
    if let engine {
      engine.stop()
      if tapInstalled {
        engine.inputNode.removeTap(onBus: 0)
        tapInstalled = false
      }
    }
    task?.cancel()
    task = nil
    request = nil
    self.engine = nil
    recognizer = nil
    starting = false
    processing = false
    lastText = ""
  }

  private func handle(result: SFSpeechRecognitionResult?, error: Error?, session: Int) {
    guard generation == session else { return }
    if let result {
      lastText = result.bestTranscription.formattedString
      if result.isFinal {
        let text = lastText
        cancel()
        onEvent("final", text, nil)
        return
      }
      onEvent("partial", lastText, nil)
    }
    if let error {
      if processing, !lastText.isEmpty {
        let text = lastText
        cancel()
        onEvent("final", text, nil)
      } else {
        fail("recognitionFailed", detail: error.localizedDescription)
      }
    }
  }

  private func finishFromTimeout(session: Int) {
    guard generation == session, processing else { return }
    if lastText.isEmpty {
      fail("noSpeech")
    } else {
      let text = lastText
      cancel()
      onEvent("final", text, nil)
    }
  }

  private func fail(_ code: String, detail: String? = nil) {
    cancel()
    onEvent("error", detail, code)
  }
}
