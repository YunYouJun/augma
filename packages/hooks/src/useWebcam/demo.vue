<template>
  <video id="webcam" ref="videoRef" autoplay />
</template>

<script lang="ts">
import { defineComponent, onMounted, ref } from "vue";
import { useWebcam } from "./index";

export default defineComponent({
  setup() {
    const videoRef = ref(null);
    const { changeWebcamStream, settings } = useWebcam(videoRef);

    onMounted(async () => {
      await changeWebcamStream();
      console.log(settings.value);
    });

    return {
      videoRef,
    };
  },
});
</script>

<style scoped>
#webcam {
  width: 100%;
}
</style>
