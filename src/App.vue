<template>
  <web-cam :flip="$store.state.app.flipScreen"></web-cam>
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
