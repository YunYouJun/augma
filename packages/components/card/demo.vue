<script lang="ts" setup>
import { AgmTypeMap } from '@augma/utils'
import { ref } from 'vue'
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
