import antfu from '@antfu/eslint-config'

export default antfu({
  vue: true,
  typescript: true,
  // Icon Composer documents keep Apple's formatting and are SHA-256 pinned.
  ignores: ['.edgeone/**', '**/dist/**', '**/node_modules/**', '**/public/**', '**/.vitepress/cache/**', '**/.vitepress/dist/**', 'test-results/**', 'playwright-report/**', '**/*.icon/**'],
  rules: {
    'vue/singleline-html-element-content-newline': 'off',
    'vue/html-self-closing': 'off',
    'antfu/top-level-function': 'off',
  },
})
