<template>
  <web-cam
    v-if="$store.state.camera.display"
    :flip="$store.state.camera.flipScreen"
    :front="$store.state.camera.front"
  ></web-cam>
  <augma-ui :opacity="1"></augma-ui>
</template>

<script>
import AugmaUi from "./components/AugmaUi.vue";
import WebCam from "./components/WebCam.vue";

export default {
  name: "App",
  components: {
    AugmaUi,
    WebCam,
  },
};
</script>
