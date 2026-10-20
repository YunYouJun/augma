import { mount } from '@vue/test-utils'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { defineComponent, h } from 'vue'
import { acceptsShortcut, ariaChord, checkChord, chordFromEvent, chordLabel, defaultShortcuts, formatChord, isMacPlatform, parseChord, shortcutIds } from '../../apps/ar/src/features/device/shortcuts'
import { shortcutsKey, useShortcuts } from '../../apps/ar/src/features/device/useShortcuts'

function press(key: string, init: Partial<KeyboardEventInit & { keyCode: number }> = {}) {
  return { key, code: '', ctrlKey: false, altKey: false, shiftKey: false, metaKey: false, isComposing: false, keyCode: 0, ...init }
}

const cleanups: (() => void)[] = []
function setup<T>(composable: () => T) {
  let result!: T
  const wrapper = mount(defineComponent({
    setup() {
      result = composable()
      return () => h('div')
    },
  }), { attachTo: document.body })
  cleanups.push(() => wrapper.unmount())
  return result
}
function keydown(key: string, init: KeyboardEventInit = {}, target: EventTarget = document.body) {
  const event = new KeyboardEvent('keydown', { key, bubbles: true, cancelable: true, ...init })
  target.dispatchEvent(event)
  return event
}

afterEach(() => {
  cleanups.splice(0).forEach(cleanup => cleanup())
  document.body.innerHTML = ''
  localStorage.clear()
})

describe('shortcut chords', () => {
  it('reads letters, symbols and layouts the same way people type them', () => {
    expect(chordFromEvent(press('w', { code: 'KeyW' }))).toBe('w')
    expect(chordFromEvent(press('N', { code: 'KeyN', shiftKey: true }))).toBe('Shift+n')
    // The character already reflects Shift, so `?` matches on US, German and JIS layouts alike.
    expect(chordFromEvent(press('?', { code: 'Slash', shiftKey: true }))).toBe('?')
    expect(chordFromEvent(press(',', { code: 'Comma' }))).toBe(',')
    // A Russian layout and macOS Option fall back to the physical key.
    expect(chordFromEvent(press('ц', { code: 'KeyW' }))).toBe('w')
    expect(chordFromEvent(press('∑', { code: 'KeyW', altKey: true }))).toBe('Alt+w')
    expect(chordFromEvent(press('≤', { code: 'Comma', altKey: true }))).toBe('Alt+,')
    expect(chordFromEvent(press('Dead', { code: 'KeyE', altKey: true }))).toBe('Alt+e')
    expect(chordFromEvent(press(' ', { code: 'Space', altKey: true }))).toBe('Alt+Space')
    expect(chordFromEvent(press('a', { code: 'KeyA', ctrlKey: true, metaKey: true }))).toBe('Ctrl+Meta+a')
    expect(chordFromEvent(press('F2', { code: 'F2' }))).toBe('F2')
  })

  it('ignores modifiers on their own and input method composition', () => {
    expect(chordFromEvent(press('Shift', { code: 'ShiftLeft', shiftKey: true }))).toBeNull()
    expect(chordFromEvent(press('Meta', { code: 'MetaLeft', metaKey: true }))).toBeNull()
    expect(chordFromEvent(press('Process', { code: 'KeyW', keyCode: 229 }))).toBeNull()
    expect(chordFromEvent(press('w', { code: 'KeyW', isComposing: true }))).toBeNull()
  })

  it('round-trips only canonical text', () => {
    expect(parseChord('Ctrl+Alt+Shift+Meta+k')).toEqual({ ctrl: true, alt: true, shift: true, meta: true, key: 'k' })
    expect(parseChord('Ctrl++')).toEqual({ ctrl: true, alt: false, shift: false, meta: false, key: '+' })
    expect(parseChord('Shift+Ctrl+k')).toBeNull()
    expect(parseChord(42)).toBeNull()
  })

  it('formats keycaps for each platform and for assistive technology', () => {
    expect(formatChord('Shift+n', true)).toEqual(['⇧', 'N'])
    expect(formatChord('Ctrl+Alt+Shift+Meta+k', true)).toEqual(['⌃', '⌥', '⇧', '⌘', 'K'])
    expect(chordLabel('Shift+n', false)).toBe('Shift+N')
    expect(chordLabel('Ctrl+Alt+a', false)).toBe('Ctrl+Alt+A')
    expect(chordLabel(',', true)).toBe(',')
    expect(ariaChord('Ctrl+Alt+a')).toBe('Control+Alt+A')
    expect(ariaChord('?')).toBe('?')
  })

  it('detects macOS and iPadOS', () => {
    expect(isMacPlatform({ platform: 'MacIntel', userAgent: '' })).toBe(true)
    expect(isMacPlatform({ platform: '', userAgent: '', userAgentData: { platform: 'macOS' } })).toBe(true)
    expect(isMacPlatform({ platform: 'Win32', userAgent: '' })).toBe(false)
    expect(isMacPlatform({ platform: 'Linux x86_64', userAgent: '' })).toBe(false)
  })
})

