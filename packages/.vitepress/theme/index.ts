import DefaultTheme from "vitepress/dist/client/theme-default";

import DemoBlock from "./components/DemoBlock.vue";

// custom css
import augma from "augma";
import "./styles/index.scss";

// import Iconify from "@iconify/iconify/dist/iconify.without-api.min.js";
// import mdiIcons from "@iconify/json/json/mdi.json";
// Iconify.addCollection(mdiIcons);

import "@iconify/iconify";
// Iconify.loadIcons(["mdi:github"]);

// import "https://code.iconify.design/2/2.0.0-rc.6/iconify.min.js";

const theme = {
  ...DefaultTheme,
  enhanceApp({ app }) {
    // app.use(augma);

    app.component("DemoBlock", DemoBlock);
  },
};

export default theme;
