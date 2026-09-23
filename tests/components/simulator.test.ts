import { mount } from '@vue/test-utils'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { defineComponent, h, nextTick } from 'vue'
import { settingsKey, useDisplaySettings } from '../../apps/ar/src/composables/useDisplaySettings'
import { useSimulator } from '../../apps/ar/src/composables/useSimulator'

const cleanups: (() => void)[] = []
function setup<T>(composable: () => T) {
  let result!: T
  const wrapper = mount(defineComponent({
    setup() {
      result = composable()
      return () => h('div')
    },
  }))
  cleanups.push(() => wrapper.unmount())
  return result
}
afterEach(() => {
  cleanups.splice(0).forEach(cleanup => cleanup())
  vi.useRealTimers()
  localStorage.clear()
})

describe('device simulation', () => {
  it('cancels in-flight scans and navigation when the device sleeps', () => {
    vi.useFakeTimers()
    const device = setup(useSimulator)
    device.scan()
    vi.advanceTimersByTime(700)
    expect(device.scanProgress.value).toBe(35)
    device.startRoute()
    device.suspend('sleeping')
    vi.advanceTimersByTime(5000)
    expect(device.scanning.value).toBe(false)
    expect(device.scanProgress.value).toBe(0)
    expect(device.routeStep.value).toBeNull()
    expect(device.notices.value.some(item => item.title === '空间扫描完成')).toBe(false)
    device.scan()
    expect(device.scanning.value).toBe(false)
    device.connect()
    vi.advanceTimersByTime(900)
    expect(device.online.value).toBe(true)
  })

  it('invalidates scene anchors and routes and completes only the selected destination', () => {
    vi.useFakeTimers()
    const device = setup(useSimulator)
    device.scan()
    vi.advanceTimersByTime(2000)
    device.togglePin()
    expect(device.pinned.value).toBe(true)
    device.startRoute()
    device.advanceRoute()
    expect(device.remaining.value).toBe(90)
    device.changeScene('city')
    expect(device.routeStep.value).toBeNull()
    expect(device.scanProgress.value).toBe(0)
    expect(device.pinned.value).toBe(false)
    expect(device.selected.value.id).toBe('gallery')
    device.selectLandmark('square')
    device.startRoute()
    for (let i = 0; i < 6; i++)
      device.advanceRoute()
    expect(device.routeProgress.value).toBe(100)
    expect(device.remaining.value).toBe(0)
    expect(device.routeInstruction.value).toBe('已到达街角广场')
    expect(device.notices.value.filter(item => item.title === '已到达目的地')).toHaveLength(1)
    device.openModule('notifications')
    expect(device.unread.value).toBe(0)
    device.clearNotices()
    expect(device.notices.value).toHaveLength(0)
  })

  it('disposes the clock, connection and scan timers on unmount', () => {
    vi.useFakeTimers()
    const device = setup(useSimulator)
    device.scan()
    cleanups.splice(0).forEach(cleanup => cleanup())
    expect(vi.getTimerCount()).toBe(0)
    vi.advanceTimersByTime(5000)
    expect(device.scanProgress.value).toBe(0)
  })
})

describe('display preferences', () => {
  it('validates persisted values and persists the reset defaults', async () => {
    localStorage.setItem(settingsKey, JSON.stringify({ opacity: -100, volume: 900, dark: true, mirror: 'yes', showHud: 'false', focus: true, depthMotion: 'true', curvedHud: true }))
    const display = setup(useDisplaySettings)
    expect(display.settings.opacity).toBe(60)
    expect(display.settings.volume).toBe(100)
    expect(display.settings.mirror).toBe(false)
    expect(display.settings.showHud).toBe(true)
    expect(display.settings.depthMotion).toBe(false)
    expect(display.settings.curvedHud).toBe(true)
    expect(document.documentElement.dataset.agmTheme).toBe('dark')
    display.reset()
    await nextTick()
    expect(document.documentElement.dataset.agmTheme).toBe('light')
    expect(JSON.parse(localStorage.getItem(settingsKey)!)).toMatchObject({ opacity: 88, volume: 35, focus: false, depthMotion: false, curvedHud: false })
  })

  it('remains usable with corrupt browser storage', async () => {
    localStorage.setItem(settingsKey, '{bad json')
    const display = setup(useDisplaySettings)
    expect(display.storageAvailable.value).toBe(false)
    display.settings.dark = true
    await nextTick()
    expect(display.storageAvailable.value).toBe(true)
    expect(JSON.parse(localStorage.getItem(settingsKey)!)).toHaveProperty('dark', true)
  })
})
