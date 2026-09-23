<script setup lang="ts">
import { AgmButton, AgmHudProgress, AgmPanel } from 'augma'
import { shallowRef } from 'vue'

const value = shallowRef(25)
</script>

<template>
  <AgmPanel title="自定义强调色" class="theme-example">
    <AgmHudProgress label="示例进度" :value="value" />
    <AgmButton @click="value = value >= 100 ? 0 : value + 25">
      推进进度
    </AgmButton>
    <p>通过语义变量定制颜色，保持组件结构与键盘行为。</p>
  </AgmPanel>
</template>

<style scoped>
.theme-example {
  --agm-accent: #7951bd;
  --agm-accent-hover: #65419e;
  --agm-on-accent: #fff;
  display: grid;
  gap: 20px;
  width: 100%;
  max-width: 420px;
}
p {
  color: var(--agm-muted);
  font-size: 13px;
}
</style>
