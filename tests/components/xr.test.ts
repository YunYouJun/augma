import { flushPromises, mount } from '@vue/test-utils'
import { describe, expect, it, vi } from 'vitest'
import { defineComponent, h } from 'vue'
import { useXr } from '../../apps/ar/src/composables/useXr'

const runtime = vi.hoisted(() => ({ createXrScene: vi.fn(), createExperience: vi.fn() }))
vi.mock('../../apps/ar/src/composables/xrRuntime', () => runtime)

describe('xR resource ownership', () => {
  it('disposes a late preparation result after the device disconnects', async () => {
    const engine = { dispose: vi.fn(), runRenderLoop: vi.fn() }
    const scene = { dispose: vi.fn() }
    const experience = { dispose: vi.fn() }
    let resolve!: (value: typeof experience) => void
    runtime.createXrScene.mockReturnValue({ engine, scene })
    runtime.createExperience.mockImplementation(() => new Promise((r) => {
      resolve = r
    }))
    let xr!: ReturnType<typeof useXr>
    const wrapper = mount(defineComponent({
      setup() {
        xr = useXr()
        return () => h('div')
      },
    }))
    const pending = xr.prepare(document.createElement('canvas'))
    await flushPromises()
    xr.stop()
    resolve(experience)
    await pending
    expect(xr.ready.value).toBe(false)
    expect(xr.busy.value).toBe(false)
    expect(engine.runRenderLoop).not.toHaveBeenCalled()
    expect(experience.dispose).toHaveBeenCalledOnce()
    expect(scene.dispose).toHaveBeenCalledOnce()
    expect(engine.dispose).toHaveBeenCalledOnce()
    wrapper.unmount()
  })
})
