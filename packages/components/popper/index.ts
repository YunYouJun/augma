import type { App } from 'vue'
import Popper from './src/index.vue'

Popper.install = (app: App): void => {
  app.component(Popper.name, Popper)
}

export default Popper
