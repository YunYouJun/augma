import DefaultTheme from "vitepress/dist/client/theme-default";

import DemoBlock from "./components/DemoBlock.vue";

// import augma from "augma";
import augma from "../../augma/index";
import "../../components/styles/index.scss";
// custom css
import "./styles/index.scss";

const isServer = typeof window === "undefined";

const theme = {
  ...DefaultTheme,
  async enhanceApp({ app }) {
    app.use(augma);

    // if (!isServer) {
    //   const augma = await import("augma");
    //   app.use(augma.default);
    // }

    app.component("DemoBlock", DemoBlock);
  },
};

export default theme;
