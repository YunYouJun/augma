<script lang="ts" setup>
import { ref } from 'vue'
import { AgmTypeMap } from '@augma/shared'
import AgmCard from './src/index.vue'

const types = ref(AgmTypeMap)
</script>

<template>
  <AgmCard v-for="(type, i) in types" :key="i" :type="type">
    <template #header>
      {{ type }}
    </template>
    Card
  </AgmCard>
</template>
