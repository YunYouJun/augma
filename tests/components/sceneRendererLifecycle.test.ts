import type { SceneRenderer, SceneRendererFactory } from '../../apps/ar/src/features/device/backdrop/sceneRenderer'
import { flushPromises, mount } from '@vue/test-utils'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { defineComponent, h, nextTick, reactive, shallowRef } from 'vue'
import { useSceneRenderer } from '../../apps/ar/src/features/device/backdrop/useSceneRenderer'

const cleanups: (() => void)[] = []
let hidden = false
let reducedMotion = false
let media: EventTarget
let disconnect: ReturnType<typeof vi.fn>

function mountScene(loadRenderer: () => Promise<SceneRendererFactory>) {
  const motion = reactive({ paused: false, depthEnabled: true })
  const wrapper = mount(defineComponent({
    setup() {
      const canvas = shallowRef<HTMLCanvasElement | null>(null)
      const { state } = useSceneRenderer(canvas, motion, loadRenderer)
      return () => h('div', { 'class': 'ar-app', 'data-renderer': state.value }, [h('canvas', { ref: canvas })])
    },
  }))
  cleanups.push(() => wrapper.unmount())
  return { wrapper, motion }
}

function fakeRenderer(): SceneRenderer {
  return { resize: vi.fn(), setPaused: vi.fn(), setDepth: vi.fn(), dispose: vi.fn() }
}

beforeEach(() => {
  hidden = false
  reducedMotion = false
  media = new EventTarget()
  disconnect = vi.fn()
  vi.useFakeTimers({ toFake: ['setTimeout', 'clearTimeout'] })
  Object.defineProperty(document, 'hidden', { configurable: true, get: () => hidden })
  Object.defineProperty(media, 'matches', { get: () => reducedMotion })
  vi.stubGlobal('matchMedia', () => media)
  vi.stubGlobal('ResizeObserver', class {
    observe() {}
    disconnect = disconnect
  })
})

afterEach(() => {
  cleanups.splice(0).forEach(cleanup => cleanup())
  vi.useRealTimers()
  vi.unstubAllGlobals()
  Reflect.deleteProperty(document, 'hidden')
})

describe('shared scenery renderer lifecycle', () => {
  it('does not create GPU resources when the scene leaves before its lazy import resolves', async () => {
    let resolveImport!: (factory: SceneRendererFactory) => void
    const loading = new Promise<SceneRendererFactory>((resolve) => {
      resolveImport = resolve
    })
    const createRenderer = vi.fn(() => fakeRenderer())
    const { wrapper } = mountScene(() => loading)
    expect(wrapper.attributes('data-renderer')).toBe('loading')

    wrapper.unmount()
    resolveImport(createRenderer)
    await flushPromises()

    expect(createRenderer).not.toHaveBeenCalled()
  })

  it('resumes only after panel, reduced-motion and visibility pauses have all cleared', async () => {
    const renderer = fakeRenderer()
    const { wrapper, motion } = mountScene(async () => (_canvas, onState) => {
      onState('webgl')
      return renderer
    })
    await flushPromises()
    expect(wrapper.attributes('data-renderer')).toBe('webgl')
    expect(renderer.setPaused).toHaveBeenLastCalledWith(false)

    motion.paused = true
    await nextTick()
    expect(renderer.setPaused).toHaveBeenLastCalledWith(true)
    hidden = true
    document.dispatchEvent(new Event('visibilitychange'))
    motion.paused = false
    await nextTick()
    expect(renderer.setPaused).toHaveBeenLastCalledWith(true)

    reducedMotion = true
    media.dispatchEvent(new Event('change'))
    hidden = false
    document.dispatchEvent(new Event('visibilitychange'))
    expect(renderer.setPaused).toHaveBeenLastCalledWith(true)
    expect(renderer.setDepth).toHaveBeenLastCalledWith(0, 0)

    reducedMotion = false
    media.dispatchEvent(new Event('change'))
    await nextTick()
    expect(renderer.setPaused).toHaveBeenLastCalledWith(false)
  })

  it('disposes its renderer and detaches global motion listeners on unmount', async () => {
    const renderer = fakeRenderer()
    const { wrapper } = mountScene(async () => (_canvas, onState) => {
      onState('webgl')
      return renderer
    })
    await flushPromises()
    wrapper.unmount()
    expect(renderer.dispose).toHaveBeenCalledOnce()
    expect(disconnect).toHaveBeenCalledOnce()
    vi.mocked(renderer.setPaused).mockClear()
    vi.mocked(renderer.setDepth).mockClear()

    hidden = true
    reducedMotion = true
    document.dispatchEvent(new Event('visibilitychange'))
    media.dispatchEvent(new Event('change'))
    window.dispatchEvent(new Event('blur'))
    await nextTick()

    expect(renderer.setPaused).not.toHaveBeenCalled()
    expect(renderer.setDepth).not.toHaveBeenCalled()
    expect(vi.getTimerCount()).toBe(0)
  })
})
