import type { DisplaySettings } from '../features/device/types'
import { onMounted, onUnmounted, reactive, shallowRef, watch } from 'vue'
import { desktopHostServices, desktopHostState, hostRecord, importLegacyPreferences, validDisplaySettings } from '../features/device/hostServices'
import { localeKey, resolveLocale, setLocale } from '../i18n/locale'

export const settingsKey = 'augma-device-settings-v1'
const defaults: DisplaySettings = { opacity: 88, volume: 35, dark: false, showHud: true, mirror: false, focus: false, depthMotion: false, sceneBackdrop: true, curvedHud: false, speechFeedback: true }

export function useDisplaySettings() {
  const host = desktopHostServices()
  const state = reactive<DisplaySettings>({ ...defaults })
  // Native preferences are authoritative. Existing scene/voice actions can request a
  // change through this facade; only a host snapshot changes the rendered state.
  const settings = host
    ? new Proxy(state, {
        set(target, key, value) {
          if (typeof key !== 'string')
            return true
          const validated = validDisplaySettings({ [key]: value })
          const name = key as keyof DisplaySettings
          const next = validated[name]
          if (next !== undefined && next !== target[name])
            host.postMessage({ action: 'setting', key: name, value: next })
          return true
        },
      })
    : state
  const storageAvailable = shallowRef(true)
  let previousTheme: string | null = null
  let hydrated = false
  const applyTheme = () => document.documentElement.setAttribute('data-agm-theme', settings.dark ? 'dark' : 'light')
  function applyHostState(value: unknown) {
    if (!hostRecord(value))
      return
    Object.assign(state, validDisplaySettings(value.settings))
    const nextLocale = resolveLocale(value.locale)
    if (nextLocale)
      setLocale(nextLocale, false)
    if (hydrated)
      applyTheme()
  }
  function onHostState(event: Event) {
    applyHostState((event as CustomEvent).detail)
  }
  if (host)
    applyHostState(desktopHostState())
  onMounted(() => {
    previousTheme = document.documentElement.getAttribute('data-agm-theme')
    if (host) {
      window.addEventListener('augma:host-state', onHostState)
      let legacySettings: Partial<DisplaySettings> = {}
      let legacyLocale: string | null = null
      try {
        legacySettings = validDisplaySettings(JSON.parse(localStorage.getItem(settingsKey) || 'null'))
      }
      catch {}
      try {
        legacyLocale = resolveLocale(localStorage.getItem(localeKey))
      }
      catch {}
      importLegacyPreferences(host, legacySettings, legacyLocale)
      hydrated = true
      applyTheme()
      return
    }
    try {
      const saved: unknown = JSON.parse(localStorage.getItem(settingsKey) || 'null')
      Object.assign(settings, validDisplaySettings(saved))
    }
    catch {
      storageAvailable.value = false
    }
    hydrated = true
    applyTheme()
  })
  watch(settings, () => {
    if (!hydrated || host)
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
    window.removeEventListener('augma:host-state', onHostState)
    if (previousTheme === null)
      document.documentElement.removeAttribute('data-agm-theme')
    else
      document.documentElement.setAttribute('data-agm-theme', previousTheme)
  })
  return { settings, storageAvailable, reset: () => host ? host.postMessage({ action: 'resetSettings' }) : Object.assign(settings, defaults) }
}
