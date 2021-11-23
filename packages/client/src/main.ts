import { createApp } from 'vue'
import augma from 'augma'
import { createRouter, createWebHashHistory } from 'vue-router'
import routes from 'pages-generated'

import App from './App.vue'
import store from './store'

// css
import './index.css'

import '@augma/components/styles/index.scss'

const router = createRouter({
  history: createWebHashHistory(),
  routes,
})

const app = createApp(App)

app.use(router).use(store).use(augma).mount('#app')
