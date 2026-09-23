import type { Theme } from 'vitepress'
import DefaultTheme from 'vitepress/theme'
import ComponentCatalog from './components/ComponentCatalog.vue'
import DemoPreview from './components/DemoPreview.vue'
import HomePage from './components/HomePage.vue'
import ShowcasePage from './components/ShowcasePage.vue'
import '@fontsource/exo-2/400.css'
import '@fontsource/exo-2/500.css'
import '@fontsource/exo-2/600.css'
import '@fontsource/exo-2/700.css'
import '@augma/core/style.css'
import './style.css'

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    app.component('HomePage', HomePage)
    app.component('DemoPreview', DemoPreview)
    app.component('ComponentCatalog', ComponentCatalog)
    app.component('ShowcasePage', ShowcasePage)
  },
} satisfies Theme
