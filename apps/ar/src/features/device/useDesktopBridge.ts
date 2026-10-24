import type { Ref } from 'vue'
import type { DeviceModule } from './types'
import { onMounted, onUnmounted, readonly, shallowRef, watch } from 'vue'
import { desktopHostServices } from './hostServices'
import { parseChord } from './shortcuts'
import { deviceModules } from './types'

type DesktopWindow = Window & {
  __AUGMA_DESKTOP_MODULE__?: DeviceModule
  __AUGMA_DESKTOP_IMMERSIVE__?: boolean
  /** The macOS app's voice menu key as a chord, `null` when the menu item has no key. */
  __AUGMA_DESKTOP_VOICE_SHORTCUT__?: string | null
  webkit?: { messageHandlers?: { moduleSelection?: { postMessage: (module: DeviceModule | null) => void } } }
}

interface DesktopBridgeOptions {
  /** The open app, reported back to the macOS menu as it changes. */
  activeModule: Ref<DeviceModule | null>
  /** Opens the app the macOS menu picked, or closes the open one for `null`. */
  select: (module: DeviceModule | null) => void
  /** Runs the voice menu item. */
  toggleSpeech: () => void
}

const nativeChord = (value: unknown) => typeof value === 'string' && parseChord(value) ? value : null

/**
 * Talks to the macOS app that hosts this page in a WKWebView. In a plain browser nothing arrives and nothing is sent.
 *
 * @returns Whether the page runs as the immersive overlay, and the voice menu item's current key
 */
export function useDesktopBridge({ activeModule, select, toggleSpeech }: DesktopBridgeOptions) {
  const desktopWindow = window as DesktopWindow
  const immersive = shallowRef(desktopWindow.__AUGMA_DESKTOP_IMMERSIVE__ === true)
  const nativePresentation = !!desktopHostServices() || typeof desktopWindow.__AUGMA_DESKTOP_IMMERSIVE__ === 'boolean'
  /** Follows the menu item, which the user can rebind under App Shortcuts in System Settings. */
  const voiceShortcut = shallowRef(nativeChord(desktopWindow.__AUGMA_DESKTOP_VOICE_SHORTCUT__))

  function selectModule(module: unknown) {
    if (module === null)
      select(null)
    else if (typeof module === 'string' && deviceModules.includes(module as DeviceModule))
      select(module as DeviceModule)
  }

  function onSelectModule(event: Event) {
    selectModule((event as CustomEvent<{ module?: unknown }>).detail?.module)
  }

  function onVoiceShortcut(event: Event) {
    voiceShortcut.value = nativeChord((event as CustomEvent<{ shortcut?: unknown }>).detail?.shortcut)
  }

  function onPresentation(event: Event) {
    const detail: unknown = (event as CustomEvent).detail
    if (!nativePresentation || !detail || typeof detail !== 'object' || !('immersive' in detail) || typeof detail.immersive !== 'boolean')
      return
    immersive.value = detail.immersive
    document.documentElement.classList.toggle('augma-desktop-immersive', detail.immersive)
  }

  watch(activeModule, (module) => {
    desktopWindow.webkit?.messageHandlers?.moduleSelection?.postMessage(module)
  })
  onMounted(() => {
    if (immersive.value)
      document.documentElement.classList.add('augma-desktop-immersive')
    window.addEventListener('augma:select-module', onSelectModule)
    window.addEventListener('augma:toggle-speech', toggleSpeech)
    window.addEventListener('augma:voice-shortcut', onVoiceShortcut)
    window.addEventListener('augma:presentation', onPresentation)
    if (desktopWindow.__AUGMA_DESKTOP_MODULE__)
      selectModule(desktopWindow.__AUGMA_DESKTOP_MODULE__)
  })
  onUnmounted(() => {
    if (immersive.value)
      document.documentElement.classList.remove('augma-desktop-immersive')
    window.removeEventListener('augma:select-module', onSelectModule)
    window.removeEventListener('augma:toggle-speech', toggleSpeech)
    window.removeEventListener('augma:voice-shortcut', onVoiceShortcut)
    window.removeEventListener('augma:presentation', onPresentation)
  })

  return { immersive: readonly(immersive), voiceShortcut }
}
