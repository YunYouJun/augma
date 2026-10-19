<script setup lang="ts">
import { AgmHudProgress, AgmHudStatus, AgmPanel } from 'augma'
</script>

<template>
  <AgmPanel title="ミッションの状態" class="hud-example">
    <div>
      <AgmHudStatus>UI の準備完了</AgmHudStatus>
      <AgmHudStatus tone="warning">許可待ち</AgmHudStatus>
      <AgmHudStatus tone="danger">デバイスがオフライン</AgmHudStatus>
    </div>
    <AgmHudProgress label="リソースの読み込み" :value="72" variant="ring" />
    <AgmHudProgress label="デバイスの接続待ち" indeterminate-text="処理中" />
    <p>サンプルの状態です。デバイスへのアクセスや権限の要求は行いません。</p>
  </AgmPanel>
</template>

<style scoped>
.hud-example {
  display: grid;
  justify-items: center;
  gap: 24px;
  width: 100%;
}
.hud-example > div:first-of-type {
  display: flex;
  flex-wrap: wrap;
  gap: 20px;
}
.hud-example > .agm-progress:not(.agm-progress--ring) {
  width: 100%;
}
p {
  color: var(--agm-muted);
  font-size: 13px;
}
</style>
