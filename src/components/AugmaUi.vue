<template>
  <div id="augma-ui" class="augma-ui" :style="styles">
    <div id="agm-loading-container">
      <agm-loading :loading="$store.state.app.loading" />
    </div>

    <system-bar />
    <agm-window />
    <face-api :enable="$store.state.faceApi.faceDetection" />
    <tfjs-yolo :enable="$store.state.app.yolo" />
    <bottom-menu id="augma-bottom-menu" />
  </div>
</template>

<script lang="ts">
import AgmWindow from "./ui/AgmWindow.vue";
import SystemBar from "./ui/SystemBar.vue";
import BottomMenu from "./ui/BottomMenu.vue";
import FaceApi from "./examples/FaceApi.vue";
import TfjsYolo from "./examples/TfjsYolo.vue";
import { defineComponent } from "vue";
export default defineComponent({
  components: {
    AgmWindow,
    BottomMenu,
    SystemBar,
    FaceApi,
    TfjsYolo,
  },
  props: {
    opacity: Number,
  },
  computed: {
    styles() {
      return {
        opacity: this.opacity,
      };
    },
  },
});
</script>

<style lang="scss">
.augma-ui {
  position: fixed;
  text-align: center;
  left: 0;
  top: 0;
  width: 100vw;
  height: 100vh;
  background: rgba(255, 255, 255, 0.1);
}

#augma-bottom-menu {
  position: absolute;
  left: 0;
  bottom: 1rem;

  width: 100%;
  margin: 0 auto;
}
</style>
