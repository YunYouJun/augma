<script setup lang="ts">
import { AgmButton, AgmSelect } from 'augma'
import { shallowRef } from 'vue'

const mode = shallowRef('focus')
const destination = shallowRef<string>()
const submitted = shallowRef(false)
const options = [
  { label: '专注模式', value: 'focus' },
  { label: '探索模式', value: 'explore' },
  { label: '不可用模式', value: 'locked', disabled: true },
]
</script>

<template>
  <div class="example-stack">
    <AgmSelect v-model="mode" label="显示模式" hint="选择适合当前场景的信息密度。" :options="options" />
    <output>已选：{{ mode }}</output>
    <AgmSelect
      v-model="destination"
      label="启动模式"
      hint="启动前请选择一个可用模式。"
      :error="submitted && !destination ? '请选择启动模式' : undefined"
      :options="options"
      required
    />
    <AgmButton variant="outline" @click="submitted = true">确认启动模式</AgmButton>
    <output v-if="submitted && destination" role="status">启动模式已确认。</output>
    <AgmSelect label="不可用选择器" :options="options" disabled />
  </div>
</template>

<style scoped>
.example-stack {
  display: grid;
  gap: 24px;
  width: 100%;
  max-width: 360px;
}
</style>
