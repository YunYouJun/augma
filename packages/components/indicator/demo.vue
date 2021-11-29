<template>
  <agm-indicator
    v-for="(type, i) in AgmTypeMap"
    :key="i"
    :color="type"
    :info="i.toString()"
  />
</template>

<script lang="ts" setup>
import { AgmTypeMap } from '@augma/shared'
import AgmIndicator from './src/index.vue'
</script>
