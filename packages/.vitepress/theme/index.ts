import DefaultTheme from "vitepress/dist/client/theme-default";
import Layout from "./Layout.vue";

// https://github.com/antfu/unocss
import 'uno.css'

// custom css
// import augma from "augma";
// import "@augma/components/styles/index.scss";
// custom css
import "./styles/index.scss";

import Toast from "vue-toastification";
// Import the CSS or use your own!
import "vue-toastification/dist/index.css";

const theme = {
  ...DefaultTheme,
  Layout,
  async enhanceApp({ app }) {
    app.use(Toast)
  },
};

export default theme;
