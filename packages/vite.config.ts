import { resolve } from 'node:path'
import { defineConfig } from 'vite'
import type { Plugin } from 'vite'

import Icons from 'unplugin-icons/vite'
import IconsResolver from 'unplugin-icons/resolver'
import Components from 'unplugin-vue-components/vite'

import { VitePWA } from 'vite-plugin-pwa'

import { capitalize } from 'vue'

import Unocss from 'unocss/vite'

import { presetAttributify, presetIcons, presetUno } from 'unocss'

import { hasDemo } from '../scripts/utils'
import { augmaChildren } from './metadata/src'

import { alias } from './augma/src/node'

// do not use './augma/src' directly to avoid ts load *.vue
import { AugmaResolver } from './augma/src/resolver'
import { presetAugma } from './augma/src/preset'
import { safelist } from './augma/src/preset/safelist'

export default defineConfig({
  resolve: {
    alias: {
      ...alias,
    },
  },
  plugins: [
    Unocss({
      presets: [
        presetAttributify({
          /* preset options */
        }),
        presetUno(),
        presetIcons({
          /* options */
        }),
        presetAugma(),
      ],
      safelist,
    }),

    // https://github.com/antfu/unplugin-vue-components
    Components({
      dirs: [resolve(__dirname, './.vitepress')],

      // allow auto load markdown components under `./src/components/`
      extensions: ['vue', 'md'],

      // allow auto import and register components used in markdown
      include: [/\.vue$/, /\.vue\?vue/, /\.md$/],

      // custom resolvers
      resolvers: [
        // auto import icons
        // https://github.com/antfu/unplugin-icons
        IconsResolver({
          // componentPrefix: '',
          // enabledCollections: ['carbon']
        }),
        AugmaResolver(),
      ],

      dts: '.vitepress/components.d.ts',
    }),

    // https://github.com/antfu/unplugin-icons
    Icons({
      autoInstall: true,
    }),

    MarkdownTransform(),

    VitePWA({
      outDir: '.vitepress/dist',
      manifest: {
        name: 'Augma Docs',
        short_name: 'Augma',
        theme_color: '#557591',
        icons: [
          {
            src: '/logo.png',
            sizes: '240x240',
            type: 'image/png',
          },
        ],
      },
    }),
  ],
})

function MarkdownTransform(): Plugin {
  return {
    name: 'md-transform',
    enforce: 'pre',
    transform(code, id) {
      if (!id.endsWith('.md'))
        return null

      const [pkg, name, i] = id.split('/').slice(-3)

      if (augmaChildren.includes(name) && i === 'index.md') {
        const yamlEnd = code.indexOf('---\n\n')
        let frontmatterEnds = code.length - 1
        if (yamlEnd !== -1)
          frontmatterEnds = code.indexOf('---\n\n') + 4

        let header = ''
        if (hasDemo(pkg, name)) {
          const insertedCode
              = '\n<script setup>\nimport Demo from \'./demo.vue\'\n</script>\n'
          const demoCode = `\n::: demo\n\n<<< ./packages/${pkg}/${name}/demo.vue\n\n:::\n`
          // const demoCode = '\n<DemoContainer><Demo/></DemoContainer>\n'
          // header = `${insertedCode}\n# ${capitalize(name)}\n${demoCode}`

          const apiTable = '## API \n\n<PropsTable v-if="$frontmatter" :props="$frontmatter.props" />'
          header = `${insertedCode}\n# ${capitalize(
            name,
          )} {{ $frontmatter.title }} \n> {{ $frontmatter.description || '简要描述' }}${demoCode}${apiTable}`
        }

        if (header) {
          code
              = `${code.slice(0, frontmatterEnds) + header + code.slice(frontmatterEnds)}`
        }
      }

      return code
    },
  }
}
