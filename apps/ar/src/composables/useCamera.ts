import { onMounted, onUnmounted, shallowRef } from 'vue'

export function useCamera() {
  const stream = shallowRef<MediaStream | null>(null)
  const busy = shallowRef(false)
  const error = shallowRef('')
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
    if (!navigator.mediaDevices?.getUserMedia) {
      error.value = '当前环境不支持摄像头，请使用 HTTPS 和支持摄像头的浏览器。'
      return
    }
    busy.value = true
    try {
      const next = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: { ideal: facing.value } },
        audio: false,
      })
      if (request !== generation) {
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
          ? '摄像头权限未开启。可在浏览器设置中允许后重试，或继续体验模拟界面。'
          : '未能打开摄像头，请检查设备是否可用后重试。'
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
  onMounted(() => window.addEventListener('pagehide', stop))
  onUnmounted(() => {
    window.removeEventListener('pagehide', stop)
    stop()
  })
  return { stream, busy, error, facing, start, stop, flip }
}
