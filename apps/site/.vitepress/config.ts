import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vitepress'
import { components, origin } from '../../../scripts/catalog.mjs'

const root = (path: string) =>
  fileURLToPath(new URL(`../../../${path}`, import.meta.url))
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
  ],
  sitemap: { hostname: origin },
  transformHead({ pageData }) {
    const path = pageData.relativePath
      .replace(/(^|\/)index\.md$/, '$1')
      .replace(/\.md$/, '')
    return [['link', { rel: 'canonical', href: `${origin}/${path}` }]]
  },
  themeConfig: {
    nav: [
      { text: '组件', link: '/components/' },
      { text: '展示', link: '/showcase/' },
      { text: '设计', link: '/design/' },
      { text: 'AI 接入', link: '/ai/' },
    ],
    sidebar: [
      {
        text: '开始使用',
        items: [
          { text: '快速开始', link: '/guide/' },
          { text: '升级说明', link: '/guide/migration' },
          { text: 'AR 演示', link: '/guide/ar' },
          { text: '设计规范', link: '/design/' },
          { text: 'AI 接入', link: '/ai/' },
        ],
      },
      ...['基础', '控制', '反馈', 'HUD'].map(group => ({
        text: group,
        items: components
          .filter(c => c.group === group)
          .map(c => ({ text: c.title, link: `/components/${c.slug}` })),
      })),
    ],
    search: {
      provider: 'local',
      options: {
        locales: {
          root: {
            translations: {
              button: { buttonText: '搜索文档', buttonAriaLabel: '搜索文档' },
              modal: {
                noResultsText: '没有找到相关内容',
                resetButtonTitle: '清除搜索',
                footer: {
                  selectText: '选择',
                  navigateText: '切换',
                  closeText: '关闭',
                },
              },
            },
          },
        },
      },
    },
    socialLinks: [
      { icon: 'github', link: 'https://github.com/YunYouJun/augma' },
    ],
    outline: { label: '本页内容', level: [2, 3] },
    docFooter: { prev: '上一页', next: '下一页' },
    lastUpdated: { text: '更新于' },
    darkModeSwitchLabel: '主题',
    lightModeSwitchTitle: '切换浅色主题',
    darkModeSwitchTitle: '切换深色主题',
    sidebarMenuLabel: '目录',
    returnToTopLabel: '返回顶部',
    editLink: {
      pattern: 'https://github.com/YunYouJun/augma/edit/main/apps/site/:path',
      text: '在 GitHub 上编辑此页',
    },
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
      ],
    },
    server: { fs: { allow: [root('.')] } },
  },
})
