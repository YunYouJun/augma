<template>
  <agm-menu v-model="open">
    <template v-slot:activator>
      <agm-button icon @click="handleClick">
        <agm-icon :icon="icon"></agm-icon>
      </agm-button>
    </template>
    <fullscreen-btn></fullscreen-btn>
    <agm-button
      v-for="(item, i) in menuItems"
      :key="i"
      icon
      :color="item.color"
      @click="item.do"
    >
      <agm-icon v-if="item.icon" :icon="item.icon" />
    </agm-button>
  </agm-menu>
</template>

<script>
import FullscreenBtn from "./FullscreenBtn.vue";
import {
  mdiCameraFlip,
  mdiDotsHorizontal,
  mdiDotsVertical,
  mdiFullscreen,
} from "@mdi/js";
export default {
  components: {
    FullscreenBtn,
  },
  data() {
    return {
      open: false,

      menuItems: [
        {
          color: "#4dade0",
          icon: mdiCameraFlip,
          do: this.toggleCameraFront,
        },
      ],
    };
  },
  computed: {
    icon() {
      return this.open ? mdiDotsVertical : mdiDotsHorizontal;
    },
  },
  methods: {
    handleClick() {
      this.open = !this.open;
    },
    toggleCameraFront() {
      this.$store.commit("camera/toggleFront");
    },
  },
};
</script>
