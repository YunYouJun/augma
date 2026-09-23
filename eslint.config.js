import antfu from '@antfu/eslint-config'

export default antfu({
  vue: true,
  typescript: true,
  ignores: ['**/dist/**', '**/node_modules/**', '**/public/**', '**/.vitepress/cache/**', '**/.vitepress/dist/**', 'test-results/**', 'playwright-report/**'],
  rules: {
    'vue/singleline-html-element-content-newline': 'off',
    'vue/html-self-closing': 'off',
    'antfu/top-level-function': 'off',
  },
})
