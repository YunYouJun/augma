import { afterEach, describe, expect, it } from 'vitest'
import { formatTime, locales, resolveLocale, setLocale, t } from '../../apps/ar/src/i18n/locale'
import { enUS } from '../../apps/ar/src/i18n/messages/en-US'
import { jaJP } from '../../apps/ar/src/i18n/messages/ja-JP'
import { zhCN } from '../../apps/ar/src/i18n/messages/zh-CN'

const placeholders = (text: string) => [...text.matchAll(/\{(\w+)\}/g)].map(match => match[1]).sort()

afterEach(() => {
  setLocale('zh-CN')
  localStorage.clear()
})

describe('aR i18n', () => {
  it.each([['en-US', enUS], ['ja-JP', jaJP]] as const)('keeps %s complete and placeholder-compatible with zh-CN', (_, catalog) => {
    for (const [key, source] of Object.entries(zhCN)) {
      const text = catalog[key as keyof typeof zhCN]
      expect(text, key).toBeTruthy()
      expect(placeholders(text), key).toEqual(placeholders(source))
    }
    expect(Object.keys(catalog).sort()).toEqual(Object.keys(zhCN).sort())
  })

  it('resolves browser and native language tags', () => {
    expect(resolveLocale('zh-Hans')).toBe('zh-CN')
    expect(resolveLocale('zh-TW')).toBe('zh-CN')
    expect(resolveLocale('en-GB')).toBe('en-US')
    expect(resolveLocale('ja')).toBe('ja-JP')
    expect(resolveLocale('fr-FR')).toBeNull()
    expect(resolveLocale(42)).toBeNull()
    expect(locales).toEqual(['zh-CN', 'en-US', 'ja-JP'])
  })

  it('translates nested messages lazily and remembers the choice', () => {
    const message = { key: 'result.routeStart', params: { name: { key: 'landmark.tree.name' } } } as const
    expect(t(message)).toBe('已开始前往中央绿洲的模拟导航')
    setLocale('en-US')
    expect(t(message)).toBe('Simulated navigation to Central Oasis started')
    expect(localStorage.getItem('augma-locale')).toBe('en-US')
    setLocale('ja-JP')
    expect(t('navigation.remaining', { distance: 42 })).toBe('残り 42 m · 模擬走行')
    expect(formatTime(new Date(2026, 9, 19, 9, 5))).toBe('09:05')
  })
})
