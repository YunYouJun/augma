<template>
  <div id="augma-ui" class="augma-ui" :style="styles">
    <system-bar />
    <agm-window />
    <bottom-menu id="augma-bottom-menu" />
  </div>
</template>

<script>
import AgmWindow from "./ui/AgmWindow.vue";
import SystemBar from "./ui/SystemBar.vue";
import BottomMenu from "./ui/BottomMenu.vue";
export default {
  components: {
    AgmWindow,
    BottomMenu,
    SystemBar,
  },
  props: {
    opacity: Number,
  },
  computed: {
    styles() {
      return {
        opacity: this.opacity,
      };
    },
  },
};
</script>

<style lang="scss">
.augma-ui {
  position: fixed;
  text-align: center;
  left: 0;
  top: 0;
  width: 100vw;
  height: 100vh;
  background: rgba(255, 255, 255, 0.1);
}

#augma-bottom-menu {
  position: absolute;
  bottom: 1.5rem;
}
</style>
