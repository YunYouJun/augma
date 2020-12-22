import type { App } from "vue";

import AgmButton from "./button/index.vue";
import AgmCard from "./card/index.vue";
import AgmClock from "./clock/index.vue";
import AgmIcon from "./icon/index.vue";

// html
import AgmHr from "./html/AgmHr.vue";

import AgmNotification from "./notification/index";

const components = [AgmButton, AgmCard, AgmClock, AgmHr, AgmIcon];
const plugins = [AgmNotification];

// register component & plugin
const install = (app: App) => {
  components.forEach((component) => {
    app.component(component.name, component);
  });

  plugins.forEach((plugin) => {
    app.use(plugin as any);
  });
};

import * as pkg from "./package.json";

export default {
  version: pkg.version,
  install,
};
