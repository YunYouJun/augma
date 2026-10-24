import type { DeviceModule } from '../../apps/ar/src/features/device/types'
import { mount } from '@vue/test-utils'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { defineComponent, h, nextTick, shallowRef } from 'vue'
import { useDesktopBridge } from '../../apps/ar/src/features/device/useDesktopBridge'

const desktopKeys = ['__AUGMA_DESKTOP_MODULE__', '__AUGMA_DESKTOP_IMMERSIVE__', '__AUGMA_DESKTOP_VOICE_SHORTCUT__', 'webkit'] as const

function mountBridge() {
  const activeModule = shallowRef<DeviceModule | null>(null)
  const select = vi.fn()
  const toggleSpeech = vi.fn()
  let bridge!: ReturnType<typeof useDesktopBridge>
  const wrapper = mount(defineComponent({
    setup() {
      bridge = useDesktopBridge({ activeModule, select, toggleSpeech })
      return () => h('div')
    },
  }))
  return { wrapper, bridge, activeModule, select, toggleSpeech }
}

const dispatch = (type: string, detail?: unknown) => window.dispatchEvent(new CustomEvent(type, { detail }))

afterEach(() => {
  for (const key of desktopKeys)
    delete (window as unknown as Record<string, unknown>)[key]
  document.documentElement.classList.remove('augma-desktop-immersive')
})

describe('macOS desktop bridge', () => {
  it('opens the module the app asked for on launch and marks the immersive overlay', () => {
    Object.assign(window, { __AUGMA_DESKTOP_MODULE__: 'weather', __AUGMA_DESKTOP_IMMERSIVE__: true })
    const { wrapper, bridge, select } = mountBridge()
    expect(select).toHaveBeenCalledWith('weather')
    expect(bridge.immersive.value).toBe(true)
    expect(document.documentElement.classList.contains('augma-desktop-immersive')).toBe(true)
    wrapper.unmount()
    expect(document.documentElement.classList.contains('augma-desktop-immersive')).toBe(false)
  })

  it('changes presentation in place while preserving the active module', async () => {
    Object.assign(window, { __AUGMA_DESKTOP_IMMERSIVE__: false })
    const { wrapper, bridge, activeModule, select } = mountBridge()
    activeModule.value = 'space'
    for (const detail of [undefined, null, {}, { immersive: 'true' }])
      dispatch('augma:presentation', detail)
    expect(bridge.immersive.value).toBe(false)
    dispatch('augma:presentation', { immersive: true })
    await nextTick()
    expect(bridge.immersive.value).toBe(true)
    expect(document.documentElement.classList.contains('augma-desktop-immersive')).toBe(true)
    expect(activeModule.value).toBe('space')
    expect(select).not.toHaveBeenCalled()
    dispatch('augma:presentation', { immersive: false })
    expect(bridge.immersive.value).toBe(false)
    expect(document.documentElement.classList.contains('augma-desktop-immersive')).toBe(false)
    wrapper.unmount()
    dispatch('augma:presentation', { immersive: true })
    expect(bridge.immersive.value).toBe(false)
  })

  it('ignores native presentation events in an ordinary browser', () => {
    const { wrapper, bridge } = mountBridge()
    dispatch('augma:presentation', { immersive: true })
    expect(bridge.immersive.value).toBe(false)
    expect(document.documentElement.classList.contains('augma-desktop-immersive')).toBe(false)
    wrapper.unmount()
  })

  it('accepts known modules and null from the menu, and ignores anything else', () => {
    const { wrapper, select } = mountBridge()
    dispatch('augma:select-module', { module: 'space' })
    dispatch('augma:select-module', { module: null })
    dispatch('augma:select-module', { module: 'unknown' })
    dispatch('augma:select-module', { module: 3 })
    dispatch('augma:select-module')
    expect(select.mock.calls).toEqual([['space'], [null]])
    wrapper.unmount()
    dispatch('augma:select-module', { module: 'space' })
    expect(select).toHaveBeenCalledTimes(2)
  })

  it('follows the voice menu key and runs the voice menu item', () => {
    Object.assign(window, { __AUGMA_DESKTOP_VOICE_SHORTCUT__: 'Alt+Meta+v' })
    const { wrapper, bridge, toggleSpeech } = mountBridge()
    expect(bridge.voiceShortcut.value).toBe('Alt+Meta+v')
    dispatch('augma:voice-shortcut', { shortcut: 'not a chord' })
    expect(bridge.voiceShortcut.value).toBeNull()
    dispatch('augma:voice-shortcut', { shortcut: 'Ctrl+Meta+F5' })
    expect(bridge.voiceShortcut.value).toBe('Ctrl+Meta+F5')
    dispatch('augma:toggle-speech')
    expect(toggleSpeech).toHaveBeenCalledOnce()
    wrapper.unmount()
    dispatch('augma:toggle-speech')
    expect(toggleSpeech).toHaveBeenCalledOnce()
  })

  it('reports the open app back to the macOS menu', async () => {
    const postMessage = vi.fn()
    Object.assign(window, { webkit: { messageHandlers: { moduleSelection: { postMessage } } } })
    const { wrapper, activeModule } = mountBridge()
    activeModule.value = 'audio'
    await nextTick()
    activeModule.value = null
    await nextTick()
    expect(postMessage.mock.calls).toEqual([['audio'], [null]])
    wrapper.unmount()
  })
})
