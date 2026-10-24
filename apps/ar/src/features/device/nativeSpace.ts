type SpaceAction = 'scene' | 'landmark' | 'scan' | 'cancelScan' | 'pin' | 'routeStart' | 'routeNext' | 'routeStop' | 'resetView'

type SpaceWindow = Window & {
  __AUGMA_DESKTOP_NATIVE_SPACE__?: boolean
  webkit?: { messageHandlers?: { nativeSpace?: { postMessage: (body: { action: SpaceAction, value?: unknown }) => void } } }
}

/** A small compatibility boundary: desktop space has no webpage state machine. */
export function desktopNativeSpace() {
  const host = window as SpaceWindow
  const bridge = host.webkit?.messageHandlers?.nativeSpace
  if (host.__AUGMA_DESKTOP_NATIVE_SPACE__ !== true || !bridge)
    return null
  const actions = new Set<string>(['scene', 'landmark', 'scan', 'cancelScan', 'pin', 'routeStart', 'routeNext', 'routeStop', 'resetView'])
  return {
    request(action: string, value?: unknown) {
      if (!actions.has(action))
        return false
      if (action === 'scene' && value !== 'garden' && value !== 'city')
        return false
      if (action === 'landmark' && (typeof value !== 'string' || !['terrace', 'pavilion', 'tree', 'gallery', 'station', 'square'].includes(value)))
        return false
      bridge.postMessage({ action: action as SpaceAction, ...(value === undefined ? {} : { value }) })
      return true
    },
  }
}
