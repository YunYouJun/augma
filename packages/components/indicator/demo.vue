<template>
  <agm-indicator
    v-for="(type, i) in TypeMap"
    :key="i"
    :color="type"
    :info="i.toString()"
  />
</template>

<script lang="ts">
import { TypeMap } from "@augma/shared";
import { defineComponent } from "vue";
import AgmIndicator from "./index.vue";

export default defineComponent({
  components: {
    AgmIndicator,
  },
  data() {
    return {
      TypeMap,
    };
  },
});
</script>
