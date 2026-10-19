<script setup lang="ts">
import { AgmButton, AgmHudProgress, AgmHudStatus, AgmPanel } from 'augma'
import { shallowRef } from 'vue'

const progress = shallowRef(72)
</script>

<template>
  <AgmPanel title="デバイスの概要" description="同期の状態を確認し、進捗を更新します。" style="width: 100%; max-width: 400px">
    <template #actions>
      <AgmHudStatus :tone="progress === 100 ? 'success' : 'neutral'">{{ progress === 100 ? '同期済み' : '未同期' }}</AgmHudStatus>
    </template>
    <AgmHudProgress label="サンプルの進捗" :value="progress" />
    <template #footer>
      <AgmButton variant="ghost" :disabled="progress === 72" @click="progress = 72">リセット</AgmButton>
      <AgmButton :disabled="progress === 100" @click="progress = 100">同期を完了</AgmButton>
    </template>
  </AgmPanel>
</template>
