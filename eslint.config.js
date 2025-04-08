import antfu from '@antfu/eslint-config'

export default antfu({
  ignores: ['dist/', '**/dist/**/', 'public/', '**/public/**/', 'node_modules/', '**/node_modules/**/', 'patches/', '**/patches/**/', 'cache/', '**/cache/**/'],
  formatters: true,
  unocss: true,
  vue: true,
})
