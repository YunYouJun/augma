import { onMounted, onUnmounted, shallowRef } from 'vue'
import { locale } from '../../i18n/locale'

/**
 * Read short status text aloud with the Web Speech API in the active locale.
 *
 * Works in browsers and in the macOS app's WKWebView; does nothing where `speechSynthesis` is missing.
 *
 * @param enabled - Whether spoken feedback is currently switched on
 * @returns `supported` for the settings UI, plus `speak` and `cancel`
 */
export function useSpeechFeedback(enabled: () => boolean) {
  const synth = typeof window !== 'undefined' && 'speechSynthesis' in window && typeof SpeechSynthesisUtterance !== 'undefined'
    ? window.speechSynthesis
    : undefined
  const supported = !!synth
  const voices = shallowRef<SpeechSynthesisVoice[]>([])

  function loadVoices() {
    voices.value = synth?.getVoices() ?? []
  }

  function pickVoice(lang: string): SpeechSynthesisVoice | undefined {
    const normalized = (voice: SpeechSynthesisVoice) => voice.lang.replace('_', '-').toLowerCase()
    const target = lang.toLowerCase()
    const language = target.split('-')[0]
    const candidates = voices.value.filter(voice => normalized(voice) === target)
    const fallback = candidates.length ? candidates : voices.value.filter(voice => normalized(voice).split('-')[0] === language)
    return fallback.find(voice => voice.localService) ?? fallback[0]
  }

  function speak(text: string) {
    if (!synth || !enabled() || !text)
      return
    // Drop any unfinished sentence so rapid commands do not queue up behind each other.
    synth.cancel()
    const utterance = new SpeechSynthesisUtterance(text)
    utterance.lang = locale.value
    const voice = pickVoice(locale.value)
    if (voice)
      utterance.voice = voice
    synth.speak(utterance)
  }

  function cancel() {
    synth?.cancel()
  }

  onMounted(() => {
    loadVoices()
    synth?.addEventListener?.('voiceschanged', loadVoices)
  })
  onUnmounted(() => {
    synth?.removeEventListener?.('voiceschanged', loadVoices)
    cancel()
  })

  return { supported, speak, cancel }
}