describe('shortcut conflicts', () => {
  it('keeps every default free of conflicts on every platform', () => {
    const chords = Object.values(defaultShortcuts).filter(Boolean)
    expect(new Set(chords).size).toBe(chords.length)
    for (const chord of chords) {
      expect(checkChord(chord!, true), chord!).toBeNull()
      expect(checkChord(chord!, false), chord!).toBeNull()
    }
    expect(shortcutIds).toEqual(Object.keys(defaultShortcuts))
  })

  it.each([
    ['Meta+w', true, 'reserved'],
    ['Shift+Meta+v', true, 'reserved'],
    ['Shift+Meta+4', true, 'reserved'],
    ['Alt+Meta+i', true, 'reserved'],
    ['Ctrl+Meta+q', true, 'reserved'],
    ['Ctrl+Space', true, 'ime'],
    ['Ctrl+w', false, 'reserved'],
    ['Ctrl+Shift+t', false, 'reserved'],
    ['Meta+d', false, 'reserved'],
    ['Alt+f', false, 'reserved'],
    ['Alt+Space', false, 'reserved'],
    ['Ctrl+Space', false, 'ime'],
    ['Ctrl+.', false, 'ime'],
    ['Ctrl+Shift+f', false, 'ime'],
    ['Shift+Space', false, 'ime'],
    ['Enter', true, 'page'],
    ['Shift+Tab', false, 'page'],
    ['Alt+ArrowLeft', false, 'page'],
    ['Space', true, 'page'],
    ['F5', false, 'reserved'],
    ['Shift+F12', true, 'reserved'],
    ['MediaPlayPause', true, 'unsupported'],
    ['Shift+Ctrl+k', true, 'unsupported'],
  ] as const)('blocks %s (mac: %s) as %s', (chord, mac, reason) => {
    expect(checkChord(chord, mac)).toEqual({ level: 'blocked', reason })
  })

  it.each([
    ['Ctrl+Meta+a', true, 'screenshot'],
    ['Alt+a', false, 'screenshot'],
    ['Ctrl+Alt+a', false, 'screenshot'],
    ['Alt+Space', true, 'launcher'],
    ['Ctrl+Alt+k', true, 'assistive'],
  ] as const)('warns about %s (mac: %s) as %s', (chord, mac, reason) => {
    expect(checkChord(chord, mac)).toEqual({ level: 'warning', reason })
  })

  it.each([
    ['k', true],
    ['Shift+k', false],
    ['F2', true],
    ['Alt+k', true],
    ['Alt+Meta+k', true],
    ['Ctrl+Alt+k', false],
    ['Ctrl+k', true],
  ] as const)('accepts %s (mac: %s)', (chord, mac) => {
    expect(checkChord(chord, mac)).toBeNull()
  })

  it('leaves text fields, typeahead widgets and dialogs alone', () => {
    document.body.innerHTML = `
      <input id="text"><input id="check" type="checkbox"><textarea id="area"></textarea><select id="select"></select>
      <div id="editable" contenteditable></div><button id="combo" role="combobox"></button>
      <div role="dialog"><button id="inside"></button></div><button id="plain"></button>`
    const byId = (id: string) => document.getElementById(id)
    for (const id of ['text', 'area', 'select', 'editable', 'combo', 'inside'])
      expect(acceptsShortcut(byId(id)), id).toBe(false)
    for (const id of ['check', 'plain'])
      expect(acceptsShortcut(byId(id)), id).toBe(true)
    expect(acceptsShortcut(document.body)).toBe(true)
  })
})

