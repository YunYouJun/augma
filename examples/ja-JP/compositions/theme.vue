<script setup lang="ts">
import { AgmButton, AgmHudProgress, AgmPanel } from 'augma'
import { shallowRef } from 'vue'

const value = shallowRef(25)
</script>

<template>
  <AgmPanel title="アクセントカラーのカスタマイズ" class="theme-example">
    <AgmHudProgress label="サンプルの進捗" :value="value" />
    <AgmButton @click="value = value >= 100 ? 0 : value + 25">
      進捗を進める
    </AgmButton>
    <p>セマンティック変数で色をカスタマイズしても、コンポーネントの構造とキーボード操作はそのままです。</p>
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
