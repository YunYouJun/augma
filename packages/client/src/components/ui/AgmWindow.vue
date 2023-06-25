<script setup lang="ts">
import { useAppStore } from '~/stores/app'

const app = useAppStore()
</script>

<template>
  <agm-weather v-if="app.weather" />
  <agm-dialog v-if="app.browser" v-model="app.browser">
    <iframe
      frameborder="0"
      src="https://docs.augma.elpsy.cn"
      width="100%"
      height="100%"
    />
  </agm-dialog>
  <agm-map :enable="app.subwayMap" />
</template>
