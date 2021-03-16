<template>
  <div>
    <agm-menu v-model="open">
      <template #activator>
        <agm-button icon>
          <agm-icon icon="mdi:dots-vertical" color="black" v-if="open" />
          <agm-icon icon="mdi:dots-horizontal" color="black" v-else />
        </agm-button>
      </template>
      <fullscreen-btn></fullscreen-btn>
      <agm-button
        v-for="(item, i) in menuItems"
        :key="i"
        icon
        @click="item.do"
        :color="item.color"
      >
        <agm-icon v-if="item.icon" :icon="item.icon" />
      </agm-button>
    </agm-menu>
  </div>
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
