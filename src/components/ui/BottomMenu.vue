<template>
  <agm-bottom-menu :menuItems="menuItems" />
</template>

<script>
import {
  mdiGithub,
  mdiEarth,
  mdiFlipHorizontal,
  mdiMap,
  mdiEye,
  mdiCamera,
  mdiCameraFlip,
  mdiFace,
  mdiCubeScan,
  mdiWeatherCloudy,
} from "@mdi/js";
import pkg from "../../../package.json";
export default {
  data() {
    return {
      mode: "use",
      browser: false,
      icons: {
        mdiCamera,
        mdiCameraFlip,
        mdiFlipHorizontal,
      },
      menuItems: [
        { color: "#8dd3d6", icon: mdiFlipHorizontal, do: this.flipScreen },
        {
          color: "var(--agm-warning)",
          icon: mdiWeatherCloudy,
          do: this.toggleWeather,
        },
        {
          color: "#4dade0",
          icon: mdiEye,
          do: this.toggleCameraDisplay,
        },
        {
          color: "var(--agm-info)",
          icon: mdiFace,
          do: this.toggleFaceDetection,
        },
        {
          color: "var(--agm-tooltip)",
          icon: mdiCubeScan,
          do: this.toggleYolo,
        },
        {
          color: "#4dade0",
          icon: mdiCamera,
          do: this.screenshot,
        },
        {
          color: "#dd9d5e",
          icon: mdiMap,
          do: this.toggleSubwayMap,
        },

        {
          color: "black",
          icon: mdiGithub,
          do: this.openGithubNotification,
        },
        {
          color: "#4dade0",
          icon: mdiEarth,
          do: this.openBrowser,
        },
      ],
    };
  },
  mounted() {
    if (this.mode === "demo") {
      this.show();
    }
  },
  methods: {
    /**
     * show effect
     */
    show() {
      this.openGithubNotification();
    },
    screenshot() {
      const video = this.$store.state.camera.videoEl;
      if (!video) {
        console.error("No camera is opened.");
        return;
      }
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
    toggleFaceDetection() {
      this.$store.commit("faceApi/toggleFaceDetection");
    },
    toggleYolo() {
      this.$store.commit("app/toggleYolo");
    },
    toggleWeather() {
      this.$store.commit("app/toggleWeather");
    },
    toggleSubwayMap() {
      this.$store.commit("app/toggleSubwayMap");
    },
    toggleCameraDisplay() {
      this.$store.commit("camera/toggleDisplay");
    },

    openGithubNotification() {
      this.$notify({
        title: "GitHub",
        icon: mdiGithub,
        color: "black",
        message: `<a href="${pkg.repository}" target="_blank">${pkg.repository}</a>`,
        // showClose: true,
      });
    },
    openBrowser() {
      this.$store.commit("windows/toggleBrowser");
    },
  },
};
</script>
