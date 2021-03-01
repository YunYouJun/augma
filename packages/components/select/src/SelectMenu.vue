<template>
  <div class="agm-select-dropdown">
    <slot></slot>
  </div>
</template>

<script lang="ts">
import { defineComponent } from "vue";
export default defineComponent({
  name: "AgmSelectDropdown",
  setup() {},
});
</script>

<style lang="scss">
.agm-select-dropdown {
  display: block;
  box-shadow: 0 0 5px rgba(0, 0, 0, 0.15);
  z-index: 99;
}
</style>
