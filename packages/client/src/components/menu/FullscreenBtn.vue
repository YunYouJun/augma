<template>
  <agm-button icon @click="toggle" title="Fullscreen">
    <agm-icon :icon="icon" color="black" />
  </agm-button>
</template>

<script lang="ts">
import { useFullscreen } from "@vueuse/core";
import { computed } from "vue";
export default {
  data() {
    return {
      fullscreen: document.fullscreenElement,
    };
  },
  setup() {
    const { isFullscreen, toggle } = useFullscreen();

    const icon = computed(() => {
      return isFullscreen.value ? "mdi:fullscreen-exit" : "mdi:fullscreen";
    });

    return {
      icon,
      toggle,
    };
  },
  mounted() {
    document.onfullscreenchange = () => {
      this.fullscreen = document.fullscreenElement;
    };
  },
};
</script>
