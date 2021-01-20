import { createApp } from "vue";
import App from "./App.vue";
import router from "./router";
import store from "./store";

// css
import "./index.css";

const app = createApp(App);

import augma from "../packages/augma";

app.use(augma);
app.use(router).use(store).mount("#app");
