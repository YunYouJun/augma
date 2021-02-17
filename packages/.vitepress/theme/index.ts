import DefaultTheme from "vitepress/dist/client/theme-default";

import DemoBlock from "./components/DemoBlock.vue";

// custom css
import augma from "augma";
import "./styles/index.scss";

const theme = {
  ...DefaultTheme,
  enhanceApp({ app }) {
    app.component("DemoBlock", DemoBlock);

    app.use(augma);
  },
};

export default theme;
