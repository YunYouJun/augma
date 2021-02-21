import type { App } from "vue";

import AgmButton from "./button/index.vue";
import AgmBottomMenu from "./bottom-menu/index.vue";
import AgmCard from "./card/index.vue";
import AgmClock from "./clock/index.vue";
import AgmDialog from "./dialog/index.vue";
import AgmIndicator from "./indicator/index.vue";
import AgmMenu from "./menu/index.vue";

import AgmNotification from "./notification/index";
import AgmLoading from "./loading/index";

import type { InstallOptions } from "@augma/utils/config";
import { ComponentSize } from "@augma/shared";

const defaultInstallOpt: InstallOptions = {
  size: "" as ComponentSize,
  zIndex: 2000,
};

const components = [
  AgmButton,
  AgmBottomMenu,
  AgmCard,
  AgmClock,
  AgmDialog,
  AgmIndicator,
  AgmMenu,
];
const plugins = [AgmNotification, AgmLoading];

// register component & plugin
const install = (app: App, opt: InstallOptions): void => {
  const option = Object.assign(defaultInstallOpt, opt);
  app.config.globalProperties.$AUGMA = option;

  components.forEach((component) => {
    app.component(component.name, component);
  });

  plugins.forEach((plugin) => {
    app.use(plugin as any);
  });
};

export { install };
