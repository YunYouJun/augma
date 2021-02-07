<template>
  <agm-card v-for="(type, i) in types" :key="i" :type="type">
    <template #header> {{ type }} </template>
    嘿嘿嘿
  </agm-card>
</template>

<script>
import AgmCard from "./index.vue";
export default {
  components: {
    AgmCard,
  },
  setup() {
    const types = [
      "default",
      "primary",
      "success",
      "warning",
      "danger",
      "info",
    ];
    return {
      types,
    };
  },
};
</script>
