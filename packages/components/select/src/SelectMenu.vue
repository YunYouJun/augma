<script lang="ts" setup>
defineProps<{
  minWidth?: string
}>()
</script>

<template>
  <div
    class="agm-select-dropdown cursor-pointer"
    :style="{
      minWidth,
    }"
  >
    <slot />
  </div>
</template>

<style lang="scss">
.agm-select-dropdown {
  display: block;
  box-shadow: 0 0 5px rgba(0, 0, 0, 0.15);

  background: rgba(white, 0.95);
}
</style>
