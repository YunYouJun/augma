import type { ComponentSize } from '@augma/utils'

export interface InstallOptions {
  size: ComponentSize
  zIndex: number
}

export type AugmaOptions = InstallOptions

let $AUGMA = {} as InstallOptions

function setConfig(option: InstallOptions): void {
  $AUGMA = option
}

function getConfig(key: keyof InstallOptions): unknown {
  return $AUGMA[key]
}

export { getConfig, setConfig }
