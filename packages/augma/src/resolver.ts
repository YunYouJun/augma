import type { ComponentResolver } from 'unplugin-vue-components'

export interface AugmaResolverOptions {}

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export function AugmaResolver(options: AugmaResolverOptions = {}): ComponentResolver {
  return {
    type: 'component',
    resolve: (name: string) => {
      if (name.startsWith('Agm')) {
        return {
          importName: name,
          path: 'augma',
        }
      }
    },
  }
}
