import type { MessageKey, Messages } from './messages/zh-CN'
import { readonly, shallowRef } from 'vue'
import { enUS } from './messages/en-US'
import { jaJP } from './messages/ja-JP'
import { zhCN } from './messages/zh-CN'

export type { MessageKey } from './messages/zh-CN'

/** BCP 47 tags of the languages the AR simulator ships with. */
export const locales = ['zh-CN', 'en-US', 'ja-JP'] as const

/** A supported UI language; also used for speech recognition, speech synthesis and date formatting. */
export type Locale = typeof locales[number]

/** Language names in their own script, for the language picker. */
export const localeNames: Record<Locale, string> = { 'zh-CN': '简体中文', 'en-US': 'English', 'ja-JP': '日本語' }

/** Values interpolated into `{name}` placeholders; nested messages are translated lazily. */
export type MessageParams = Record<string, string | number | Message>

/** A translatable message kept as data, so stored text follows later language changes. */
export interface Message {
  key: MessageKey
  params?: MessageParams
}

export const localeKey = 'augma-locale'
const catalogs: Record<Locale, Messages> = { 'zh-CN': zhCN, 'en-US': enUS, 'ja-JP': jaJP }

/**
 * Map a language tag such as `ja`, `en-GB` or `zh-Hans` to a supported locale.
 *
 * @param value - Any language tag; non-strings are ignored
 * @returns The matching locale, or `null` when the language is not supported
 */
export function resolveLocale(value: unknown): Locale | null {
  if (typeof value !== 'string')
    return null
  const tag = value.toLowerCase()
  if (tag.startsWith('zh'))
    return 'zh-CN'
  if (tag.startsWith('ja'))
    return 'ja-JP'
  if (tag.startsWith('en'))
    return 'en-US'
  return null
}

function detectLocale(): Locale {
  try {
    const saved = resolveLocale(localStorage.getItem(localeKey))
    if (saved)
      return saved
  }
  catch {}
  // The macOS app injects its own UI language so the embedded page matches the native menus.
  const desktop = resolveLocale((window as Window & { __AUGMA_DESKTOP_LOCALE__?: unknown }).__AUGMA_DESKTOP_LOCALE__)
  if (desktop)
    return desktop
  for (const language of navigator.languages ?? [navigator.language]) {
    const match = resolveLocale(language)
    if (match)
      return match
  }
  return 'en-US'
}

const current = shallowRef<Locale>(detectLocale())

/** The active UI language. Change it with {@link setLocale}. */
export const locale = readonly(current)

/**
 * Switch the UI language and remember the choice in this browser.
 *
 * @param next - The locale to activate
 * @returns `true` when the choice was saved, `false` when storage is unavailable
 */
export function setLocale(next: Locale): boolean {
  current.value = next
  try {
    localStorage.setItem(localeKey, next)
    return true
  }
  catch {
    return false
  }
}

/**
 * Translate a message into the active locale. Reading `locale` here makes callers reactive.
 *
 * @param input - A message key, or a stored {@link Message}
 * @param params - Placeholder values when `input` is a key
 * @returns The translated text with placeholders filled in
 *
 * @example
 * ```ts
 * t('world.select', { name: { key: 'landmark.tree.name' } }) // "选择中央绿洲"
 * ```
 */
export function t(input: MessageKey | Message, params?: MessageParams): string {
  const message = typeof input === 'string' ? { key: input, params } : input
  return catalogs[current.value][message.key].replace(/\{(\w+)\}/g, (placeholder, name: string) => {
    const value = message.params?.[name]
    if (value === undefined)
      return placeholder
    return typeof value === 'object' ? t(value) : String(value)
  })
}

/**
 * Format a clock time for the HUD. The HUD always uses a 24-hour clock to keep its width stable.
 *
 * @param value - A date or timestamp
 * @returns The localized `HH:mm` time
 */
export function formatTime(value: Date | number): string {
  return new Date(value).toLocaleTimeString(current.value, { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' })
}
