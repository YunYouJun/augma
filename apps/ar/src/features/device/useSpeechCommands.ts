import type { Locale, Message, MessageKey } from '../../i18n/locale'
import type { AssistantMessage, AssistantTurn } from './assistant'
import type { SpeechEventDetail, SpeechRecorder } from './browserSpeech'
import type { VoiceCommand } from './voiceCommands'
import { computed, onMounted, onUnmounted, shallowRef } from 'vue'
import { locale } from '../../i18n/locale'
import { AssistantError, assistantMessages, historyLimit, isAssistantErrorCode, parseAssistantAnswer, requestDeepSeek } from './assistant'
import { createBrowserRecorder } from './browserSpeech'
import { matchVoiceCommand } from './voiceCommands'

type SpeechStatus = 'idle' | 'requesting' | 'listening' | 'processing' | 'interpreting'
type SpeechAction = 'start' | 'stop' | 'cancel' | 'config'

type SpeechMessage = SpeechAction | { action: 'start', locale: Locale } | { action: 'interpret', messages: AssistantMessage[] }

interface SpeechBridgeWindow extends Window {
  webkit?: { messageHandlers?: { speechCommand?: { postMessage: (message: SpeechMessage) => void } } }
}

const recorderErrors = new Set([
  'speechPermission',
  'microphonePermission',
  'browserMicrophone',
  'appInactive',
  'recognizerUnavailable',
  'noMicrophone',
  'microphoneStart',
  'recognitionFailed',
  'noSpeech',
])

function recorderError(detail: SpeechEventDetail): Message | null {
  if (detail.code && recorderErrors.has(detail.code))
    return { key: `speech.error.${detail.code}` as MessageKey, params: { detail: detail.text || '' } }
  return null
}

interface UseSpeechCommandsOptions {
  isPanelVisible: () => boolean
  onCommand: (command: VoiceCommand) => void
  /** Receives the assistant's spoken reply when it answers instead of running a command. */
  onReply: (reply: string) => void
  /** The user's DeepSeek key in the browser. The macOS app keeps its key natively and reports readiness instead. */
  apiKey: () => string | null
}

/**
 * Voice and typed commands for the demo, with an optional DeepSeek assistant for phrases the local rules miss.
 *
 * Recording uses the macOS app's native bridge when present, otherwise the browser's speech recognition.
 * The assistant request goes through the native bridge (key in the Keychain) or straight from the browser (key in this browser).
 */
