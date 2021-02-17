<template>
  <agm-card v-for="(type, i) in types" :key="i" :type="type">
    <template #header> {{ type }} </template>
    Card
  </agm-card>
</template>

<script>
import { TypeMap } from "@augma/shared/src";
import AgmCard from "./index.vue";
export default {
  components: {
    AgmCard,
  },
  setup() {
    return {
      types: TypeMap,
    };
  },
};
</script>
