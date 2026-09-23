<script setup lang="ts">
import { AgmInput } from 'augma'
import { shallowRef } from 'vue'

const name = shallowRef('Augma')
</script>

<template>
  <div class="example-stack">
    <AgmInput
      v-model="name"
      label="设备名称"
      placeholder="输入设备名称"
      :error="name.trim() ? undefined : '请输入设备名称'"
    />
    <AgmInput label="设备编号" model-value="AGM-001" disabled />
    <output>当前名称：{{ name || '未填写' }}</output>
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
