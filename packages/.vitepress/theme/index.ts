import DefaultTheme from "vitepress/dist/client/theme-default";

import DemoBlock from "./components/DemoBlock.vue";

// custom css
import "./styles/index.scss";

const theme = {
  ...DefaultTheme,
  enhanceApp({ app }) {
    app.component("DemoBlock", DemoBlock);
  },
};

export default theme;
