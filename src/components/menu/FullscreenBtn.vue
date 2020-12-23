<template>
  <agm-button icon @click="toggleFullscreen" title="Fullscreen">
    <agm-icon :icon="icon"></agm-icon>
  </agm-button>
</template>

<script>
import { mdiFullscreen, mdiFullscreenExit } from "@mdi/js";
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
      if (!document.fullscreenElement) {
        document.documentElement.requestFullscreen().catch((err) => {
          this.$notify({
            type: "error",
            message: "无法进入全屏模式",
          });
        });
      } else {
        document.exitFullscreen();
      }
    },
  },
};
</script>