export function useSpeechCommands(options: UseSpeechCommandsOptions) {
  const bridge = (window as SpeechBridgeWindow).webkit?.messageHandlers?.speechCommand
  const recorder: SpeechRecorder | null = bridge
    ? {
        start: locale => bridge.postMessage({ action: 'start', locale }),
        stop: () => bridge.postMessage('stop'),
        // Also cancels a pending native assistant request.
        cancel: () => bridge.postMessage('cancel'),
      }
    : createBrowserRecorder(receive)
  const available = !!recorder
  const native = !!bridge
  const status = shallowRef<SpeechStatus>('idle')
  const transcript = shallowRef('')
  const reply = shallowRef('')
  const error = shallowRef<Message | null>(null)
  const nativeAssistant = shallowRef(false)
  const assistantReady = computed(() => native ? nativeAssistant.value : !!options.apiKey())
  let history: AssistantTurn[] = []
  // Bumped on every question and cancel, so a late answer to an abandoned question is dropped.
  let asking = 0
  let request: AbortController | null = null
  let pending: { resolve: (content: string) => void, reject: (error: AssistantError) => void } | null = null

  function complete(messages: AssistantMessage[]): Promise<string> {
    if (bridge) {
      return new Promise((resolve, reject) => {
        pending = { resolve, reject }
        bridge.postMessage({ action: 'interpret', messages })
      })
    }
    const key = options.apiKey()
    if (!key)
      return Promise.reject(new AssistantError('deepseekNotConfigured'))
    request = new AbortController()
    return requestDeepSeek(messages, key, request.signal)
  }

  async function ask(question: string) {
    const generation = ++asking
    status.value = 'interpreting'
    try {
      const content = await complete(assistantMessages(question, locale.value, history))
      if (generation !== asking)
        return
      const answer = parseAssistantAnswer(content)
      status.value = 'idle'
      history = [...history, { question, ...answer }].slice(-historyLimit)
      if (answer.command) {
        options.onCommand(answer.command)
      }
      else {
        reply.value = answer.reply
        options.onReply(answer.reply)
      }
    }
    catch (failure) {
      if (generation !== asking)
        return
      status.value = 'idle'
      error.value = failure instanceof AssistantError
        ? { key: `speech.error.${failure.code}`, params: { detail: failure.detail } }
        : { key: 'speech.error.deepseekRequest', params: { detail: failure instanceof Error ? failure.message : String(failure) } }
    }
    finally {
      if (generation === asking)
        request = null
    }
  }

  function interpret(text: string) {
    if (!text) {
      error.value = { key: 'speech.noSpeech' }
      return
    }
    const command = matchVoiceCommand(text, locale.value)
    if (command)
      options.onCommand(command)
    else if (assistantReady.value)
      void ask(text)
    else
      error.value = { key: 'speech.unmatched', params: { text } }
  }

  function submitText(value: string) {
    if (status.value !== 'idle')
      cancel()
    transcript.value = value.trim().slice(0, 500)
    reply.value = ''
    error.value = null
    interpret(transcript.value)
  }

  function start() {
    if (!recorder || status.value !== 'idle')
      return
    transcript.value = ''
    reply.value = ''
    error.value = null
    status.value = 'requesting'
    recorder.start(locale.value)
  }

  function stop() {
    if (status.value !== 'listening')
      return
    status.value = 'processing'
    recorder?.stop()
  }

  function cancel() {
    if (status.value === 'idle')
      return
    const wasInterpreting = status.value === 'interpreting'
    asking++
    pending = null
    request?.abort()
    request = null
    recorder?.cancel()
    status.value = 'idle'
    transcript.value = ''
    error.value = { key: wasInterpreting ? 'speech.interpretCancelled' : 'speech.recordingCancelled' }
  }

  function receive(input: Event | SpeechEventDetail) {
    const detail = input instanceof Event ? (input as CustomEvent<SpeechEventDetail>).detail : input
    if (!detail || !['listening', 'processing', 'partial', 'final', 'error', 'cancelled', 'config', 'interpreted'].includes(detail.type))
      return
    if (detail.type === 'config') {
      nativeAssistant.value = detail.enabled === true
      return
    }
    if (pending && (detail.type === 'interpreted' || detail.type === 'error')) {
      const { resolve, reject } = pending
      pending = null
      if (detail.type === 'interpreted')
        resolve(detail.text ?? '')
      else
        reject(new AssistantError(isAssistantErrorCode(detail.code) ? detail.code : 'deepseekRequest', detail.text ?? ''))
      return
    }
    if (detail.type === 'interpreted' || !options.isPanelVisible() || status.value === 'idle')
      return
    if (detail.type === 'cancelled') {
      status.value = 'idle'
      error.value = { key: 'speech.recordingCancelled' }
      return
    }
    if (detail.type === 'listening') {
      status.value = 'listening'
      return
    }
    if (detail.type === 'processing') {
      status.value = 'processing'
      return
    }
    if (detail.type === 'partial') {
      transcript.value = detail.text || ''
      return
    }
    status.value = 'idle'
    if (detail.type === 'error') {
      error.value = recorderError(detail) ?? (detail.text ? { key: 'speech.error.recognitionFailed', params: { detail: detail.text } } : { key: 'speech.failed' })
      return
    }
    transcript.value = detail.text || ''
    interpret(transcript.value)
  }

  onMounted(() => {
    window.addEventListener('augma:speech', receive)
    bridge?.postMessage('config')
  })
  onUnmounted(() => {
    window.removeEventListener('augma:speech', receive)
    cancel()
  })

  return { available, native, assistantReady, status, transcript, reply, error, start, stop, cancel, submitText }
}
