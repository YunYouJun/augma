import type { MessageKey } from '../i18n/locale'
import { onMounted, onUnmounted, shallowRef } from 'vue'

function nativeCamera() {
  return (window as Window & { __AUGMA_DESKTOP_NATIVE_MAP_CAMERA__?: boolean }).__AUGMA_DESKTOP_NATIVE_MAP_CAMERA__ === true
}

export function useCamera() {
  const stream = shallowRef<MediaStream | null>(null)
  const busy = shallowRef(false)
  const error = shallowRef<MessageKey | ''>('')
  const facing = shallowRef<'environment' | 'user'>('environment')
  let generation = 0
  function stop() {
    generation++
    stream.value?.getTracks().forEach(track => track.stop())
    stream.value = null
    busy.value = false
  }
  async function start() {
    stop()
    const request = generation
    error.value = ''
    // Desktop capture belongs to AVFoundation, including permission requests.
    if (nativeCamera())
      return
    if (!navigator.mediaDevices?.getUserMedia) {
      error.value = 'camera.error.unsupported'
      return
    }
    busy.value = true
    try {
      const next = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: { ideal: facing.value } },
        audio: false,
      })
      if (request !== generation || nativeCamera()) {
        next.getTracks().forEach(track => track.stop())
        return
      }
      stream.value = next
    }
    catch (cause) {
      if (request !== generation)
        return
      error.value
        = cause instanceof DOMException && cause.name === 'NotAllowedError'
          ? 'camera.error.permission'
          : 'camera.error.failed'
    }
    finally {
      if (request === generation)
        busy.value = false
    }
  }
  async function flip() {
    facing.value = facing.value === 'environment' ? 'user' : 'environment'
    if (stream.value)
      await start()
  }
  onMounted(() => {
    if (nativeCamera())
      stop()
    window.addEventListener('pagehide', stop)
  })
  onUnmounted(() => {
    window.removeEventListener('pagehide', stop)
    stop()
  })
  return { stream, busy, error, facing, start, stop, flip }
}
