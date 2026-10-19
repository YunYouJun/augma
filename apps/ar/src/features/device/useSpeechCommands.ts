import type { Locale, Message, MessageKey } from '../../i18n/locale'
import type { VoiceCommand } from './voiceCommands'
import { onMounted, onUnmounted, shallowRef } from 'vue'
import { locale } from '../../i18n/locale'
import { isVoiceCommand, matchVoiceCommand } from './voiceCommands'

type SpeechStatus = 'idle' | 'requesting' | 'listening' | 'processing' | 'interpreting'
type SpeechAction = 'start' | 'stop' | 'cancel' | 'config'

type SpeechMessage = SpeechAction | { action: 'start', locale: Locale } | { action: 'interpret', text: string }

interface SpeechEventDetail {
  type: 'listening' | 'processing' | 'partial' | 'final' | 'error' | 'cancelled' | 'config' | 'interpreted'
  text?: string
  /** Error code from the native bridge, translated on this side. */
  code?: string
  enabled?: boolean
}

interface SpeechBridgeWindow extends Window {
  webkit?: { messageHandlers?: { speechCommand?: { postMessage: (message: SpeechMessage) => void } } }
}

const nativeErrors = new Set([
  'speechPermission',
  'microphonePermission',
  'appInactive',
  'recognizerUnavailable',
  'noMicrophone',
  'microphoneStart',
  'recognitionFailed',
  'noSpeech',
  'deepseekNotConfigured',
  'deepseekInvalidInput',
  'deepseekInvalidKey',
  'deepseekInsufficientBalance',
  'deepseekRateLimited',
  'deepseekInvalidResponse',
  'deepseekHttp',
  'deepseekRequest',
])

function nativeError(detail: SpeechEventDetail): Message | null {
  if (detail.code && nativeErrors.has(detail.code))
    return { key: `speech.error.${detail.code}` as MessageKey, params: { detail: detail.text || '' } }
  return null
}

interface UseSpeechCommandsOptions {
  isPanelVisible: () => boolean
  onCommand: (command: VoiceCommand) => void
}

export function useSpeechCommands(options: UseSpeechCommandsOptions) {
  const bridge = (window as SpeechBridgeWindow).webkit?.messageHandlers?.speechCommand
  const available = !!bridge
  const status = shallowRef<SpeechStatus>('idle')
  const transcript = shallowRef('')
  const error = shallowRef<Message | null>(null)
  const cloudEnabled = shallowRef(false)

  function interpret(text: string) {
    if (!text) {
      error.value = { key: 'speech.noSpeech' }
      return
    }
    const command = matchVoiceCommand(text, locale.value)
    if (command) {
      options.onCommand(command)
    }
    else if (cloudEnabled.value && bridge) {
      status.value = 'interpreting'
      bridge.postMessage({ action: 'interpret', text })
    }
    else {
      error.value = { key: 'speech.unmatched', params: { text } }
    }
  }

  function submitText(value: string) {
    if (status.value !== 'idle')
      cancel()
    transcript.value = value.trim().slice(0, 500)
    error.value = null
    interpret(transcript.value)
  }

  function start() {
    if (!bridge || status.value !== 'idle')
      return
    transcript.value = ''
    error.value = null
    status.value = 'requesting'
    bridge.postMessage({ action: 'start', locale: locale.value })
  }

  function stop() {
    if (status.value !== 'listening')
      return
    status.value = 'processing'
    bridge?.postMessage('stop')
  }

  function cancel() {
    if (status.value === 'idle')
      return
    const wasInterpreting = status.value === 'interpreting'
    bridge?.postMessage('cancel')
    status.value = 'idle'
    transcript.value = ''
    error.value = { key: wasInterpreting ? 'speech.interpretCancelled' : 'speech.recordingCancelled' }
  }

  function receive(event: Event) {
    const detail = (event as CustomEvent<SpeechEventDetail>).detail
    if (!detail || !['listening', 'processing', 'partial', 'final', 'error', 'cancelled', 'config', 'interpreted'].includes(detail.type))
      return
    if (detail.type === 'config') {
      cloudEnabled.value = detail.enabled === true
      return
    }
    if (!options.isPanelVisible() || status.value === 'idle')
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
      error.value = nativeError(detail) ?? (detail.text ? { key: 'speech.error.recognitionFailed', params: { detail: detail.text } } : { key: 'speech.failed' })
      return
    }
    if (detail.type === 'interpreted') {
      if (isVoiceCommand(detail.text))
        options.onCommand(detail.text)
      else
        error.value = { key: 'speech.unmatched', params: { text: transcript.value } }
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

  return { available, cloudEnabled, status, transcript, error, start, stop, cancel, submitText }
}
