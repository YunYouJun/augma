import { App } from 'vue'
import Notify from './src/notify'
export { default as AgmNotify } from './src/notify'

export const install = (app: App): void => {
  app.config.globalProperties.$notify = Notify
}

export default Notify
