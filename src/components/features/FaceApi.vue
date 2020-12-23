<template>
  <div id="rects"></div>
  <canvas id="overlay" ref="overlay"></canvas>
</template>

<script>
import * as faceapi from "face-api.js";
export default {
  data() {
    return {
      videoEl: null,
      overlay: null,

      minConfidence: 0.5,
      withBoxes: true,
    };
  },

  async mounted() {},
};
</script>
