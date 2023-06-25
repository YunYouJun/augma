<script lang="ts" setup>
import { onMounted } from 'vue'

const auxiliaryColors = [
  {
    name: 'brand',
    value: '',
  },
  {
    name: 'success',
    value: '',
  },
  {
    name: 'warning',
    value: '',
  },
  {
    name: 'danger',
    value: '',
  },
  {
    name: 'info',
    value: '',
  },
  {
    name: 'tooltip',
    value: '',
  },
]

onMounted(() => {
  auxiliaryColors.forEach((color) => {
    color.value = getComputedStyle(document.documentElement).getPropertyValue(
      `--agm-${color.name}`,
    )
  })
})
</script>

<template>
  <div class="demo-color-box-group">
    <div
      v-for="color in auxiliaryColors"
      class="demo-color-box demo-color-box-other demo-color-box-lite"
      :style="{ background: color.value }"
    >
      <div class="name capitalize">
        {{ color.name }}
      </div>
      <div class="value uppercase">
        {{ color.value }}
      </div>
    </div>
  </div>
</template>
