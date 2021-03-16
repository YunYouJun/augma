<template>
  <agm-menu v-model="open">
    <template #activator>
      <agm-button icon>
        <agm-icon icon="mdi:dots-vertical" v-if="open" />
        <agm-icon icon="mdi:dots-horizontal" v-else />
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

<script lang="ts">
import FullscreenBtn from "./FullscreenBtn.vue";
import { defineComponent } from "vue";

export default defineComponent({
  components: {
    FullscreenBtn,
  },
  data() {
    return {
      open: false,
      menuItems: [
        {
          color: "#4dade0",
          icon: "mdi:camera-flip",
          do: this.toggleCameraFront,
        },
      ],
    };
  },
  methods: {
    toggleCameraFront() {
      this.$store.commit("camera/toggleFront");
    },
  },
});
</script>
