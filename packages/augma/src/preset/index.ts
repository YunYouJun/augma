import type { Preset } from '@unocss/core'
import { shortcuts } from './shortcuts'

export * from './common'

export interface AugmaOptions { }

/* eslint-disable @typescript-eslint/no-unused-vars */
export const presetAugma = (options = {}): Preset<{}> => ({
  name: 'unocss-preset-augma',
  theme: {
    colors: {
      primary: '#557591',
    },
  },
  shortcuts,
})

export default presetAugma