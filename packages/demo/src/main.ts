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

// import augma from "augma";
import augma from "augma";
// import "@augma/components/styles/index.scss";
import "augma/dist/style.css";

app.use(router).use(store).use(augma).mount("#app");
