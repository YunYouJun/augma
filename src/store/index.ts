import { createStore, createLogger } from "vuex";

import app from "./modules/app";
import camera from "./modules/camera";
import faceApi from "./modules/faceApi";
import windows from "./modules/windows";

// const debug = process.env.NODE_ENV !== "production";
const debug = false;

export default createStore({
  state: {},
  mutations: {},
  actions: {},
  modules: {
    app,
    camera,
    faceApi,
    windows,
  },
  strict: debug,
  plugins: debug ? [createLogger()] : [],
});
