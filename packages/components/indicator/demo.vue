<script lang="ts" setup>
import { AgmTypeMap } from '@augma/utils'
import AgmIndicator from './src/index.vue'
</script>

<template>
  <AgmIndicator
    v-for="(type, i) in AgmTypeMap"
    :key="i"
    :color="type"
    :info="i.toString()"
  />
</template>
