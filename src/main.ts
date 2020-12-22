import { createApp } from "vue";
import App from "./App.vue";
import store from "./store";

// css
import "./index.css";

import augma from "../packages/augma";
import "../packages/theme/augma.scss";

const app = createApp(App);

app.use(augma);
app.use(store).mount("#app");
