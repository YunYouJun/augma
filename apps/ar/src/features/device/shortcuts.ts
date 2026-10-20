import type { MessageKey } from '../../i18n/locale'

/** Actions the keyboard can trigger. App actions reuse their module id. */
export type ShortcutId = 'weather' | 'audio' | 'space' | 'camera' | 'navigation' | 'notifications' | 'settings' | 'device' | 'hud' | 'dark' | 'mirror' | 'focus' | 'fullscreen' | 'voice' | 'help'

/** A binding prepared for tooltips and `aria-keyshortcuts`. */
export interface ShortcutHint {
  label: string
  aria: string
}

export type ShortcutGroup = 'apps' | 'view' | 'voice' | 'general'

export const shortcutGroups: readonly { id: ShortcutGroup, actions: readonly ShortcutId[] }[] = [
  { id: 'apps', actions: ['weather', 'audio', 'space', 'camera', 'navigation', 'notifications', 'settings', 'device'] },
  { id: 'view', actions: ['hud', 'dark', 'mirror', 'focus', 'fullscreen'] },
  { id: 'voice', actions: ['voice'] },
  { id: 'general', actions: ['help'] },
]

export const shortcutIds: readonly ShortcutId[] = shortcutGroups.flatMap(group => group.actions)

export const shortcutLabels: Readonly<Record<ShortcutId, MessageKey>> = {
  weather: 'module.weather',
  audio: 'module.audio',
  space: 'module.space',
  camera: 'module.camera',
  navigation: 'module.navigation',
  notifications: 'module.notifications',
  settings: 'module.settings',
  device: 'module.device',
  hud: 'shortcuts.action.hud',
  dark: 'shortcuts.action.dark',
  mirror: 'shortcuts.action.mirror',
  focus: 'shortcuts.action.focus',
  fullscreen: 'shortcuts.action.fullscreen',
  voice: 'shortcuts.action.voice',
  help: 'shortcuts.action.help',
}

/**
 * Default bindings. Every default is a single key, at most with Shift: the page only acts on them while focus is
 * outside text fields, and browsers, operating systems and other apps' global hotkeys always add ⌘, Ctrl or Alt,
 * so the defaults cannot take a key from them.
 */
export const defaultShortcuts: Readonly<Record<ShortcutId, string | null>> = {
  weather: 'w',
  audio: 'a',
  space: 's',
  camera: 'c',
  navigation: 'n',
  notifications: 'Shift+n',
  settings: ',',
  device: null,
  hud: 'h',
  dark: 'd',
  mirror: 'm',
  focus: null,
  fullscreen: 'f',
  voice: 'v',
  help: '?',
}

export interface Chord {
  ctrl: boolean
  alt: boolean
  shift: boolean
  meta: boolean
  /** A lowercase letter, digit, ASCII symbol, `Space`, or a named key such as `F2` or `Enter`. */
  key: string
}

/** Why a chord cannot be bound, or what it may collide with outside the page. */
export type ShortcutIssue
  = | { level: 'blocked', reason: 'unsupported' | 'page' | 'reserved' | 'ime' }
    | { level: 'warning', reason: 'screenshot' | 'launcher' | 'assistive' }

