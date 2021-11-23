<template>
  <div>
    <agm-menu v-model="open">
      <template #activator>
        <agm-button icon>
          <agm-icon v-if="open" icon="mdi:dots-vertical" color="black" />
          <agm-icon v-else icon="mdi:dots-horizontal" color="black" />
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
  </div>
</template>

<script lang="ts">
import { defineComponent } from 'vue'
import FullscreenBtn from './FullscreenBtn.vue'

export default defineComponent({
  components: {
    FullscreenBtn,
  },
  data() {
    return {
      open: false,
      menuItems: [
        {
          color: '#4dade0',
          icon: 'mdi:camera-flip',
          do: this.toggleCameraFront,
        },
      ],
    }
  },
  methods: {
    toggleCameraFront() {
      this.$store.commit('camera/toggleFront')
    },
  },
})
</script>
