import type { DisplaySettings } from '../features/device/types'
import { onMounted, onUnmounted, reactive, shallowRef, watch } from 'vue'

export const settingsKey = 'augma-device-settings-v1'
const defaults: DisplaySettings = { opacity: 88, volume: 35, dark: false, showHud: true, mirror: false, focus: false, depthMotion: false, curvedHud: false }

export function useDisplaySettings() {
  const settings = reactive<DisplaySettings>({ ...defaults })
  const storageAvailable = shallowRef(true)
  let previousTheme: string | null = null
  let hydrated = false
  const applyTheme = () => document.documentElement.setAttribute('data-agm-theme', settings.dark ? 'dark' : 'light')
  onMounted(() => {
    previousTheme = document.documentElement.getAttribute('data-agm-theme')
    try {
      const saved: unknown = JSON.parse(localStorage.getItem(settingsKey) || 'null')
      if (saved && typeof saved === 'object') {
        const data = saved as Record<string, unknown>
        for (const key of ['dark', 'showHud', 'mirror', 'focus', 'depthMotion', 'curvedHud'] as const) {
          if (typeof data[key] === 'boolean')
            settings[key] = data[key]
        }
        for (const key of ['opacity', 'volume'] as const) {
          if (typeof data[key] === 'number' && Number.isFinite(data[key]))
            settings[key] = Math.min(100, Math.max(key === 'opacity' ? 60 : 0, data[key]))
        }
      }
    }
    catch {
      storageAvailable.value = false
    }
    hydrated = true
    applyTheme()
  })
  watch(settings, () => {
    if (!hydrated)
      return
    applyTheme()
    try {
      localStorage.setItem(settingsKey, JSON.stringify(settings))
      storageAvailable.value = true
    }
    catch {
      storageAvailable.value = false
    }
  })
  onUnmounted(() => {
    if (previousTheme === null)
      document.documentElement.removeAttribute('data-agm-theme')
    else
      document.documentElement.setAttribute('data-agm-theme', previousTheme)
  })
  return { settings, storageAvailable, reset: () => Object.assign(settings, defaults) }
}
