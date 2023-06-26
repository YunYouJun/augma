<script lang="ts" setup>
import { useCameraStore } from '~/stores/camera'
import { isDark, toggleDark } from '~/composables'

const camera = useCameraStore()

const open = ref(false)
const menuItems = computed(() => ([
  {
    color: '#4dade0',
    icon: 'i-mdi-camera-flip',
    do: camera.toggleFront,
  },
  {
    color: '#4dade0',
    icon: isDark.value ? 'i-ri-moon-line' : 'i-ri-sun-line',
    do: () => { 
      console.log('toggledark')
      toggleDark()
    },
  },
]))
</script>

<template>
  <div>
    <AgmMenu v-model="open">
      <template #activator>
        <AgmButton icon>
          <AgmIcon v-if="open" class="i-mdi-dots-vertical">
            <i-mdi-dots-vertical />
          </AgmIcon>
          <AgmIcon v-else icon="mdi:dots-horizontal">
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
        @click="() => { item.do() }"
      >
        <AgmIcon :name="item.icon" />
      </AgmButton>
    </AgmMenu>
  </div>
</template>
