<script setup lang="ts">
import { AgmHudProgress, AgmSlider } from 'augma'
import { shallowRef } from 'vue'

const value = shallowRef(72)
</script>

<template>
  <div class="example-stack">
    <div class="example-row">
      <AgmHudProgress label="同期済み" :value="value" variant="ring" />
      <AgmHudProgress label="スキャン中" variant="ring" />
    </div>
    <AgmHudProgress label="データ同期" :value="value" />
    <AgmSlider v-model="value" label="サンプルの進捗を調整" />
    <AgmHudProgress label="接続中" indeterminate-text="処理中" />
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
