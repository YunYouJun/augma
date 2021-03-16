import DefaultTheme from "vitepress/dist/client/theme-default";

import DemoBlock from "./components/DemoBlock.vue";

// import augma from "augma";
import augma from "../../augma/index";
import "../../components/styles/index.scss";
// custom css
import "./styles/index.scss";

// import Iconify from "@iconify/iconify/dist/iconify.without-api.min.js";
// import mdiIcons from "@iconify/json/json/mdi.json";
// Iconify.addCollection(mdiIcons);

import "@iconify/iconify";
// import Iconify from "@iconify/iconify";
// Iconify.loadIcons(["mdi:github"]);

// import "https://code.iconify.design/2/2.0.0-rc.6/iconify.min.js";

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
