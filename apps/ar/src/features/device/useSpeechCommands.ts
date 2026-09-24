import type { VoiceCommand } from './voiceCommands'
import { onMounted, onUnmounted, shallowRef } from 'vue'
import { isVoiceCommand, matchVoiceCommand } from './voiceCommands'

type SpeechStatus = 'idle' | 'requesting' | 'listening' | 'processing' | 'interpreting'
type SpeechAction = 'start' | 'stop' | 'cancel' | 'config'

interface SpeechEventDetail {
  type: 'listening' | 'processing' | 'partial' | 'final' | 'error' | 'cancelled' | 'config' | 'interpreted'
  text?: string
  enabled?: boolean
}

interface SpeechBridgeWindow extends Window {
  webkit?: { messageHandlers?: { speechCommand?: { postMessage: (action: SpeechAction | { action: 'interpret', text: string }) => void } } }
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
  const error = shallowRef('')
  const cloudEnabled = shallowRef(false)

  function interpret(text: string) {
    if (!text) {
      error.value = '没有识别到语音，请重试。'
      return
    }
    const command = matchVoiceCommand(text)
    if (command) {
      options.onCommand(command)
    }
    else if (cloudEnabled.value && bridge) {
      status.value = 'interpreting'
      bridge.postMessage({ action: 'interpret', text })
    }
    else {
      error.value = `未匹配到指令：${text}`
    }
  }

  function submitText(value: string) {
    if (status.value !== 'idle')
      cancel()
    transcript.value = value.trim().slice(0, 500)
    error.value = ''
    interpret(transcript.value)
  }

  function start() {
    if (!bridge || status.value !== 'idle')
      return
    transcript.value = ''
    error.value = ''
    status.value = 'requesting'
    bridge.postMessage('start')
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
    error.value = wasInterpreting ? '已取消理解。' : '录音已取消。'
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
      error.value = '录音已取消。'
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
      error.value = detail.text || '语音识别失败，请重试。'
      return
    }
    if (detail.type === 'interpreted') {
      if (isVoiceCommand(detail.text))
        options.onCommand(detail.text)
      else
        error.value = `未匹配到指令：${transcript.value}`
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
