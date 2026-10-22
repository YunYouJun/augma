import type { DefaultTheme, HeadConfig, LocaleSpecificConfig } from 'vitepress'
import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vitepress'
import { groupNames, localizeComponents, localizeEffects } from '../../../scripts/catalog-i18n.mjs'
import { origin } from '../../../scripts/catalog.mjs'

const root = (path: string) =>
  fileURLToPath(new URL(`../../../${path}`, import.meta.url))

type Lang = 'zh-CN' | 'en-US' | 'ja-JP'

// Simplified Chinese is the source at `/`; translations mirror its paths under `/en/` and `/ja/`.
const locales = [
  {
    key: 'root',
    lang: 'zh-CN',
    label: '简体中文',
    prefix: '',
    ogLocale: 'zh_CN',
    title: '界面，浮现于现实。',
    description: '为 Web 构建轻盈的 AR 风格界面。',
    nav: ['组件', '展示', '设计', 'AI 接入', '下载'],
    start: ['开始使用', '快速开始', '升级说明', 'AR 演示', 'macOS 客户端', '设计规范', 'AI 接入'],
    theme: {
      outline: '本页内容',
      prev: '上一页',
      next: '下一页',
      lastUpdated: '更新于',
      darkModeSwitchLabel: '主题',
      lightModeSwitchTitle: '切换浅色主题',
      darkModeSwitchTitle: '切换深色主题',
      sidebarMenuLabel: '目录',
      returnToTopLabel: '返回顶部',
      langMenuLabel: '切换语言',
      skipToContentLabel: '跳到正文',
      editLink: '在 GitHub 上编辑此页',
    },
    search: {
      button: '搜索文档',
      noResults: '没有找到相关内容',
      reset: '清除搜索',
      back: '返回',
      details: '显示详细列表',
      select: '选择',
      navigate: '切换',
      close: '关闭',
    },
  },
  {
    key: 'en',
    lang: 'en-US',
    label: 'English',
    prefix: 'en/',
    ogLocale: 'en_US',
    title: 'Interfaces that surface in reality.',
    description: 'Build light, AR-inspired interfaces for the web.',
    nav: ['Components', 'Showcase', 'Design', 'AI', 'Download'],
    start: ['Getting started', 'Quick start', 'Migrating from 0.1', 'AR demo', 'macOS app', 'Design system', 'AI integration'],
    theme: {
      outline: 'On this page',
      prev: 'Previous page',
      next: 'Next page',
      lastUpdated: 'Last updated',
      darkModeSwitchLabel: 'Appearance',
      lightModeSwitchTitle: 'Switch to light theme',
      darkModeSwitchTitle: 'Switch to dark theme',
      sidebarMenuLabel: 'Menu',
      returnToTopLabel: 'Return to top',
      langMenuLabel: 'Change language',
      skipToContentLabel: 'Skip to content',
      editLink: 'Edit this page on GitHub',
    },
    search: {
      button: 'Search docs',
      noResults: 'No results for',
      reset: 'Clear search',
      back: 'Back',
      details: 'Show detailed list',
      select: 'to select',
      navigate: 'to navigate',
      close: 'to close',
    },
  },
  {
    key: 'ja',
    lang: 'ja-JP',
    label: '日本語',
    prefix: 'ja/',
    ogLocale: 'ja_JP',
    title: 'インターフェースが、現実に浮かび上がる。',
    description: 'Web のための、軽やかな AR スタイルのインターフェース。',
    nav: ['コンポーネント', 'ショーケース', 'デザイン', 'AI 連携', 'ダウンロード'],
    start: ['はじめに', 'クイックスタート', '0.1 からの移行', 'AR デモ', 'macOS アプリ', 'デザインシステム', 'AI 連携'],
    theme: {
      outline: 'このページの内容',
      prev: '前のページ',
      next: '次のページ',
      lastUpdated: '最終更新',
      darkModeSwitchLabel: 'テーマ',
      lightModeSwitchTitle: 'ライトテーマに切り替え',
      darkModeSwitchTitle: 'ダークテーマに切り替え',
      sidebarMenuLabel: 'メニュー',
      returnToTopLabel: 'トップに戻る',
      langMenuLabel: '言語を切り替え',
      skipToContentLabel: '本文へスキップ',
      editLink: 'GitHub でこのページを編集',
    },
    search: {
      button: 'ドキュメントを検索',
      noResults: '一致する結果がありません',
      reset: '検索をクリア',
      back: '戻る',
      details: '詳細を表示',
      select: '選択',
      navigate: '移動',
      close: '閉じる',
    },
  },
] satisfies { key: string, lang: Lang, prefix: string, [field: string]: unknown }[]

type Locale = typeof locales[number]

