import type { Ref } from 'vue'
import { onMounted, onUnmounted, readonly, shallowRef, watch } from 'vue'

/** A median frame slower than this, about 20 fps, cannot carry the ambient motion. */
const slowFrame = 50

/**
 * Whether the scenery should hold still because this browser cannot keep its motion smooth.
 *
 * Without a GPU (a virtual machine, CI or an old computer) every frame of the layered scenery is composited in
 * software, and its drifting layers can stall the whole simulator, panels included. Once the scene has settled,
 * this samples the frame rate for a moment; below about 20 fps the scenery stays still, as under reduced motion.
 * Only a visible, moving scene is sampled: a paused scene renders cheaply and would hide a slow machine.
 *
 * @param paused - Whether the scenery is paused, for example behind an open panel
 * @param settle - How long the scene moves before sampling, in milliseconds
 * @param sample - How long to sample frames, in milliseconds
 */
export function useMotionBudget(paused: Readonly<Ref<boolean>>, settle = 1500, sample = 1500) {
  const still = shallowRef(false)
  let decided = false
  let timer: ReturnType<typeof setTimeout> | undefined
  let frame: number | undefined

  function stop() {
    clearTimeout(timer)
    timer = undefined
    if (frame !== undefined)
      cancelAnimationFrame(frame)
    frame = undefined
  }
  function measure() {
    timer = undefined
    const intervals: number[] = []
    let last = performance.now()
    const end = last + sample
    function tick(now: number) {
      intervals.push(now - last)
      last = now
      if (now < end) {
        frame = requestAnimationFrame(tick)
        return
      }
      frame = undefined
      decided = true
      intervals.sort((a, b) => a - b)
      still.value = intervals.length < 3 || intervals[intervals.length >> 1]! > slowFrame
    }
    frame = requestAnimationFrame(tick)
  }
  // Sampling starts over whenever the scene stops moving or the tab is hidden, which also pauses frames.
  function sync() {
    if (decided || document.hidden || paused.value)
      stop()
    else if (timer === undefined && frame === undefined)
      timer = setTimeout(measure, settle)
  }

  watch(paused, sync)
  onMounted(() => {
    sync()
    document.addEventListener('visibilitychange', sync)
  })
  onUnmounted(() => {
    stop()
    document.removeEventListener('visibilitychange', sync)
  })

  return readonly(still)
}
