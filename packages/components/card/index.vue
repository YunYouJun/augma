<template>
  <div :class="classes" :style="styles">
    <div class="agm-card--header">
      <slot name="header"></slot>
    </div>
    <div class="agm-card--body">
      <slot></slot>
    </div>
  </div>
</template>

<script>
import "./index.scss";
export default {
  name: "AgmCard",
  props: {
    color: {
      type: String,
      default: "",
    },
    dark: {
      type: Boolean,
      default: false,
    },
    type: {
      type: String,
      default: "",
    },
  },
  computed: {
    classes() {
      return [
        "agm-card",
        this.type ? `agm-card--${this.type}` : "",
        this.dark ? "is-dark" : "",
      ];
    },
  },
};
</script>

