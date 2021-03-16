<template>
  <agm-select
    v-model="currentOption"
    :options="options"
    placeholder="Placeholder"
    :callback="callback"
  ></agm-select>
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
      currentOption: {},
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
  methods: {
    callback(val: any) {
      console.log(val);
      console.log(this.currentOption);
    },
  },
});
</script>
