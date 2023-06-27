declare interface Window {
  // extend the window
  WebXRPolyfill?: any
}


declare module '*.vue' {
  import type { DefineComponent } from 'vue'
  const component: DefineComponent<{}, {}, any>
  export default component
}

// with vite-plugin-vue-markdown, markdowns can be treat as Vue components
declare module '*.md' {
  import type { ComponentOptions } from 'vue'
  const component: ComponentOptions
  export default component
}
