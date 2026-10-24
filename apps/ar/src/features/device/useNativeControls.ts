import type { Ref } from 'vue'
import type { useCamera } from '../../composables/useCamera'
import type { useSimulator } from '../../composables/useSimulator'
import type { useSoundscape } from '../../composables/useSoundscape'
import type { useXr } from '../../composables/useXr'
import type { Locale, Message, MessageKey } from '../../i18n/locale'
import type { DisplaySettings } from './types'
import type { useSpeechCommands } from './useSpeechCommands'
import { computed, onMounted, onUnmounted, readonly, shallowRef, watch } from 'vue'
import { soundscapes } from '../../composables/useSoundscape'
import { formatTime, locale, resolveLocale, t } from '../../i18n/locale'
import { zhCN } from '../../i18n/messages/zh-CN'
import { desktopHostServices } from './hostServices'
import { desktopNativeSpace } from './nativeSpace'

interface NativeControlsOptions {
  device: ReturnType<typeof useSimulator>
  settings: DisplaySettings
  sound: ReturnType<typeof useSoundscape>
  camera: ReturnType<typeof useCamera>
  xr: ReturnType<typeof useXr>
  speech: ReturnType<typeof useSpeechCommands>
  message: Ref<Message | null>
  notification: Ref<boolean>
  storageAvailable: Ref<boolean>
  speechFeedbackSupported: boolean
  startSpeech: () => void
  changeLocale: (locale: Locale) => void
  resetSettings: () => void
  snapshot: () => void
  prepareXr: () => Promise<void>
}

type NativeWindow = Window & {
  __AUGMA_DESKTOP_NATIVE_CONTROLS__?: boolean
  __AUGMA_DESKTOP_NATIVE_MAP_CAMERA__?: boolean
  webkit?: { messageHandlers?: { nativeState?: { postMessage: (state: unknown) => void } } }
}

