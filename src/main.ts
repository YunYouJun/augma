import { createApp } from "vue";
import App from "./App.vue";
import store from "./store";

// css
import "./index.css";

const app = createApp(App);

import augma from "../packages/augma";

app.use(augma);
app.use(store).mount("#app");
