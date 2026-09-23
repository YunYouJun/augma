<script setup lang="ts">
import { AgmButton, AgmDialog, AgmInput, AgmSelect } from 'augma'
import { shallowRef } from 'vue'

const open = shallowRef(false)
const name = shallowRef('Augma')
const mode = shallowRef('focus')
</script>

<template>
  <AgmDialog
    v-model:open="open"
    title="设备设置"
    description="调整设备名称，关闭后继续浏览。"
  >
    <template #trigger>
      <AgmButton variant="outline">打开设置</AgmButton>
    </template>
    <div class="example-stack">
      <AgmInput v-model="name" label="设备名称" />
      <AgmSelect v-model="mode" label="显示模式" :options="[{ label: '专注', value: 'focus' }, { label: '探索', value: 'explore' }]" />
    </div>
    <template #footer>
      <AgmButton @click="open = false">完成</AgmButton>
    </template>
  </AgmDialog>
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
