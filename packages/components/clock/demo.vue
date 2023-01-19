<script lang="ts" setup>
import { AgmTypeMap } from '@augma/shared'
import { agmColors } from 'augma'
import AgmClock from './src/index.vue'
</script>

<template>
  <AgmClock class="mx-2" />
  <AgmClock
    v-for="(color, i) in agmColors"
    :key="i"
    :color="color"
    class="mx-2"
  />
  <hr class="my-4 opacity-20">
  <AgmClock class="mx-2" :add-zero="false" />
  <AgmClock
    v-for="(color, i) in agmColors"
    :key="i"
    :color="color"
    :add-zero="false"
    class="mx-2"
  />
</template>
