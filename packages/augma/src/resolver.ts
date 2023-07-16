import type { ComponentResolver } from 'unplugin-vue-components'

export interface AugmaResolverOptions {}

export function AugmaResolver(_options: AugmaResolverOptions = {}): ComponentResolver {
  return {
    type: 'component',
    resolve(name: string) {
      if (name.startsWith('Agm')) {
        return {
          from: 'augma',
          name,
        }
      }
    },
  }
}
