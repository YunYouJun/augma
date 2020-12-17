<template>
  <video :class="classes" id="webcam" ref="webcamVideo" autoplay></video>
</template>

<script>
import { changeWebcamStream } from "../lib/webcam";
export default {
  props: {
    flip: Boolean,
    front: Boolean,
  },
  async mounted() {
    this.initWebcam();
  },
  computed: {
    classes() {
      return {
        flip: this.flip,
      };
    },
  },
  watch: {
    async front(val) {
      const videoEl = this.$refs.webcamVideo;
      await changeWebcamStream(videoEl, this.front);
    },
  },
  methods: {
    async initWebcam() {
      const videoEl = this.$refs.webcamVideo;
      this.$store.commit("camera/setVideoEl", videoEl);
      const settings = await changeWebcamStream(videoEl, this.front);
      this.$store.commit("camera/setSettings", settings);
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
