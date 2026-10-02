<script setup lang="ts">
import { AgmButton, AgmHudProgress, AgmHudStatus, AgmPanel } from 'augma'
import { shallowRef } from 'vue'

const progress = shallowRef(72)
</script>

<template>
  <AgmPanel title="设备概览" description="查看同步状态并调整当前进度。" style="width: 100%; max-width: 400px">
    <template #actions>
      <AgmHudStatus :tone="progress === 100 ? 'success' : 'neutral'">{{ progress === 100 ? '已同步' : '待同步' }}</AgmHudStatus>
    </template>
    <AgmHudProgress label="示例进度" :value="progress" />
    <template #footer>
      <AgmButton variant="ghost" :disabled="progress === 72" @click="progress = 72">重置</AgmButton>
      <AgmButton :disabled="progress === 100" @click="progress = 100">完成同步</AgmButton>
    </template>
  </AgmPanel>
</template>
