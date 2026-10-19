<script setup lang="ts">
import { AgmButton, AgmHudProgress, AgmHudStatus, AgmPanel } from 'augma'
import { shallowRef } from 'vue'

const progress = shallowRef(72)
</script>

<template>
  <AgmPanel title="Device overview" description="Check the sync status and update the progress." style="width: 100%; max-width: 400px">
    <template #actions>
      <AgmHudStatus :tone="progress === 100 ? 'success' : 'neutral'">{{ progress === 100 ? 'Synced' : 'Not synced' }}</AgmHudStatus>
    </template>
    <AgmHudProgress label="Sample progress" :value="progress" />
    <template #footer>
      <AgmButton variant="ghost" :disabled="progress === 72" @click="progress = 72">Reset</AgmButton>
      <AgmButton :disabled="progress === 100" @click="progress = 100">Finish sync</AgmButton>
    </template>
  </AgmPanel>
</template>
