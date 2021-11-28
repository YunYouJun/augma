<template>
  <div>
    <AgmMenu v-model="open">
      <template #activator>
        <AgmButton icon>
          <AgmIcon v-if="open" icon="mdi:dots-vertical" color="black">
            <i-mdi-dots-vertical />
          </AgmIcon>
          <AgmIcon v-else icon="mdi:dots-horizontal" color="black">
            <i-mdi-dots-horizontal />
          </AgmIcon>
        </AgmButton>
      </template>
      <FullscreenBtn />
      <AgmButton
        v-for="(item, i) in menuItems"
        :key="i"
        icon
        :color="item.color"
        @click="item.do"
      >
        <AgmIcon v-if="item.icon" :icon="item.icon" />
      </AgmButton>
    </AgmMenu>
  </div>
</template>

<script lang="ts" setup>
import { useCameraStore } from '~/stores/camera'

import IconMdiCameraFlip from '~icons/mdi/camera-flip'

const camera = useCameraStore()

const open = ref(false)
const menuItems = [
  {
    color: '#4dade0',
    icon: IconMdiCameraFlip,
    do: camera.toggleFront,
  },
]
</script>
