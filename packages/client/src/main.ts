import type { UserModule } from './types'
import { setupLayouts } from 'virtual:generated-layouts'
import generatedRoutes from 'virtual:generated-pages'
// register vue composition api globally
import { ViteSSG } from 'vite-ssg'

import App from './App.vue'

// https://github.com/antfu/unocss
import '@unocss/reset/tailwind.css'
// custom css
import './styles/index.scss'

import '@augma/components/styles/index.scss'

import 'uno.css'

const routes = setupLayouts(generatedRoutes)

// https://github.com/antfu/vite-ssg
export const createApp = ViteSSG(
  App,
  { routes, base: import.meta.env.BASE_URL },
  (ctx) => {
    // install all modules under `modules/`
    Object.values(import.meta.glob<{ install: UserModule }>('./modules/*.ts', { eager: true }))
      .forEach(i => i.install?.(ctx))
  },
)
