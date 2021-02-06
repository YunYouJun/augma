<template>
  <video :class="classes" id="webcam" ref="webcamVideo" autoplay></video>
</template>

<script>
import { Webcam } from "../lib/webcam";
export default {
  props: {
    flip: Boolean,
    front: Boolean,
  },
  data() {
    return {
      webcam: null,
    };
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

      await this.webcam.changeWebcamStream(this.front);
    },
  },
  methods: {
    async initWebcam() {
      const videoEl = this.$refs.webcamVideo;
      this.$store.commit("camera/setVideoEl", videoEl);

      this.webcam = new Webcam(videoEl, this.front);
      await this.webcam.changeWebcamStream(this.front);

      const settings = this.webcam.settings;
      this.$store.commit("camera/setSettings", settings);

      const ratio = document.body.clientWidth / settings.width;
      this.$store.commit("camera/setRatio", ratio);
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
