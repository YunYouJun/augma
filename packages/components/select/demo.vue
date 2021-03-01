<template>
  <agm-select :options="options" placeholder="Placeholder"></agm-select>
</template>

<script lang="ts">
import AgmSelect from "./index.vue";
import { defineComponent } from "vue";
export default defineComponent({
  components: {
    AgmSelect,
  },
  data() {
    return {
      options: [
        {
          label: "Label A",
          value: "A",
        },
        {
          label: "Label B",
          value: "B",
        },
        {
          label: "Label C",
          value: "C",
        },
      ],
    };
  },
});
</script>
