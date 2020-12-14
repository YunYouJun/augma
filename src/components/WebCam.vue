<template>
  <video id="webcam" ref="webcamVideo" autoplay></video>
</template>

<script>
import { changeWebcamStream } from "../lib/webcam";
export default {
  mounted() {
    this.initWebcam();
  },
  methods: {
    async initWebcam() {
      const videoEl = this.$refs.webcamVideo;
      await changeWebcamStream(videoEl);
    },
  },
};
</script>

<style lang="scss">
#webcam {
  width: 100vw;
  height: 100vh;
  object-fit: cover;
}

.flip {
  transform: rotateY(180deg);
}
</style>
