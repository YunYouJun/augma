<script setup lang="ts">
import { AgmButton, AgmHudProgress, AgmHudStatus, AgmPanel, AgmSlider, AgmSwitch } from 'augma'
import { shallowRef } from 'vue'

defineProps<{ theme: 'light' | 'dark', label: string }>()
const visible = shallowRef(true)
const brightness = shallowRef(72)

function reset() {
  visible.value = true
  brightness.value = 72
}
</script>

<template>
  <section class="theme-sample" :data-agm-theme="theme" :aria-label="`${label}主题示例`">
    <div class="theme-caption">
      <span>{{ label }}</span>
      <div class="theme-swatches" aria-hidden="true">
        <i v-for="token in ['accent', 'cyan', 'success', 'text']" :key="token" :style="{ background: `var(--agm-${token})` }" />
      </div>
    </div>
    <AgmPanel title="我的视界" description="让信息保持清晰，让操作足够轻。">
      <div class="theme-controls">
        <div class="theme-overview">
          <AgmHudProgress v-if="visible" label="界面亮度" :value="brightness" variant="ring" />
          <p v-else class="theme-hidden">HUD 已隐藏</p>
          <AgmHudStatus :tone="visible ? 'success' : 'neutral'">{{ visible ? '显示已开启' : '显示已关闭' }}</AgmHudStatus>
        </div>
        <AgmSwitch v-model="visible" label="显示界面" />
        <AgmSlider v-model="brightness" label="亮度" :min="20" :max="100" :disabled="!visible" />
      </div>
      <template #footer>
        <AgmButton variant="outline" :disabled="visible && brightness === 72" @click="reset">恢复默认</AgmButton>
      </template>
    </AgmPanel>
  </section>
</template>

<style scoped>
.theme-sample { min-width: 0; padding: 20px; background: var(--agm-surface); color: var(--agm-text); border: 1px solid var(--agm-border); border-radius: 4px; }
.theme-caption { display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px; font-size: 13px; font-weight: 500; }
.theme-swatches { display: flex; gap: 8px; }
.theme-swatches i { width: 12px; height: 12px; border-radius: 50%; }
.theme-sample .agm-panel { padding: 20px; box-shadow: none; }
.theme-controls { display: grid; gap: 12px; }
.theme-overview { display: grid; justify-items: center; gap: 16px; min-height: 165px; margin-bottom: 12px; }
.theme-hidden { display: grid; place-items: center; width: 132px; height: 132px; border: 1px dashed var(--agm-border); border-radius: 50%; color: var(--agm-muted); font-size: 13px; margin: 0 !important; }
</style>
