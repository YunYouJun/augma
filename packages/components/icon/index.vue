<template>
  <div class="agm-icon" :style="styles">
    <span class="iconify" :data-icon="icon"></span>
  </div>
</template>

<script lang="ts">
import "./index.scss";
import { computed, defineComponent } from "vue";

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
  },
  setup(props) {
    const styles = computed(() => {
      return {
        color: props.color,
        fontSize: props.size,
      };
    });

    return {
      styles,
    };
  },
});
</script>
