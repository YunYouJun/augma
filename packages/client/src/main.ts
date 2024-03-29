import { createApp } from "vue";
import App from "./App.vue";
import store from "./store";

// css
import "./index.css";

import { createRouter, createWebHashHistory } from "vue-router";
import routes from "pages-generated";

const router = createRouter({
  history: createWebHashHistory(),
  routes,
});

const app = createApp(App);

import augma from "../../augma/index";
import "../../components/styles/index.scss";

import "@iconify/iconify";

app.use(router).use(store).use(augma).mount("#app");
