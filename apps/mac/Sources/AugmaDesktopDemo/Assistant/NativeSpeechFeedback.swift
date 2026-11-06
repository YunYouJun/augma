import AVFoundation

@MainActor
protocol NativeFeedbackSpeaking: AnyObject {
  func speak(_ message: String, locale: String)
  func stop()
}

/// Kept separate from recognition: opening or cancelling an assistant need not load the system's voice engine.
@MainActor
final class SystemNativeFeedbackSpeaker: NativeFeedbackSpeaking {
  private let synthesizer = AVSpeechSynthesizer()

  func speak(_ message: String, locale: String) {
    stop()
    let utterance = AVSpeechUtterance(string: String(message.prefix(NativeAssistantConversation.maxReplyLength)))
    utterance.voice = AVSpeechSynthesisVoice(language: locale)
    synthesizer.speak(utterance)
  }

  func stop() { synthesizer.stopSpeaking(at: .immediate) }
}
