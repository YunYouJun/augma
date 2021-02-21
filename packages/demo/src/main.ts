import { createApp } from "vue";
import App from "./App.vue";
import router from "./router";
import store from "./store";

// css
import "./index.css";

const app = createApp(App);

import augma from "augma";
// import "@augma/components/styles/index.scss";
import "augma/dist/style.css";

app.use(augma);
app.use(router).use(store).mount("#app");
