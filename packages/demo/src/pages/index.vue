<template>
  <!-- <web-cam
    v-if="$store.state.camera.display"
    :isFlip="$store.state.camera.flipScreen"
    :isFront="$store.state.camera.front"
  ></web-cam> -->
  <augma-ui :opacity="0.95"></augma-ui>
</template>

<script lang="ts">
import { defineComponent } from "vue";
import AugmaUi from "~/components/AugmaUi.vue";
// import WebCam from "~/components/WebCam.vue";

export default defineComponent({
  name: "App",
  components: {
    AugmaUi,
    //   WebCam,
  },
});
</script>