const modifierKeys = new Set(['Shift', 'Control', 'Alt', 'AltGraph', 'Meta', 'OS', 'Super', 'Hyper', 'Fn', 'FnLock', 'CapsLock', 'NumLock', 'ScrollLock', 'Symbol', 'SymbolLock'])
const symbolCodes: Record<string, string> = { Comma: ',', Period: '.', Slash: '/', Semicolon: ';', Quote: '\'', BracketLeft: '[', BracketRight: ']', Backslash: '\\', Minus: '-', Equal: '=', Backquote: '`' }
/** Keys that move focus, scroll, edit or operate the focused control. */
const pageKeys = new Set(['Tab', 'Enter', 'Escape', 'Backspace', 'Delete', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Home', 'End', 'PageUp', 'PageDown'])
/** Help, find next, reload, address bar, caret browsing, the notification region (F8), menu bar, full screen, developer tools. */
const reservedFunctionKeys = new Set(['F1', 'F3', 'F5', 'F6', 'F7', 'F8', 'F10', 'F11', 'F12'])

interface PlatformRules {
  ime: ReadonlySet<string>
  reserved: ReadonlySet<string>
  warnings: ReadonlyMap<string, 'screenshot' | 'launcher'>
}

const macRules: PlatformRules = {
  // Switch input source.
  ime: new Set(['Ctrl+Space', 'Ctrl+Alt+Space']),
  reserved: new Set([
    // Browser: developer tools, view source, find, downloads, bookmarks, cache, reload, new and close windows.
    ...'ijcufldbertnwv'.split('').map(key => `Alt+Meta+${key}`),
    // System: hide others, Dock, minimize all, force quit, paste and match style.
    'Alt+Meta+h',
    'Alt+Meta+d',
    'Alt+Meta+m',
    'Alt+Shift+Meta+v',
    // System: full screen, lock screen, look up, emoji and symbols.
    'Ctrl+Meta+f',
    'Ctrl+Meta+q',
    'Ctrl+Meta+d',
    'Ctrl+Meta+Space',
  ]),
  warnings: new Map([
    // WeChat and QQ screenshots.
    ['Ctrl+Meta+a', 'screenshot'],
    // Alfred, Raycast and the ChatGPT app.
    ['Alt+Space', 'launcher'],
  ]),
}

const otherRules: PlatformRules = {
  // Toggle the input method, full or half width, Chinese punctuation, simplified or traditional characters.
  ime: new Set(['Ctrl+Space', 'Shift+Space', 'Ctrl+.', 'Ctrl+Shift+f']),
  reserved: new Set([
    // Browser menus and address bar.
    ...'fedvsbth'.split('').map(key => `Alt+${key}`),
    // Window menu, close window.
    'Alt+Space',
    'Alt+F4',
    // Linux desktops: terminal, lock screen, show desktop.
    'Ctrl+Alt+t',
    'Ctrl+Alt+l',
    'Ctrl+Alt+d',
  ]),
  warnings: new Map([
    // WeChat and QQ screenshots.
    ['Alt+a', 'screenshot'],
    ['Ctrl+Alt+a', 'screenshot'],
  ]),
}

// The key is one character or a named key such as `F2`, so `Shift+Ctrl+k` does not parse as Shift with `Ctrl+k`.
const chordPattern = /^(Ctrl\+)?(Alt\+)?(Shift\+)?(Meta\+)?(.|[A-Z][\dA-Z]*)$/i

/** @returns The canonical text form, modifiers in the order Ctrl, Alt, Shift, Meta. */
export function stringifyChord(chord: Chord): string {
  return [chord.ctrl && 'Ctrl', chord.alt && 'Alt', chord.shift && 'Shift', chord.meta && 'Meta', chord.key].filter(Boolean).join('+')
}

/** @returns The chord, or `null` when the text is not in canonical form */
export function parseChord(value: unknown): Chord | null {
  if (typeof value !== 'string')
    return null
  const match = chordPattern.exec(value)
  if (!match)
    return null
  const chord = { ctrl: !!match[1], alt: !!match[2], shift: !!match[3], meta: !!match[4], key: match[5] }
  return stringifyChord(chord) === value ? chord : null
}

function isBindableKey(key: string) {
  return /^[a-z0-9]$/.test(key) || /^[\x21-\x2F\x3A-\x40\x5B-\x60\x7B-\x7E]$/.test(key) || key === 'Space' || /^F(?:[1-9]|1\d|2[0-4])$/.test(key)
}

/**
 * Read the chord a key press produces.
 *
 * Letters, digits and ASCII symbols use the character typed, so `?` works on any layout. Other layouts and macOS
 * Option produce other characters; those fall back to the physical key, so `W` still works with a Russian layout.
 * Shift is kept for letters and named keys; for symbols the character already reflects it.
 *
 * @returns The canonical chord, or `null` for a modifier on its own, an input method composition or an unknown key
 */
export function chordFromEvent(event: Pick<KeyboardEvent, 'key' | 'code' | 'ctrlKey' | 'altKey' | 'shiftKey' | 'metaKey' | 'isComposing' | 'keyCode'>): string | null {
  const { key, code } = event
  if (event.isComposing || event.keyCode === 229 || !key || key === 'Process' || key === 'Unidentified' || modifierKeys.has(key))
    return null
  let base: string | null = null
  let symbol = false
  if (key.length === 1 && /^[a-z]$/i.test(key)) {
    base = key.toLowerCase()
  }
  else if (key.length === 1 && /^[\x21-\x7E]$/.test(key)) {
    base = key
    symbol = true
  }
  else if (/^Key[A-Z]$/.test(code)) {
    base = code.slice(3).toLowerCase()
  }
  else if (/^Digit\d$/.test(code)) {
    base = code.slice(5)
  }
  else if (symbolCodes[code]) {
    base = symbolCodes[code]
  }
  else if (key === ' ') {
    base = 'Space'
  }
  else if (key.length > 1 && key !== 'Dead') {
    base = key
  }
  if (!base)
    return null
  return stringifyChord({ ctrl: event.ctrlKey, alt: event.altKey, shift: event.shiftKey && !symbol, meta: event.metaKey, key: base })
}

/**
 * Check a chord against browser, system, input method and page keys, and against common global hotkeys.
 *
 * Blocked chords either never reach the page or would take a key the user relies on. Warnings are allowed: the
 * page still receives them unless the named kind of app is installed and running.
 *
 * @param value - A canonical chord
 * @param mac - Whether to apply the macOS rules (⌘ as the primary modifier) instead of Windows and Linux rules
 */
export function checkChord(value: string, mac: boolean): ShortcutIssue | null {
  const chord = parseChord(value)
  if (!chord)
    return { level: 'blocked', reason: 'unsupported' }
  const rules = mac ? macRules : otherRules
  if (rules.ime.has(value))
    return { level: 'blocked', reason: 'ime' }
  if (rules.reserved.has(value))
    return { level: 'blocked', reason: 'reserved' }
  const modified = chord.ctrl || chord.alt || chord.meta
  if (pageKeys.has(chord.key) || (chord.key === 'Space' && !modified))
    return { level: 'blocked', reason: 'page' }
  if (!isBindableKey(chord.key))
    return { level: 'blocked', reason: 'unsupported' }
  if (reservedFunctionKeys.has(chord.key))
    return { level: 'blocked', reason: 'reserved' }
  // ⌘ or Ctrl with a key, with or without Shift, belongs to the browser, the system or text editing.
  const primary = mac ? chord.meta : chord.ctrl
  const secondary = mac ? chord.ctrl : chord.meta
  if (primary && !chord.alt && !secondary)
    return { level: 'blocked', reason: 'reserved' }
  // The Windows or Super key belongs to the desktop.
  if (!mac && chord.meta)
    return { level: 'blocked', reason: 'reserved' }
  const warning = rules.warnings.get(value)
  if (warning)
    return { level: 'warning', reason: warning }
  // ⌃⌥ is VoiceOver's modifier, and window managers such as Rectangle use it too.
  if (mac && chord.ctrl && chord.alt && !chord.meta)
    return { level: 'warning', reason: 'assistive' }
  return null
}

const macSymbols = { ctrl: '⌃', alt: '⌥', shift: '⇧', meta: '⌘' } as const
const otherNames = { ctrl: 'Ctrl', alt: 'Alt', shift: 'Shift', meta: 'Win' } as const

/**
 * Split a chord into keycaps for display, in each platform's usual modifier order.
 *
 * @example
 * ```ts
 * formatChord('Shift+n', true) // ['⇧', 'N']
 * formatChord('Ctrl+Alt+a', false) // ['Ctrl', 'Alt', 'A']
 * ```
 */
export function formatChord(value: string, mac: boolean): string[] {
  const chord = parseChord(value)
  if (!chord)
    return []
  const names = mac ? macSymbols : otherNames
  const keys = (['ctrl', 'alt', 'shift', 'meta'] as const).filter(modifier => chord[modifier]).map(modifier => names[modifier])
  return [...keys, chord.key.length === 1 ? chord.key.toUpperCase() : chord.key]
}

/** @returns The chord as one string, such as `⇧N` on macOS or `Shift+N` elsewhere */
export function chordLabel(value: string, mac: boolean): string {
  return formatChord(value, mac).join(mac ? '' : '+')
}

/** @returns The chord in `aria-keyshortcuts` syntax, such as `Shift+N` */
export function ariaChord(value: string): string {
  const chord = parseChord(value)
  if (!chord)
    return ''
  const key = chord.key === 'Space' ? 'Space' : chord.key.length === 1 ? chord.key.toUpperCase() : chord.key
  return [chord.ctrl && 'Control', chord.alt && 'Alt', chord.shift && 'Shift', chord.meta && 'Meta', key].filter(Boolean).join('+')
}

/** @returns Whether the browser runs on macOS or iPadOS, where ⌘ is the primary modifier */
export function isMacPlatform(nav: Pick<Navigator, 'platform' | 'userAgent'> & { userAgentData?: { platform?: string } } = navigator): boolean {
  return /mac|iphone|ipad|ipod/i.test(nav.userAgentData?.platform || nav.platform || nav.userAgent)
}

const textEntry = [
  `input${['checkbox', 'radio', 'button', 'submit', 'reset', 'range', 'color', 'file'].map(type => `:not([type=${type}])`).join('')}`,
  'textarea',
  'select',
  '[contenteditable]:not([contenteditable=false])',
  // Widgets that type to search or take letter keys themselves, and modal dialogs.
  ...['textbox', 'searchbox', 'combobox', 'listbox', 'option', 'menu', 'menubar', 'menuitem', 'menuitemcheckbox', 'menuitemradio', 'spinbutton', 'grid', 'tree', 'treegrid', 'dialog', 'alertdialog'].map(role => `[role=${role}]`),
].join(', ')

/** @returns Whether a key press on this element may run a page shortcut instead of reaching the control */
export function acceptsShortcut(target: EventTarget | null): boolean {
  return !(target instanceof Element) || !target.closest(textEntry)
}
