import { mount } from '@vue/test-utils'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { defineComponent, h, nextTick, shallowRef } from 'vue'
import { useMotionBudget } from '../../apps/ar/src/features/device/backdrop/useMotionBudget'

let now = 0
let frames = new Map<number, FrameRequestCallback>()
let nextFrame = 0
let hidden = false

/** Advance the clock by `interval` milliseconds per frame and run `count` frames. */
function runFrames(interval: number, count: number) {
  for (let i = 0; i < count; i++) {
    now += interval
    const pending = [...frames.values()]
    frames.clear()
    pending.forEach(callback => callback(now))
  }
}

function mountBudget() {
  const paused = shallowRef(false)
  let still!: ReturnType<typeof useMotionBudget>
  const wrapper = mount(defineComponent({
    setup() {
      still = useMotionBudget(paused, 1000, 1000)
      return () => h('div')
    },
  }))
  return { paused, still, wrapper }
}

beforeEach(() => {
  now = 0
  frames = new Map()
  hidden = false
  vi.useFakeTimers({ toFake: ['setTimeout', 'clearTimeout'] })
  vi.spyOn(performance, 'now').mockImplementation(() => now)
  vi.stubGlobal('requestAnimationFrame', (callback: FrameRequestCallback) => {
    frames.set(++nextFrame, callback)
    return nextFrame
  })
  vi.stubGlobal('cancelAnimationFrame', (id: number) => frames.delete(id))
  Object.defineProperty(document, 'hidden', { configurable: true, get: () => hidden })
})
afterEach(() => {
  vi.useRealTimers()
  vi.unstubAllGlobals()
  Reflect.deleteProperty(document, 'hidden')
})

describe('scene backdrop motion budget', () => {
  it('holds the scenery still when frames stay slow after it settles', () => {
    const { still } = mountBudget()
    vi.advanceTimersByTime(1000)
    runFrames(120, 12)
    expect(still.value).toBe(true)
  })

  it('keeps the motion when the browser renders smoothly', () => {
    const { still } = mountBudget()
    vi.advanceTimersByTime(1000)
    runFrames(17, 80)
    expect(still.value).toBe(false)
    expect(frames.size).toBe(0)
  })

  it('waits for a hidden tab to come back before sampling', () => {
    hidden = true
    const { still } = mountBudget()
    vi.advanceTimersByTime(1000)
    expect(frames.size).toBe(0)
    hidden = false
    document.dispatchEvent(new Event('visibilitychange'))
    vi.advanceTimersByTime(1000)
    runFrames(120, 12)
    expect(still.value).toBe(true)
  })

  it('samples only while the scene moves', async () => {
    const { paused, still } = mountBudget()
    vi.advanceTimersByTime(1000)
    runFrames(120, 3)
    paused.value = true
    await nextTick()
    expect(frames.size).toBe(0)
    vi.advanceTimersByTime(5000)
    expect(frames.size).toBe(0)
    paused.value = false
    await nextTick()
    vi.advanceTimersByTime(1000)
    runFrames(17, 80)
    expect(still.value).toBe(false)
  })

  it('stops sampling once unmounted', () => {
    const { still, wrapper } = mountBudget()
    wrapper.unmount()
    vi.advanceTimersByTime(1000)
    expect(frames.size).toBe(0)
    expect(still.value).toBe(false)
  })
})
