// windicss layers
// import 'virtual:windi-base.css'
// import 'virtual:windi-components.css'

// https://github.com/antfu/unocss
import 'uno.css'

import DefaultTheme from 'vitepress/theme'

// custom css
// import augma from "augma";
// import "@augma/components/styles/index.scss";
// custom css
import './styles/index.scss'

import Toast from 'vue-toastification'

// Import the CSS or use your own!
import 'vue-toastification/dist/index.css'

import VTooltip from 'v-tooltip'
import 'v-tooltip/dist/v-tooltip.css'
import type { Theme } from 'vitepress'

// windicss utilities should be the last style import
// import 'virtual:windi-utilities.css'
// windicss devtools support (dev only)
// import 'virtual:windi-devtools'

const theme: Theme = {
  ...DefaultTheme,
  async enhanceApp({ app }) {
    app.use(Toast)
    app.use(VTooltip)
  },
}

export default theme
