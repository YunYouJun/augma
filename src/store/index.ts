import { createStore } from "vuex";
import app from "./modules/app";
import camera from "./modules/camera";

export default createStore({
  state: {},
  mutations: {},
  actions: {},
  modules: {
    app,
    camera,
  },
});
