import { createStore } from "vuex";

import app from "./modules/app";
import camera from "./modules/camera";
import windows from "./modules/windows";

export default createStore({
  state: {},
  mutations: {},
  actions: {},
  modules: {
    app,
    camera,
    windows,
  },
});
