<template>
  <agm-clock
    v-for="(type, i) in AgmTypeMap"
    :key="i"
    :color="type"
    style="margin: 1rem"
  />
  <hr style="opacity: 0.1; margin: 1rem" />
  <agm-clock
    v-for="(type, i) in AgmTypeMap"
    :key="i"
    :color="type"
    :addZero="false"
    style="margin: 1rem"
  />
</template>

<script lang="ts">
import { defineComponent } from "vue";
import { AgmTypeMap } from "@augma/shared";
import AgmClock from "./index.vue";
export default defineComponent({
  components: {
    AgmClock,
  },
  setup() {
    return {
      AgmTypeMap,
    };
  },
});
</script>
