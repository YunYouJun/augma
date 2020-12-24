<template>
  <canvas v-show="enable" id="overlay" ref="overlay"></canvas>
  <agm-indicator
    v-show="enable"
    class="customClass"
    name="YunYouJun"
    info="201920081203009"
    :style="indicatorStyle"
  />
</template>

<script>
// import * as faceapi from "face-api.js";
// import * as faceapi from "@vladmandic/face-api";
export default {
  props: {
    enable: {
      type: Boolean,
      default: false,
    },
  },

  data() {
    return {
      videoEl: null,
      overlay: null,

      minConfidence: 0.5,
      withBoxes: false,

      indicatorStyle: {
        position: "absolute",
        top: "1rem",
        transform: "translateX(-50%)",
        transition: "all 0.2s",
      },
    };
  },

  async mounted() {
    this.videoEl = this.$store.state.camera.videoEl;
    this.overlay = this.$refs.overlay;

    this.overlay.width = document.body.clientWidth;
    this.overlay.height = document.body.clientHeight;
  },

  watch: {
    async enable(val) {
      if (val) {
        await this.loadModel();
        this.onPlay();
      }
    },
  },

  methods: {
    async loadModel() {
      const faceApiWeightsUri = "/weights";
      // const faceApiWeightsUri =
      //   "https://raw.githubusercontent.com/justadudewhohacks/face-api.js/master/weights";
      await faceapi.nets.tinyFaceDetector.loadFromUri(faceApiWeightsUri);
      // await faceapi.nets.ageGenderNet.loadFromUri(faceApiWeightsUri);
    },

    async onPlay() {
      if (!this.enable) return;

      const videoEl = this.videoEl;

      if (videoEl.paused || videoEl.ended) {
        return setTimeout(() => onPlay());
      }

      // tiny_face_detector options
      let inputSize = 512;
      let scoreThreshold = 0.5;
      const options = new faceapi.TinyFaceDetectorOptions({
        inputSize,
        scoreThreshold,
      });

      const result = await faceapi.detectSingleFace(videoEl, options);

      if (result) {
        this.drawDetectionsResults(result);
      }

      setTimeout(() => {
        this.onPlay();
      }, 100);
    },

    drawDetectionsResults(result) {
      const videoEl = this.videoEl;
      const canvas = this.overlay;
      const dims = faceapi.matchDimensions(canvas, videoEl, true);

      const resizedResult = faceapi.resizeResults(result, dims);
      this.setIndicatorByBox(resizedResult.box);
      if (this.withBoxes) {
        faceapi.draw.drawDetections(canvas, resizedResult);
      }
      // const { age, gender, genderProbability } = resizedResult;

      // interpolate gender predictions over last 30 frames
      // to make the displayed age more stable
      // const interpolatedAge = interpolateAgePredictions(age);
      // new faceapi.draw.DrawTextField(
      //   [
      //     `${faceapi.utils.round(interpolatedAge, 0)} years`,
      //     `${gender} (${faceapi.utils.round(genderProbability)})`,
      //   ],
      //   result.detection.box.bottomLeft
      // ).draw(canvas);
    },

    setIndicatorByBox(box) {
      const ratio = this.$store.state.camera.ratio;

      this.indicatorStyle.top = box.top - 180 + "px";
      this.indicatorStyle.left = `${(box.left + box.width / 2) * ratio}px`;
    },
  },
};
</script>

<style lang="scss">
#overlay {
  position: absolute;
  width: 100vw;
  height: 100vh;
  object-fit: cover;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
}

.text {
  font-size: 1em;
  padding: 5px;
  @media screen and (max-width: 600px) {
    font-size: 0.8em;
  }
}
</style>
