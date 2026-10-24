import type { DisplaySettings } from './types'

export type HostServiceAction
  = | { action: 'setting', key: keyof DisplaySettings, value: number | boolean }
    | { action: 'locale', value: string }
    | { action: 'resetSettings' | 'play' | 'pause' }
    | { action: 'track' | 'seek', value: number }
    | { action: 'legacyPreferences', settings: Partial<DisplaySettings>, locale: string | null }

interface HostServiceHandler {
  postMessage: (action: HostServiceAction) => void
}

type HostWindow = Window & {
  __AUGMA_DESKTOP_HOST_SERVICES__?: boolean
  __AUGMA_DESKTOP_HOST_STATE__?: unknown
  webkit?: { messageHandlers?: { hostServices?: HostServiceHandler } }
}

/** A flag alone cannot opt an ordinary browser into native ownership. */
export function desktopHostServices(): HostServiceHandler | undefined {
  const host = window as HostWindow
  const handler = host.webkit?.messageHandlers?.hostServices
  return host.__AUGMA_DESKTOP_HOST_SERVICES__ === true && typeof handler?.postMessage === 'function' ? handler : undefined
}

export function desktopHostState(): unknown {
  return (window as HostWindow).__AUGMA_DESKTOP_HOST_STATE__
}

export function hostRecord(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === 'object' && !Array.isArray(value)
}

const booleanSettings = ['dark', 'showHud', 'mirror', 'focus', 'depthMotion', 'sceneBackdrop', 'curvedHud', 'speechFeedback'] as const

/** Validate both imported preferences and host snapshots against the same narrow schema. */
export function validDisplaySettings(value: unknown): Partial<DisplaySettings> {
  const result: Partial<DisplaySettings> = {}
  if (!hostRecord(value))
    return result
  for (const key of booleanSettings) {
    if (typeof value[key] === 'boolean')
      result[key] = value[key]
  }
  for (const key of ['opacity', 'volume'] as const) {
    if (typeof value[key] === 'number' && Number.isFinite(value[key]))
      result[key] = Math.min(100, Math.max(key === 'opacity' ? 60 : 0, value[key]))
  }
  return result
}

// A shared scene can remount without resending legacy browser preferences to the host.
const imported = new WeakSet<HostServiceHandler>()
export function importLegacyPreferences(handler: HostServiceHandler, settings: Partial<DisplaySettings>, locale: string | null) {
  if (imported.has(handler))
    return
  imported.add(handler)
  handler.postMessage({ action: 'legacyPreferences', settings, locale })
}
