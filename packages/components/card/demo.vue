<template>
  <agm-card v-for="(type, i) in types" :key="i" :type="type">
    <template #header>
      {{ type }}
    </template>
    Card
  </agm-card>
</template>

<script>
import { AgmTypeMap } from '@augma/shared'
import AgmCard from './index.vue'
export default {
  components: {
    AgmCard,
  },
  setup() {
    return {
      types: AgmTypeMap,
    }
  },
}
</script>
