import VueLoading from 'vue-loading-overlay'
import 'vue-loading-overlay/dist/vue-loading.css'

import { UserModule } from '~/types'

export const install: UserModule = ({ app }) => {
  app.use(VueLoading)
}
