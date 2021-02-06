<template>
  <div class="agm-card" :style="styles">
    <slot></slot>
  </div>
</template>

<script>
export default {
  name: "AgmCard",
  props: {
    color: {
      type: String,
      default: "white",
    },
    dark: {
      type: Boolean,
      default: false,
    },
  },
  computed: {
    styles() {
      return {
        backgroundColor: this.color,
        color: this.dark ? "white" : "black",
      };
    },
  },
};
</script>

<style lang="scss">
.agm-card {
  display: inline-flex;
  min-width: 12rem;
  border-radius: 0.5rem;
  box-shadow: 0 0 5px rgba(0, 0, 0, 0.2);
  overflow: hidden;
}
</style>