/** SwiftUI owns controls; the page publishes only scene state when native host services are available. */
export function useNativeControls(options: NativeControlsOptions) {
  const host = window as NativeWindow
  const bridge = host.webkit?.messageHandlers?.nativeState
  const enabled = host.__AUGMA_DESKTOP_NATIVE_CONTROLS__ === true && !!bridge
  const nativeMapCamera = host.__AUGMA_DESKTOP_NATIVE_MAP_CAMERA__ === true
  const hostServices = desktopHostServices()
  const nativeSpace = desktopNativeSpace()
  const { device, settings, sound, camera, xr, speech } = options
  const sceneVisible = shallowRef(true)
  // Cached by locale rather than translating the catalog on every playback/scan tick.
  const labels = computed(() => Object.fromEntries((Object.keys(zhCN) as MessageKey[])
    .filter(key => /^(?:module|connection|device|scene|space|navigation|sound|notifications|settings|weather|camera|commands|dock)\./.test(key))
    .map(key => [key, t(key)])))
  const notices = computed(() => device.notices.value.map(item => ({
    id: item.id,
    title: t(item.title),
    detail: t(item.detail),
    time: formatTime(item.at),
  })))
  const tracks = computed(() => soundscapes.map(item => ({
    id: item.id,
    name: t(`sound.track.${item.id}.name`),
    subtitle: t(`sound.track.${item.id}.subtitle`),
  })))
  const state = computed(() => ({
    version: 2,
    ...(!hostServices ? { locale: locale.value, settings: { ...settings } } : {}),
    labels: labels.value,
    online: device.online.value,
    connection: device.connection.value,
    storageAvailable: options.storageAvailable.value,
    speechFeedbackSupported: options.speechFeedbackSupported,
    scene: device.scene.value,
    selected: device.selected.value,
    scanning: device.scanning.value,
    scanProgress: device.scanProgress.value,
    pinned: device.pinned.value,
    routeStep: device.routeStep.value,
    routeProgress: device.routeProgress.value,
    remaining: device.remaining.value,
    routeInstruction: device.routeInstruction.value,
    notices: notices.value,
    message: options.notification.value && options.message.value ? t(options.message.value) : '',
    ...(!hostServices
      ? {
          soundElapsed: sound.elapsed.value,
          sound: {
            playing: sound.playing.value,
            busy: sound.busy.value,
            duration: sound.duration,
            trackIndex: sound.trackIndex.value,
            error: sound.error.value ? t(sound.error.value) : '',
            tracks: tracks.value,
          },
        }
      : {}),
    camera: { live: !!camera.stream.value, busy: camera.busy.value, error: camera.error.value ? t(camera.error.value) : '' },
    xr: { supported: xr.supported.value, ready: xr.ready.value, active: xr.active.value, busy: xr.busy.value, error: xr.error.value ? t(xr.error.value) : '' },
    speech: { available: speech.available, status: speech.status.value, transcript: speech.transcript.value, reply: speech.reply.value, error: speech.error.value ? t(speech.error.value) : '', assistantReady: speech.assistantReady.value },
  }))

  function receive(event: Event) {
    const detail: unknown = (event as CustomEvent).detail
    if (!detail || typeof detail !== 'object' || !('action' in detail))
      return
    const { action, value } = detail as { action: unknown, value?: unknown }
    if (typeof action === 'string' && nativeSpace?.request(action, value))
      return
    // Explicit allowlist: native controls never evaluate arbitrary code or mutate arbitrary fields.
    switch (action) {
      case 'setting': {
        if (!value || typeof value !== 'object')
          return
        const { key, value: next } = value as { key: unknown, value: unknown }
        for (const name of ['dark', 'showHud', 'mirror', 'focus', 'depthMotion', 'sceneBackdrop', 'curvedHud', 'speechFeedback'] as const) {
          if (key === name && typeof next === 'boolean')
            settings[name] = next
        }
        for (const name of ['opacity', 'volume'] as const) {
          if (key === name && typeof next === 'number' && Number.isFinite(next))
            settings[name] = Math.min(100, Math.max(name === 'opacity' ? 60 : 0, next))
        }
        return
      }
      case 'locale': {
        const next = resolveLocale(value)
        if (next)
          options.changeLocale(next)
        return
      }
      case 'scene':
        if (value === 'garden' || value === 'city')
          device.changeScene(value)
        return
      case 'landmark':
        if (typeof value === 'string')
          device.selectLandmark(value)
        return
      case 'scan':
        if (sceneVisible.value)
          device.scan()
        return
      case 'cancelScan': return device.cancelScan()
      case 'pin': return device.togglePin()
      case 'routeStart':
        device.startRoute()
        if (nativeMapCamera)
          device.openModule('space')
        return
      case 'routeNext':
        device.advanceRoute()
        if (nativeMapCamera)
          device.openModule('space')
        return
      case 'routeStop':
        device.cancelRoute()
        if (nativeMapCamera)
          device.openModule('space')
        return
      case 'connect': return device.connect()
      case 'sleep': return device.suspend('sleeping')
      case 'disconnect': return device.suspend('disconnected')
      case 'clearNotices': return device.clearNotices()
      case 'dismissMessage':
        options.notification.value = false
        return
      case 'resetSettings': return options.resetSettings()
      case 'play':
        if (hostServices || device.online.value)
          void sound.play()
        return
      case 'pause': return sound.pause()
      case 'track':
        if ((hostServices || device.online.value) && typeof value === 'number' && Number.isInteger(value) && soundscapes[value])
          sound.selectTrack(value)
        return
      case 'seek':
        if ((hostServices || device.online.value) && typeof value === 'number' && Number.isFinite(value))
          sound.seek(value)
        return
      case 'cameraStart':
        if (nativeMapCamera) {
          device.openModule('camera')
          return
        }
        if (sceneVisible.value && device.online.value && !xr.ready.value && !xr.busy.value)
          void camera.start()
        return
      case 'cameraStop': return camera.stop()
      case 'cameraFlip':
        if (nativeMapCamera) {
          device.openModule('camera')
          return
        }
        if (sceneVisible.value && camera.stream.value && !camera.busy.value)
          void camera.flip()
        return
      case 'capture':
        if (nativeMapCamera) {
          device.openModule('camera')
          return
        }
        if (sceneVisible.value && camera.stream.value)
          options.snapshot()
        return
      case 'xrPrepare':
        if (nativeMapCamera)
          return
        if (sceneVisible.value && device.online.value && xr.supported.value && !camera.busy.value)
          void options.prepareXr()
        return
      case 'xrEnter':
        if (nativeMapCamera)
          return
        if (sceneVisible.value && xr.ready.value && !xr.active.value && !xr.busy.value)
          void xr.enter()
        return
      case 'xrStop': return xr.stop()
      case 'speechStart': return options.startSpeech()
      case 'speechStop': return speech.stop()
      case 'speechCancel': return speech.cancel()
      case 'submit':
        if (typeof value === 'string' && value.trim() && value.length <= 500)
          speech.submitText(value)
    }
  }

  function receiveVisibility(event: Event) {
    const detail: unknown = (event as CustomEvent).detail
    if (!detail || typeof detail !== 'object' || !('visible' in detail) || typeof detail.visible !== 'boolean')
      return
    if (sceneVisible.value === detail.visible)
      return
    sceneVisible.value = detail.visible
    if (!detail.visible) {
      camera.stop()
      xr.stop()
      device.cancelScan()
      speech.cancel()
    }
  }

  // WK messages are ordered. Send unchanged catalogs and collections only once per change.
  const previous = new Map<string, { value: unknown, encoded: string }>()
  function publish(snapshot: Record<string, unknown>) {
    const initial = previous.size === 0
    const changes: Record<string, unknown> = {}
    for (const [key, value] of Object.entries(snapshot)) {
      const old = previous.get(key)
      if (old && Object.is(old.value, value))
        continue
      const encoded = JSON.stringify(value)
      if (!old || encoded !== old.encoded)
        changes[key] = value
      previous.set(key, { value, encoded })
    }
    if (Object.keys(changes).length)
      bridge!.postMessage({ version: 2, initial, changes })
  }

  let stop: (() => void) | undefined
  onMounted(() => {
    if (nativeMapCamera) {
      camera.stop()
      xr.stop()
    }
    if (!enabled)
      return
    window.addEventListener('augma:native-action', receive)
    window.addEventListener('augma:native-visibility', receiveVisibility)
    stop = watch(state, publish, { immediate: true, flush: 'post' })
  })
  onUnmounted(() => {
    stop?.()
    window.removeEventListener('augma:native-action', receive)
    window.removeEventListener('augma:native-visibility', receiveVisibility)
  })
  return { enabled, sceneVisible: readonly(sceneVisible) }
}
