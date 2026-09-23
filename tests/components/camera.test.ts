import { mount } from '@vue/test-utils'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { defineComponent, h } from 'vue'
import { useCamera } from '../../apps/ar/src/composables/useCamera'

afterEach(() => vi.unstubAllGlobals())
describe('camera ownership', () => {
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
    expect(camera.error.value).toContain('权限')
    expect(camera.busy.value).toBe(false)
    wrapper.unmount()
  })
})
