<script setup lang="ts">
import { AgmSelect } from 'augma'
import { shallowRef } from 'vue'

const mode = shallowRef('focus')
const options = [
  { label: '专注模式', value: 'focus' },
  { label: '探索模式', value: 'explore' },
  { label: '不可用模式', value: 'locked', disabled: true },
]
</script>

<template>
  <div class="example-stack">
    <AgmSelect v-model="mode" label="显示模式" :options="options" />
    <output>已选：{{ mode }}</output>
    <AgmSelect label="不可用选择器" :options="options" disabled />
  </div>
</template>

<style scoped>
.example-row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 16px;
}
.example-stack {
  display: grid;
  gap: 24px;
  width: 100%;
  max-width: 360px;
}
</style>