describe('shortcut bindings', () => {
  it('runs bound actions outside text fields and skips repeats', () => {
    const run = vi.fn()
    setup(() => useShortcuts({ run, mac: false }))
    expect(keydown('w').defaultPrevented).toBe(true)
    keydown('N', { shiftKey: true })
    keydown('w', { repeat: true })
    keydown('w', { ctrlKey: true })
    const input = document.body.appendChild(document.createElement('input'))
    keydown('w', {}, input)
    expect(run.mock.calls).toEqual([['weather'], ['notifications']])
  })

  it('turns off character shortcuts but keeps Escape', () => {
    const run = vi.fn()
    const escape = vi.fn(() => true)
    const shortcuts = setup(() => useShortcuts({ run, escape, mac: false }))
    shortcuts.setEnabled(false)
    keydown('w')
    expect(keydown('Escape').defaultPrevented).toBe(true)
    expect(run).not.toHaveBeenCalled()
    expect(escape).toHaveBeenCalledOnce()
    expect(JSON.parse(localStorage.getItem(shortcutsKey)!)).toEqual({ enabled: false, bindings: {} })
  })

  it('skips actions the browser cannot perform', () => {
    const run = vi.fn()
    setup(() => useShortcuts({ run, available: id => id !== 'fullscreen', mac: false }))
    expect(keydown('f').defaultPrevented).toBe(false)
    expect(run).not.toHaveBeenCalled()
  })

  it('moves a chord between actions, stores only changes and restores defaults', () => {
    const run = vi.fn()
    const shortcuts = setup(() => useShortcuts({ run, mac: true }))
    expect(shortcuts.assign('weather', 'Meta+w')).toBe(false)
    expect(shortcuts.assign('weather', 'd')).toBe(true)
    expect(shortcuts.bindings.value.weather).toBe('d')
    expect(shortcuts.bindings.value.dark).toBeNull()
    expect(shortcuts.customized('dark')).toBe(true)
    keydown('d')
    keydown('w')
    expect(run.mock.calls).toEqual([['weather']])
    expect(JSON.parse(localStorage.getItem(shortcutsKey)!)).toEqual({ enabled: true, bindings: { weather: 'd', dark: null } })

    shortcuts.reset('dark')
    expect(shortcuts.bindings.value.dark).toBe('d')
    expect(shortcuts.bindings.value.weather).toBeNull()
    shortcuts.resetAll()
    expect(shortcuts.bindings.value).toEqual(defaultShortcuts)
    expect(localStorage.getItem(shortcutsKey)).toBeNull()
  })

  it('ignores malformed, unknown and blocked stored bindings', () => {
    localStorage.setItem(shortcutsKey, JSON.stringify({ enabled: 'no', bindings: { weather: 'Ctrl+w', audio: 'Shift+Ctrl+k', space: 7, unknown: 'q', camera: 'x', dark: 'x', device: 'Alt+k' } }))
    const shortcuts = setup(() => useShortcuts({ run: vi.fn(), mac: false }))
    expect(shortcuts.enabled.value).toBe(true)
    expect(shortcuts.bindings.value).toMatchObject({ weather: 'w', audio: 'a', space: 's', camera: 'x', dark: null, device: 'Alt+k' })
  })
})
