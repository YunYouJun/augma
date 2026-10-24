import type { Ref } from 'vue'
import type { MessageKey } from '../i18n/locale'
import { computed, onMounted, onUnmounted, readonly, shallowRef, watch } from 'vue'
import { desktopHostServices, desktopHostState, hostRecord } from '../features/device/hostServices'

export type SoundscapeId = 'echo' | 'drift' | 'letter'

export const soundscapes: { id: SoundscapeId, notes: number[] }[] = [
  { id: 'echo', notes: [174.61, 220, 261.63] },
  { id: 'drift', notes: [196, 246.94, 293.66] },
  { id: 'letter', notes: [164.81, 207.65, 246.94] },
]

export function useSoundscape(volume: Ref<number>) {
  const host = desktopHostServices()
  const trackIndex = shallowRef(0)
  const playing = shallowRef(false)
  const busy = shallowRef(false)
  const elapsed = shallowRef(0)
  const error = shallowRef<MessageKey | ''>('')
  const track = computed(() => soundscapes[trackIndex.value])
  let context: AudioContext | undefined
  let gain: GainNode | undefined
  let oscillators: OscillatorNode[] = []
  let timer: ReturnType<typeof setInterval> | undefined
  let startedAt = 0
  let generation = 0
  const duration = 120
  function applyHostState(value: unknown) {
    if (!hostRecord(value) || !hostRecord(value.audio))
      return
    const audio = value.audio
    if (typeof audio.trackIndex === 'number' && Number.isInteger(audio.trackIndex) && soundscapes[audio.trackIndex])
      trackIndex.value = audio.trackIndex
    if (typeof audio.playing === 'boolean')
      playing.value = audio.playing
    if (typeof audio.busy === 'boolean')
      busy.value = audio.busy
    if (typeof audio.elapsed === 'number' && Number.isFinite(audio.elapsed))
      elapsed.value = Math.max(0, Math.min(duration, audio.elapsed))
    if (typeof audio.error === 'string')
      error.value = audio.error ? 'sound.error' : ''
  }
  function onHostState(event: Event) {
    applyHostState((event as CustomEvent).detail)
  }
  if (host)
    applyHostState(desktopHostState())
  function stopNodes() {
    oscillators.forEach((node) => {
      node.stop()
      node.disconnect()
    })
    oscillators = []
  }
  function pause() {
    if (host) {
      host.postMessage({ action: 'pause' })
      return
    }
    generation++
    busy.value = false
    if (playing.value)
      elapsed.value = Math.min(duration, (performance.now() - startedAt) / 1000)
    playing.value = false
    clearInterval(timer)
    stopNodes()
    void context?.suspend().catch(() => {})
  }
  async function play() {
    if (playing.value || busy.value)
      return
    if (host) {
      host.postMessage({ action: 'play' })
      return
    }
    busy.value = true
    const request = ++generation
    error.value = ''
    try {
      context ??= new AudioContext()
      gain ??= context.createGain()
      gain.disconnect()
      gain.connect(context.destination)
      gain.gain.value = volume.value / 100 * 0.065
      await context.resume()
      if (request !== generation)
        return
      if (elapsed.value >= duration)
        elapsed.value = 0
      oscillators = track.value.notes.map((frequency, index) => {
        const node = context!.createOscillator()
        node.frequency.value = frequency
        node.detune.value = index * 2
        node.connect(gain!)
        node.start()
        return node
      })
      startedAt = performance.now() - elapsed.value * 1000
      playing.value = true
      timer = setInterval(() => {
        elapsed.value = Math.min(duration, (performance.now() - startedAt) / 1000)
        if (elapsed.value >= duration)
          pause()
      }, 250)
    }
    catch {
      pause()
      error.value = 'sound.error'
    }
    finally {
      if (request === generation)
        busy.value = false
    }
  }
  function selectTrack(index: number) {
    if (!Number.isInteger(index) || !soundscapes[index])
      return
    if (host) {
      host.postMessage({ action: 'track', value: index })
      return
    }
    const resume = playing.value
    pause()
    elapsed.value = 0
    trackIndex.value = index
    if (resume)
      void play()
  }
  function seek(value: number) {
    if (!Number.isFinite(value))
      return
    const next = Math.max(0, Math.min(duration, value))
    if (host) {
      host.postMessage({ action: 'seek', value: next })
      return
    }
    elapsed.value = next
    startedAt = performance.now() - elapsed.value * 1000
  }
  watch(volume, (value) => {
    if (gain && context)
      gain.gain.setTargetAtTime(value / 100 * 0.065, context.currentTime, 0.05)
  })
  function onVisibility() {
    if (document.hidden)
      pause()
  }
  onMounted(() => {
    if (host)
      window.addEventListener('augma:host-state', onHostState)
    else
      document.addEventListener('visibilitychange', onVisibility)
  })
  onUnmounted(() => {
    window.removeEventListener('augma:host-state', onHostState)
    if (host)
      return
    pause()
    document.removeEventListener('visibilitychange', onVisibility)
    void context?.close().catch(() => {})
  })
  return { track, trackIndex: readonly(trackIndex), playing: readonly(playing), busy: readonly(busy), elapsed: readonly(elapsed), error: readonly(error), duration, play, pause, selectTrack, seek }
}
