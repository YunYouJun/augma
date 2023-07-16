import type { App } from 'vue'

import type { ComponentSize, InstallOptions } from '@augma/utils'

export * from './bottom-menu'
export * from './button'
export * from './card'
export * from './clock'
export * from './dialog'
export * from './form'
export * from './indicator'
export * from './icon'
export * from './input'
export * from './menu'
export * from './select'
export * from './toast'

const defaultInstallOpt: InstallOptions = {
  size: '' as ComponentSize,
  zIndex: 2000,
}

// register component & plugin
function install(app: App, opt: InstallOptions): void {
  const option = Object.assign(defaultInstallOpt, opt)
  app.config.globalProperties.$AUGMA = option
}

export { install }
