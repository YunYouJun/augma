<template>
  <agm-indicator
    v-for="(type, i) in AgmTypeMap"
    :key="i"
    :color="type"
    :info="i.toString()"
  />
</template>

<script lang="ts">
import { AgmTypeMap } from "@augma/shared";
import { defineComponent } from "vue";
import AgmIndicator from "./index.vue";

export default defineComponent({
  components: {
    AgmIndicator,
  },
  data() {
    return {
      AgmTypeMap,
    };
  },
});
</script>
