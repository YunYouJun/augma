import AppKit
import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechCommandRecognizer {
  var onEvent: (String, String?) -> Void
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

  init(onEvent: @escaping (String, String?) -> Void) {
    self.onEvent = onEvent
  }

  func start() async {
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
      fail("请在系统设置中允许 Augma 使用语音识别。")
      return
    }

    let microphonePermission = await AVCaptureDevice.requestAccess(for: .audio)
    guard generation == session else { return }
    guard microphonePermission else {
      fail("请在系统设置中允许 Augma 使用麦克风。")
      return
    }
    guard NSApp.isActive else {
      fail("已离开 Augma，录音已取消。")
      return
    }

    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")), recognizer.isAvailable else {
      fail("当前设备的中文语音识别不可用，请稍后重试。")
      return
    }

    let engine = AVAudioEngine()
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0 else {
      fail("没有可用的麦克风输入。")
      return
    }

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    request.contextualStrings = ["打开地图", "扫描空间", "播放声音", "隐藏 HUD"]
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
      fail("无法启动麦克风：\(error.localizedDescription)")
      return
    }

    starting = false
    onEvent("listening", nil)
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
    onEvent("processing", nil)
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
        onEvent("final", text)
        return
      }
      onEvent("partial", lastText)
    }
    if let error {
      if processing, !lastText.isEmpty {
        let text = lastText
        cancel()
        onEvent("final", text)
      } else {
        fail("语音识别失败：\(error.localizedDescription)")
      }
    }
  }

  private func finishFromTimeout(session: Int) {
    guard generation == session, processing else { return }
    if lastText.isEmpty {
      fail("没有识别到语音，请重试。")
    } else {
      let text = lastText
      cancel()
      onEvent("final", text)
    }
  }

  private func fail(_ message: String) {
    cancel()
    onEvent("error", message)
  }
}
