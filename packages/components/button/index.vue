<template>
  <button :class="classes" :style="styles">
    <slot></slot>
  </button>
</template>

<script lang="ts">
import { defineComponent } from "vue";
import "./index.scss";

export default defineComponent({
  name: "AgmButton",
  props: {
    color: String,
    icon: Boolean,
  },
  computed: {
    classes(): any {
      return {
        "agm-button": true,
        "agm-button--icon": this.icon,
      };
    },
    styles(): any {
      return {
        color: this.color,
      };
    },
  },
});
</script>
