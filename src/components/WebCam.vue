<template>
  <video :class="classes" id="webcam" ref="webcamVideo" autoplay></video>
</template>

<script>
import { changeWebcamStream } from "../lib/webcam";
export default {
  props: {
    flip: Boolean,
  },
  mounted() {
    this.initWebcam();
  },
  computed: {
    classes() {
      return {
        flip: this.flip,
      };
    },
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
