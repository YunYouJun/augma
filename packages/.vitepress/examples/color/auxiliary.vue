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
      :key="color.name"
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

<style lang="scss">
.demo-color-box {
  border-radius: 4px;
  padding: 20px;
  height: 5rem;
  box-sizing: border-box;
  color: #fff;
  font-size: 1rem;
  margin: 5px;
  box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
}

.demo-color-box-group {
  .demo-color-box {
    border-radius: 0;
    margin: 0 5px;
  }
  .demo-color-box:first-child {
    border-radius: 4px 4px 0 0;
  }
  .demo-color-box:last-child {
    border-radius: 0 0 4px 4px;
  }
}
</style>
