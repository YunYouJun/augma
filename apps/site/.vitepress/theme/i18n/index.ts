import type { MessageKey, Messages } from './zh-CN'
import { useData } from 'vitepress'
import { computed } from 'vue'
import { enUS } from './en-US'
import { jaJP } from './ja-JP'
import { zhCN } from './zh-CN'

/** Docs languages by VitePress locale index. The tags match the AR demo's locales. */
export const siteLocales = { root: 'zh-CN', en: 'en-US', ja: 'ja-JP' } as const

export type SiteLocale = typeof siteLocales[keyof typeof siteLocales]

const catalogs: Record<SiteLocale, Messages> = { 'zh-CN': zhCN, 'en-US': enUS, 'ja-JP': jaJP }

/**
 * Map a page language to a docs locale.
 *
 * @param lang - The `lang` VitePress resolved for the current page
 * @returns The matching locale, falling back to Simplified Chinese
 */
export function resolveSiteLocale(lang: string): SiteLocale {
  return Object.values(siteLocales).find(locale => locale === lang) ?? 'zh-CN'
}

/**
 * Translate theme copy and prefix internal links for the current page's locale.
 *
 * @example
 * ```ts
 * const { t, link } = useI18n()
 * t('catalog.count', { shown: 3, total: 13 }) // "Showing 3 of 13 components" on /en/
 * link('/components/') // "/en/components/" on /en/
 * ```
 */
export function useI18n() {
  const { lang, localeIndex } = useData()
  const locale = computed(() => resolveSiteLocale(lang.value))
  function t(key: MessageKey, params?: Record<string, string | number>) {
    return catalogs[locale.value][key].replace(/\{(\w+)\}/g, (placeholder, name: string) => String(params?.[name] ?? placeholder))
  }
  function link(path: string) {
    return localeIndex.value === 'root' ? path : `/${localeIndex.value}${path}`
  }
  return { locale, t, link }
}
