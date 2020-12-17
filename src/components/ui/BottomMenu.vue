<template>
  <div class="augma-bottom-menu">
    <div class="agm-bottom-menu">
      <div class="down-arrow"></div>
      <div class="agm-menu-container">
        <agm-button icon color="#8dd3d6" @click="flipScreen">
          <agm-icon :icon="icons.mdiFlipHorizontal"></agm-icon>
        </agm-button>
        <agm-button
          v-for="(item, i) in menuItems"
          :key="i"
          icon
          :color="item.color"
          @click="item.do"
        >
          <agm-icon v-if="item.icon" :icon="item.icon" />
        </agm-button>
      </div>
    </div>
  </div>
</template>

<script>
import AgmButton from "../button/index.vue";
import AgmIcon from "../icon/index.vue";
import {
  mdiGithub,
  mdiEarth,
  mdiFlipHorizontal,
  mdiMap,
  mdiEye,
  mdiCamera,
  mdiCameraFlip,
} from "@mdi/js";
import pkg from "../../../package.json";
export default {
  components: {
    AgmButton,
    AgmIcon,
  },
  data() {
    return {
      icons: {
        mdiCamera,
        mdiCameraFlip,
        mdiFlipHorizontal,
      },
      menuItems: [
        {
          color: "#4dade0",
          icon: mdiEye,
          do: this.toggleCameraDisplay,
        },
        {
          color: "#4dade0",
          icon: mdiCamera,
          do: this.screenshot,
        },
        {
          color: "#dd9d5e",
          icon: mdiMap,
        },
        {
          color: "#4dade0",
          icon: mdiCameraFlip,
          do: this.toggleCameraFront,
        },
        {
          color: "black",
          icon: mdiGithub,
          do: this.goToGithub,
        },
        {
          color: "#4dade0",
          icon: mdiEarth,
          do: this.openBrowser,
        },
      ],
    };
  },
  methods: {
    screenshot() {
      const video = this.$store.state.camera.videoEl;
      const canvas = document.createElement("canvas");
      // canvas.width = video.clientWidth;
      // canvas.height = video.clientHeight;
      const settings = this.$store.state.camera.settings;
      canvas.width = settings.width;
      canvas.height = settings.height;
      const ctx = canvas.getContext("2d");
      ctx.drawImage(video, 0, 0);

      const dataUrl = canvas.toDataURL();
      const link = document.createElement("a");
      link.href = dataUrl;
      link.download = new Date();
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    },
    flipScreen() {
      this.$store.commit("camera/toggleFlipScreen");
    },
    toggleCameraDisplay() {
      this.$store.commit("camera/toggleDisplay");
    },
    toggleCameraFront() {
      this.$store.commit("camera/toggleFront");
    },
    goToGithub() {
      window.open(pkg.repository, "_blank");
    },
    openBrowser() {
      console.log("open!!!");
    },
  },
};
</script>

<style lang="scss">
$bottom-nav-color: white;

.augma-bottom-menu {
  width: 100%;
  margin: 0 auto;
}

.agm-bottom-menu {
  display: inline-flex;
  height: 2rem;
  min-width: 20rem;
  padding: 1rem 3rem;
  border-top: 2px solid $bottom-nav-color;
}

.down-arrow {
  position: absolute;
  margin: 0 auto;
  top: 0;
  left: 0;
  right: 0;
  width: 0;
  height: 0;
  border: 10px solid $bottom-nav-color;
  border-color: $bottom-nav-color transparent transparent transparent;
}

.agm-menu-container {
  display: flex;
  margin: 0 auto;
  gap: 1.5rem;
}
</style>
