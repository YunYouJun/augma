<script setup lang="ts">
import { AgmButton, AgmHudStatus } from 'augma'
import { shallowRef } from 'vue'

const count = shallowRef(0)
</script>

<template>
  <div class="example-demo">
    <div class="example-row">
      <AgmButton @click="count++">デバイスを接続</AgmButton>
      <AgmButton variant="outline" @click="count++">サブアクション</AgmButton>
      <AgmButton variant="ghost" @click="count++">控えめなアクション</AgmButton>
      <AgmButton loading>読み込み中</AgmButton>
      <AgmButton disabled>使用不可</AgmButton>
    </div>
    <AgmHudStatus :tone="count ? 'success' : 'neutral'">
      <strong class="example-count">{{ count }}</strong> 回操作しました
    </AgmHudStatus>
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
/* The readout sits on its own line, so the button row never moves as the count grows. */
.example-demo {
  display: grid;
  justify-items: start;
  gap: 20px;
}
.example-count {
  color: var(--agm-text);
  font-variant-numeric: tabular-nums;
}
</style>
