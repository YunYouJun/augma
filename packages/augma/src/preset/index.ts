import type { Preset } from 'unocss'
import { shortcuts } from './shortcuts'

export * from './common'

export interface AugmaOptions { }

export function presetAugma(_options = {}): Preset {
  return {
    name: 'unocss-preset-augma',
    theme: {
      colors: {
        primary: '#557591',
      },
    },
    shortcuts,
  }
}

export default presetAugma
