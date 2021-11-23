<template>
  <div
    class="agm-select-dropdown"
    :style="{
      minWidth: minWidth,
    }"
  >
    <slot></slot>
  </div>
</template>

<script lang="ts">
import { defineComponent } from 'vue'
export default defineComponent({
  name: 'AgmSelectDropdown',
  props: {
    minWidth: String,
  },
  setup() {},
})
</script>

<style lang="scss">
.agm-select-dropdown {
  display: block;
  box-shadow: 0 0 5px rgba(0, 0, 0, 0.15);

  background: rgba(white, 0.95);
}
</style>
