<script setup lang="ts">
import { AgmHudProgress, AgmHudStatus, AgmPanel } from 'augma'
</script>

<template>
  <AgmPanel title="任务状态" class="hud-example">
    <div>
      <AgmHudStatus>界面就绪</AgmHudStatus>
      <AgmHudStatus tone="warning">等待授权</AgmHudStatus>
      <AgmHudStatus tone="danger">设备离线</AgmHudStatus>
    </div>
    <AgmHudProgress label="资源加载" :value="72" variant="ring" />
    <AgmHudProgress label="等待设备连接" />
    <p>示例状态，不会访问设备或请求权限。</p>
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
