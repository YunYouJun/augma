import { ComponentCustomProperties } from "vue";
import { Store } from "vuex";

declare interface Window {
  // extend the window
}

import { State as CameraState } from "./store/modules/camera";

declare module "@vue/runtime-core" {
  // declare your own store states
  interface State {
    app: any;
    camera: CameraState;
    faceApi: any;
  }

  // provide typings for `this.$store`
  interface ComponentCustomProperties {
    $store: Store<State>;
  }
}
