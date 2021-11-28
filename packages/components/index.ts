import type { App } from 'vue'

import type { InstallOptions } from '@augma/utils/config'
import { ComponentSize } from '@augma/shared'

export * from './notification'
export * from './dialog'
export * from './select/index.vue'
export * from './menu'
export * from './indicator/index.vue'
export * from './clock'
export * from './card'
export * from './bottom-menu'
export * from './button'
export * from './icon'

const defaultInstallOpt: InstallOptions = {
  size: '' as ComponentSize,
  zIndex: 2000,
}

// register component & plugin
const install = (app: App, opt: InstallOptions): void => {
  const option = Object.assign(defaultInstallOpt, opt)
  app.config.globalProperties.$AUGMA = option
}

export { install }
