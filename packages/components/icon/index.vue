<template>
  <div class="agm-icon" :style="styles">
    <span v-if="icon" class="iconify" :data-icon="icon"></span>
    <span v-else v-html="svg"></span>
  </div>
</template>

<script lang="ts">
import "./index.scss";
import { computed, defineComponent } from "vue";
import { getAgmColorByType } from "@augma/shared";

export default defineComponent({
  name: "AgmIcon",
  props: {
    icon: {
      type: String,
      default: "",
    },
    color: {
      type: String,
      default: "",
    },
    size: {
      type: String,
      default: "1.5rem",
    },
    svg: String,
  },
  setup(props) {
    const styles = computed(() => {
      return {
        color: getAgmColorByType(props.color) || "inherit",
        fontSize: props.size,
      };
    });

    return {
      styles,
    };
  },
});
</script>
