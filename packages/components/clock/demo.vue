<template>
  <agm-clock
    v-for="(type, i) in AgmTypeMap"
    :key="i"
    :color="type"
    style="margin: 1rem"
  />
  <hr style="opacity: 0.1; margin: 1rem">
  <agm-clock
    v-for="(type, i) in AgmTypeMap"
    :key="i"
    :color="type"
    :add-zero="false"
    style="margin: 1rem"
  />
</template>

<script lang="ts" setup>
import { AgmTypeMap } from '@augma/shared'
import AgmClock from './src/index.vue'
</script>
