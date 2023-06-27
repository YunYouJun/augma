<script lang="ts" setup>
import { useCameraStore } from '~/stores/camera'

const camera = useCameraStore()
</script>

<template>
  <WebCam
    v-if="camera.display"
    :is-flip="camera.flipScreen"
    :is-front="camera.front"
  />
  <AgmBabylon />
  <AugmaUi :opacity="0.95" />
</template>
