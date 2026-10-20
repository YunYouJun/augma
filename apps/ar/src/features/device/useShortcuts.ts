import type { ShortcutId } from './shortcuts'
import { computed, onMounted, onUnmounted, shallowRef } from 'vue'
import { acceptsShortcut, checkChord, chordFromEvent, defaultShortcuts, isMacPlatform, shortcutIds } from './shortcuts'

export const shortcutsKey = 'augma-shortcuts-v1'

type Overrides = Partial<Record<ShortcutId, string | null>>

interface UseShortcutsOptions {
  run: (id: ShortcutId) => void
  /** Actions the current browser cannot perform keep their binding but are skipped. */
  available?: (id: ShortcutId) => boolean
  /** Escape outside any control; return `true` when it closed something. Runs even with shortcuts turned off. */
  escape?: () => boolean
  mac?: boolean
}

/**
 * Keyboard shortcuts for the device, with bindings the user can change and turn off, kept in this browser.
 *
 * Only the user's changes are stored, so later releases can add actions and adjust defaults. Stored chords that are
 * malformed, or blocked on this platform, are ignored.
 *
 * @returns The current `bindings` and `enabled` state, with `assign`, `reset` and `resetAll`
 */
export function useShortcuts(options: UseShortcutsOptions) {
  const mac = options.mac ?? isMacPlatform()
  const enabled = shallowRef(true)
  const overrides = shallowRef<Overrides>({})
  const storageAvailable = shallowRef(true)

  try {
    const saved: unknown = JSON.parse(localStorage.getItem(shortcutsKey) || 'null')
    if (saved && typeof saved === 'object') {
      const data = saved as { enabled?: unknown, bindings?: unknown }
      if (typeof data.enabled === 'boolean')
        enabled.value = data.enabled
      if (data.bindings && typeof data.bindings === 'object') {
        const stored = data.bindings as Record<string, unknown>
        const next: Overrides = {}
        for (const id of shortcutIds) {
          const value = stored[id]
          if (value === null || (typeof value === 'string' && checkChord(value, mac)?.level !== 'blocked'))
            next[id] = value
        }
        overrides.value = next
      }
    }
  }
  catch {
    storageAvailable.value = false
  }

  /** Each action's chord. A changed binding wins over another action's default for the same chord. */
  const bindings = computed(() => {
    const result = {} as Record<ShortcutId, string | null>
    const taken = new Set<string>()
    for (const id of shortcutIds) {
      const value = overrides.value[id]
      if (value !== undefined) {
        result[id] = value && !taken.has(value) ? value : null
        if (value)
          taken.add(value)
      }
    }
    for (const id of shortcutIds) {
      if (overrides.value[id] !== undefined)
        continue
      const value = defaultShortcuts[id]
      result[id] = value && !taken.has(value) ? value : null
      if (value)
        taken.add(value)
    }
    return result
  })
  const actions = computed(() => new Map(shortcutIds.flatMap(id => bindings.value[id] ? [[bindings.value[id], id] as const] : [])))

  function persist() {
    try {
      if (enabled.value && !Object.keys(overrides.value).length)
        localStorage.removeItem(shortcutsKey)
      else
        localStorage.setItem(shortcutsKey, JSON.stringify({ enabled: enabled.value, bindings: overrides.value }))
      storageAvailable.value = true
    }
    catch {
      storageAvailable.value = false
    }
  }

  function setEnabled(value: boolean) {
    enabled.value = value
    persist()
  }

  /** @returns The action that already uses `chord`, other than `id` */
  function owner(chord: string, id?: ShortcutId): ShortcutId | null {
    const current = actions.value.get(chord)
    return current && current !== id ? current : null
  }

  /**
   * Bind `chord` to `id`, taking it from any other action, or clear the binding with `null`.
   *
   * @returns `false` when the chord is blocked on this platform
   */
  function assign(id: ShortcutId, chord: string | null): boolean {
    if (chord && checkChord(chord, mac)?.level === 'blocked')
      return false
    const next = { ...overrides.value }
    const previous = chord && owner(chord, id)
    if (previous)
      next[previous] = null
    if (chord === defaultShortcuts[id])
      delete next[id]
    else
      next[id] = chord
    overrides.value = next
    persist()
    return true
  }

  /** Restore the default binding of `id`, taking it back from another action if needed. */
  function reset(id: ShortcutId) {
    assign(id, defaultShortcuts[id])
  }

  function resetAll() {
    overrides.value = {}
    enabled.value = true
    persist()
  }

  function onKeyDown(event: KeyboardEvent) {
    if (event.defaultPrevented || !acceptsShortcut(event.target))
      return
    if (event.key === 'Escape') {
      if (!event.ctrlKey && !event.altKey && !event.metaKey && !event.shiftKey && options.escape?.())
        event.preventDefault()
      return
    }
    if (!enabled.value)
      return
    const chord = chordFromEvent(event)
    const id = chord && actions.value.get(chord)
    if (!id || options.available?.(id) === false)
      return
    // Also stops Firefox's quick find on `/` and `'`.
    event.preventDefault()
    if (!event.repeat)
      options.run(id)
  }

  onMounted(() => window.addEventListener('keydown', onKeyDown))
  onUnmounted(() => window.removeEventListener('keydown', onKeyDown))

  return {
    mac,
    enabled: computed(() => enabled.value),
    bindings,
    storageAvailable,
    customized: (id: ShortcutId) => overrides.value[id] !== undefined,
    owner,
    setEnabled,
    assign,
    reset,
    resetAll,
  }
}
