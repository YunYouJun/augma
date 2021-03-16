<template>
  <agm-bottom-menu :menuItems="menuItems" />
</template>

<script lang="ts">
import { defineComponent } from "vue";
import pkg from "../../../package.json";
export default defineComponent({
  data() {
    return {
      mode: "use",
      browser: false,
      menuItems: [
        { color: "#8dd3d6", icon: "mdi:flip-horizontal", do: this.flipScreen },
        {
          color: "var(--agm-warning)",
          icon: "mdi:weather-cloudy",
          do: this.toggleWeather,
        },
        {
          color: "#4dade0",
          icon: "mdi:eye",
          do: this.toggleCameraDisplay,
        },
        {
          color: "var(--agm-info)",
          icon: "mdi:face",
          do: this.toggleFaceDetection,
        },
        {
          color: "var(--agm-tooltip)",
          icon: "mdi:cube-scan",
          do: this.toggleYolo,
        },
        {
          color: "#4dade0",
          icon: "mdi:camera",
          do: this.screenshot,
        },
        {
          color: "#dd9d5e",
          icon: "mdi:map",
          do: this.toggleSubwayMap,
        },

        {
          color: "black",
          icon: "mdi:github",
          do: this.openGithubNotification,
        },
        {
          color: "#4dade0",
          icon: "mdi:earth",
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
      link.download = new Date().toString();
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
        icon: "mdi:github",
        color: "black",
        message: `<a href="${pkg.repository}" target="_blank">${pkg.repository}</a>`,
        // showClose: true,
      });
    },
    openBrowser() {
      this.$store.commit("windows/toggleBrowser");
    },
  },
});
</script>
