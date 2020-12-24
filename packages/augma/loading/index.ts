import { App } from "vue";
import Loading from "./src/index";

const $loading = Loading();

export default {
  install(app: App) {
    app.config.globalProperties.$loading = $loading;
  },
};
