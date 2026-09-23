import { mount } from '@vue/test-utils'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { defineComponent, h, shallowRef } from 'vue'
import { useSoundscape } from '../../apps/ar/src/composables/useSoundscape'

afterEach(() => {
  vi.unstubAllGlobals()
  vi.useRealTimers()
})

describe('sound resource ownership', () => {
  function setup(resume = vi.fn().mockResolvedValue(undefined)) {
    const stop = vi.fn()
    const close = vi.fn().mockResolvedValue(undefined)
    const suspend = vi.fn().mockResolvedValue(undefined)
    const createOscillator = vi.fn(() => ({ frequency: { value: 0 }, detune: { value: 0 }, connect: vi.fn(), start: vi.fn(), disconnect: vi.fn(), stop }))
    vi.stubGlobal('AudioContext', class {
      resume = resume
      close = close
      suspend = suspend
      createOscillator = createOscillator
      createGain = () => ({ gain: { value: 0, setTargetAtTime: vi.fn() }, connect: vi.fn(), disconnect: vi.fn() })
    })
    let sound!: ReturnType<typeof useSoundscape>
    const wrapper = mount(defineComponent({
      setup() {
        sound = useSoundscape(shallowRef(35))
        return () => h('div')
      },
    }))
    return { sound, wrapper, createOscillator, stop, close, suspend }
  }

  it('does not start sound if the device pauses while audio permission is pending', async () => {
    let resolve!: () => void
    const resume = vi.fn(() => new Promise<void>((r) => {
      resolve = r
    }))
    const { sound, wrapper, createOscillator, close } = setup(resume)
    const pending = sound.play()
    sound.pause()
    resolve()
    await pending
    expect(createOscillator).not.toHaveBeenCalled()
    expect(sound.playing.value).toBe(false)
    wrapper.unmount()
    expect(close).toHaveBeenCalledOnce()
  })

  it('stops every oscillator and timer when leaving the device view', async () => {
    vi.useFakeTimers()
    const { sound, wrapper, stop, close } = setup()
    await sound.play()
    expect(sound.playing.value).toBe(true)
    vi.advanceTimersByTime(1250)
    expect(sound.elapsed.value).toBeGreaterThan(0)
    wrapper.unmount()
    expect(stop).toHaveBeenCalledTimes(3)
    expect(close).toHaveBeenCalledOnce()
    expect(vi.getTimerCount()).toBe(0)
  })
})
