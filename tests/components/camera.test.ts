import { mount } from '@vue/test-utils'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { defineComponent, h } from 'vue'
import { useCamera } from '../../apps/ar/src/composables/useCamera'

afterEach(() => {
  delete (window as Window & { __AUGMA_DESKTOP_NATIVE_MAP_CAMERA__?: boolean }).__AUGMA_DESKTOP_NATIVE_MAP_CAMERA__
  vi.unstubAllGlobals()
})
describe('camera ownership', () => {
  it('never requests browser permission when capture belongs to the native host', async () => {
    const getUserMedia = vi.fn()
    vi.stubGlobal('navigator', { mediaDevices: { getUserMedia } })
    Object.assign(window, { __AUGMA_DESKTOP_NATIVE_MAP_CAMERA__: true })
    let camera!: ReturnType<typeof useCamera>
    const wrapper = mount(defineComponent({
      setup() {
        camera = useCamera()
        return () => h('div')
      },
    }))
    await camera.start()
    await camera.flip()
    expect(getUserMedia).not.toHaveBeenCalled()
    expect(camera.stream.value).toBeNull()
    expect(camera.error.value).toBe('')
    expect(camera.busy.value).toBe(false)
    wrapper.unmount()
  })

  it('releases a browser permission response if capture ownership changes while awaiting permission', async () => {
    let resolve!: (stream: MediaStream) => void
    const stop = vi.fn()
    vi.stubGlobal('navigator', { mediaDevices: { getUserMedia: vi.fn(() => new Promise<MediaStream>((done) => {
      resolve = done
    })) } })
    let camera!: ReturnType<typeof useCamera>
    const wrapper = mount(defineComponent({
      setup() {
        camera = useCamera()
        return () => h('div')
      },
    }))
    const pending = camera.start()
    Object.assign(window, { __AUGMA_DESKTOP_NATIVE_MAP_CAMERA__: true })
    resolve({ getTracks: () => [{ stop }] } as unknown as MediaStream)
    await pending
    expect(stop).toHaveBeenCalledOnce()
    expect(camera.stream.value).toBeNull()
    expect(camera.busy.value).toBe(false)
    wrapper.unmount()
  })

  it('stops a late camera response after leaving the page', async () => {
    let resolve!: (s: MediaStream) => void
    const stop = vi.fn()
    const getUserMedia = vi.fn(
      () =>
        new Promise<MediaStream>((r) => {
          resolve = r
        }),
    )
    vi.stubGlobal('navigator', { mediaDevices: { getUserMedia } })
    let camera!: ReturnType<typeof useCamera>
    const wrapper = mount(
      defineComponent({
        setup() {
          camera = useCamera()
          return () => h('div')
        },
      }),
    )
    const pending = camera.start()
    wrapper.unmount()
    resolve({ getTracks: () => [{ stop }] } as unknown as MediaStream)
    await pending
    expect(stop).toHaveBeenCalledOnce()
    expect(camera.stream.value).toBeNull()
  })
  it('releases an active stream when stopped and reports denied permission', async () => {
    const stop = vi.fn()
    const getUserMedia = vi
      .fn()
      .mockResolvedValueOnce({ getTracks: () => [{ stop }] })
      .mockRejectedValueOnce(new DOMException('Denied', 'NotAllowedError'))
    vi.stubGlobal('navigator', { mediaDevices: { getUserMedia } })
    let camera!: ReturnType<typeof useCamera>
    const wrapper = mount(
      defineComponent({
        setup() {
          camera = useCamera()
          return () => h('div')
        },
      }),
    )
    await camera.start()
    camera.stop()
    expect(stop).toHaveBeenCalledOnce()
    await camera.start()
    expect(camera.error.value).toBe('camera.error.permission')
    expect(camera.busy.value).toBe(false)
    wrapper.unmount()
  })
})
