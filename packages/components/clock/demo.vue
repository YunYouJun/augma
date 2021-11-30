<template>
  <agm-clock class="mx-2" />
  <agm-clock
    v-for="(color, i) in agmColors"
    :key="i"
    :color="color"
    class="mx-2"
  />
  <hr class="my-4 opacity-20">
  <agm-clock class="mx-2" :add-zero="false" />
  <agm-clock
    v-for="(color, i) in agmColors"
    :key="i"
    :color="color"
    :add-zero="false"
    class="mx-2"
  />
</template>

<script lang="ts" setup>
import { AgmTypeMap } from '@augma/shared'
import { agmColors } from 'augma'
import AgmClock from './src/index.vue'
</script>
