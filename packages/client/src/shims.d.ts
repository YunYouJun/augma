/* eslint-disable import/no-duplicates */
import type { PluginApi } from 'vue-loading-overlay'

declare interface Window {
  // extend the window
}

// with vite-plugin-md, markdowns can be treat as Vue components
declare module '*.md' {
  import type { ComponentOptions } from 'vue'
  const component: ComponentOptions
  export default component
}

declare module '@vue/runtime-core' {
  interface ComponentInternalInstance {
    $loading: PluginApi
  }
}
