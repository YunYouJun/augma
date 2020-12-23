<template>
  <agm-button icon @click="toggleFullscreen" title="Fullscreen">
    <agm-icon :icon="icon"></agm-icon>
  </agm-button>
</template>

<script>
import { mdiFullscreen, mdiFullscreenExit } from "@mdi/js";
import { toggleFullscreen } from "../../../packages/augma/utils/functions";
export default {
  data() {
    return {
      fullscreen: document.fullscreenElement,
    };
  },
  computed: {
    icon() {
      return this.fullscreen ? mdiFullscreenExit : mdiFullscreen;
    },
  },
  mounted() {
    document.onfullscreenchange = () => {
      this.fullscreen = document.fullscreenElement;
    };
  },
  methods: {
    toggleFullscreen() {
      toggleFullscreen();
    },
  },
};
</script>