function themeConfig(locale: Locale): DefaultTheme.Config {
  const link = (path: string) => `/${locale.prefix}${path}`
  const [components, showcase, design, ai, download] = locale.nav
  const [start, quickStart, migration, ar, macos, designGuide, aiGuide] = locale.start
  // Effects such as Link Start share the sidebar with components under their own group.
  const catalog = [...localizeComponents(locale.lang), ...localizeEffects(locale.lang)]
  return {
    nav: [
      { text: components, link: link('components/') },
      { text: showcase, link: link('showcase/') },
      { text: design, link: link('design/') },
      { text: ai, link: link('ai/') },
      { text: download, link: link('download') },
    ],
    sidebar: [
      {
        text: start,
        items: [
          { text: quickStart, link: link('guide/') },
          { text: migration, link: link('guide/migration') },
          { text: ar, link: link('guide/ar') },
          { text: macos, link: link('guide/macos') },
          { text: designGuide, link: link('design/') },
          { text: aiGuide, link: link('ai/') },
        ],
      },
      ...(Object.keys(groupNames) as (keyof typeof groupNames)[]).map(group => ({
        text: groupNames[group][locale.lang],
        items: catalog
          .filter(c => c.group === group)
          .map(c => ({ text: c.title, link: link(`components/${c.slug}`) })),
      })),
    ],
    outline: { label: locale.theme.outline, level: [2, 3] },
    docFooter: { prev: locale.theme.prev, next: locale.theme.next },
    lastUpdated: { text: locale.theme.lastUpdated },
    darkModeSwitchLabel: locale.theme.darkModeSwitchLabel,
    lightModeSwitchTitle: locale.theme.lightModeSwitchTitle,
    darkModeSwitchTitle: locale.theme.darkModeSwitchTitle,
    sidebarMenuLabel: locale.theme.sidebarMenuLabel,
    returnToTopLabel: locale.theme.returnToTopLabel,
    langMenuLabel: locale.theme.langMenuLabel,
    skipToContentLabel: locale.theme.skipToContentLabel,
    editLink: {
      pattern: 'https://github.com/YunYouJun/augma/edit/main/apps/site/:path',
      text: locale.theme.editLink,
    },
  }
}

// The AR demo at /ar/ is a separate app that reads its language from localStorage (apps/ar/src/i18n/locale.ts).
// Inlined into <head> so links followed before hydration still carry the docs language over.
function handOffLocaleToAr() {
  const remember = (event: MouseEvent) => {
    const anchor = (event.target as Element | null)?.closest?.('a[href]')
    if (!(anchor instanceof HTMLAnchorElement) || anchor.origin !== location.origin || !/^\/ar(?:\/|$)/.test(anchor.pathname))
      return
    try {
      localStorage.setItem('augma-locale', document.documentElement.lang)
    }
    catch {}
  }
  // Capture phase, and auxclick for middle-click "open in new tab".
  addEventListener('click', remember, true)
  addEventListener('auxclick', remember, true)
}

const pagePath = (relativePath: string) =>
  relativePath.replace(/(^|\/)index\.md$/, '$1').replace(/\.md$/, '')

export default defineConfig({
  lang: 'zh-CN',
  title: 'Augma',
  description: '为 Web 构建轻盈的 AR 风格界面。',
  cleanUrls: true,
  lastUpdated: true,
  appearance: true,
  srcExclude: ['public/**'],
  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/favicon.svg' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:site_name', content: 'Augma' }],
    ['meta', { property: 'og:image', content: `${origin}/og.jpg` }],
    ['meta', { property: 'og:image:type', content: 'image/jpeg' }],
    ['meta', { property: 'og:image:width', content: '1200' }],
    ['meta', { property: 'og:image:height', content: '630' }],
    ['meta', { name: 'twitter:card', content: 'summary_large_image' }],
    ['meta', { name: 'twitter:image', content: `${origin}/og.jpg` }],
    ['script', {}, `(${handOffLocaleToAr})()`],
  ],
  sitemap: { hostname: origin },
  // Canonical URL, Open Graph copy in the page's language, and hreflang links to every translation of the page.
  transformHead({ pageData, siteConfig }) {
    const path = pageData.relativePath
    const locale = locales.find(l => l.prefix && path.startsWith(l.prefix)) ?? locales[0]
    const source = path.slice(locale.prefix.length)
    const translations = locales.filter(l => siteConfig.pages.includes(l.prefix + source))
    const head: HeadConfig[] = [
      ['link', { rel: 'canonical', href: `${origin}/${pagePath(path)}` }],
      ['meta', { property: 'og:url', content: `${origin}/${pagePath(path)}` }],
      ['meta', { property: 'og:title', content: `Augma · ${locale.title}` }],
      ['meta', { property: 'og:description', content: locale.description }],
      ['meta', { property: 'og:locale', content: locale.ogLocale }],
    ]
    if (translations.length > 1) {
      for (const translation of translations)
        head.push(['link', { rel: 'alternate', hreflang: translation.lang, href: `${origin}/${pagePath(translation.prefix + source)}` }])
      head.push(['link', { rel: 'alternate', hreflang: 'x-default', href: `${origin}/${pagePath(source)}` }])
    }
    return head
  },
  locales: Object.fromEntries(locales.map(locale => [locale.key, {
    label: locale.label,
    lang: locale.lang,
    link: `/${locale.prefix}`,
    description: locale.description,
    themeConfig: themeConfig(locale),
  } satisfies LocaleSpecificConfig<DefaultTheme.Config> & { label: string, link: string }])),
  themeConfig: {
    search: {
      provider: 'local',
      options: {
        locales: Object.fromEntries(locales.map(({ key, search }) => [key, {
          translations: {
            button: { buttonText: search.button, buttonAriaLabel: search.button },
            modal: {
              displayDetails: search.details,
              resetButtonTitle: search.reset,
              backButtonTitle: search.back,
              noResultsText: search.noResults,
              footer: {
                selectText: search.select,
                navigateText: search.navigate,
                closeText: search.close,
              },
            },
          },
        }])),
      },
    },
    socialLinks: [
      { icon: 'github', link: 'https://github.com/YunYouJun/augma' },
    ],
  },
  vite: {
    resolve: {
      alias: [
        { find: /^augma$/, replacement: root('packages/augma/src/index.ts') },
        {
          find: 'augma/style.css',
          replacement: root('packages/core/src/style.css'),
        },
        {
          find: '@augma/core/style.css',
          replacement: root('packages/core/src/style.css'),
        },
        {
          find: '@augma/core/link-start',
          replacement: root('packages/core/src/link-start.ts'),
        },
      ],
    },
    server: { fs: { allow: [root('.')] } },
  },
})
