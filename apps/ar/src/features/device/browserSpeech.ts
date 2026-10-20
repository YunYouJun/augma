import type { Locale } from '../../i18n/locale'

/** A recording or assistant event. The macOS app dispatches these as `augma:speech`; the browser recorder emits the same shape. */
export interface SpeechEventDetail {
  type: 'listening' | 'processing' | 'partial' | 'final' | 'error' | 'cancelled' | 'config' | 'interpreted'
  text?: string
  /** Error code, translated by the page. */
  code?: string
  enabled?: boolean
}

/** Starts, finishes and cancels one recording; progress arrives as {@link SpeechEventDetail} events. */
export interface SpeechRecorder {
  start: (locale: Locale) => void
  stop: () => void
  cancel: () => void
}

// The parts of the Web Speech recognition API used here; TypeScript's DOM library does not declare it.
interface Recognition {
  lang: string
  continuous: boolean
  interimResults: boolean
  onstart: (() => void) | null
  onresult: ((event: { results: ArrayLike<ArrayLike<{ transcript: string }>> }) => void) | null
  onerror: ((event: { error: string }) => void) | null
  onend: (() => void) | null
  start: () => void
  stop: () => void
  abort: () => void
}

interface RecognitionWindow extends Window {
  SpeechRecognition?: new () => Recognition
  webkitSpeechRecognition?: new () => Recognition
}

/** Matches the macOS app: one recording lasts at most about 12 seconds. */
const maxRecording = 12_000

const errorCodes: Record<string, string> = {
  'not-allowed': 'browserMicrophone',
  'service-not-allowed': 'browserMicrophone',
  'audio-capture': 'noMicrophone',
  'no-speech': 'noSpeech',
  'language-not-supported': 'recognizerUnavailable',
}

/**
 * Record with the browser's Web Speech recognition (Chrome, Edge and Safari; not Firefox).
 *
 * The browser asks for the microphone on the first recording, and its vendor may recognize the audio online.
 *
 * @param emit - Receives progress, the final transcript and errors
 * @returns A recorder, or `null` when this browser cannot recognize speech
 */
export function createBrowserRecorder(emit: (detail: SpeechEventDetail) => void): SpeechRecorder | null {
  const scope = typeof window === 'undefined' ? undefined : window as RecognitionWindow
  const Available = scope?.SpeechRecognition ?? scope?.webkitSpeechRecognition
  if (!Available)
    return null
  // Hoisted functions below do not see the narrowing above.
  const Recognizer: new () => Recognition = Available
  let session: { recognition: Recognition, cancelled: boolean } | null = null
  let timer: ReturnType<typeof setTimeout> | undefined

  function start(locale: Locale) {
    cancel()
    const recognition = new Recognizer()
    const current = { recognition, cancelled: false }
    session = current
    let text = ''
    let failed = false
    recognition.lang = locale
    recognition.continuous = true
    recognition.interimResults = true
    recognition.onstart = () => {
      if (session !== current)
        return
      emit({ type: 'listening' })
      timer = setTimeout(stop, maxRecording)
    }
    recognition.onresult = (event) => {
      text = Array.from(event.results, result => result[0]?.transcript ?? '').join('').trim()
      if (session === current)
        emit({ type: 'partial', text })
    }
    recognition.onerror = (event) => {
      if (current.cancelled || event.error === 'aborted')
        return
      failed = true
      const code = errorCodes[event.error]
      emit(code ? { type: 'error', code } : { type: 'error', code: 'recognitionFailed', text: event.error })
    }
    recognition.onend = () => {
      if (session === current) {
        session = null
        clearTimeout(timer)
      }
      if (!current.cancelled && !failed)
        emit({ type: 'final', text })
    }
    try {
      recognition.start()
    }
    catch (error) {
      session = null
      emit({ type: 'error', code: 'microphoneStart', text: error instanceof Error ? error.message : String(error) })
    }
  }

  function stop() {
    if (!session)
      return
    clearTimeout(timer)
    emit({ type: 'processing' })
    session.recognition.stop()
  }

  function cancel() {
    if (!session)
      return
    clearTimeout(timer)
    session.cancelled = true
    session.recognition.abort()
    session = null
  }

  return { start, stop, cancel }
}
