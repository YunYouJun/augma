<script setup lang="ts">
import { AgmButton, AgmHudProgress, AgmHudStatus, AgmPanel, AgmSlider, AgmSwitch } from 'augma'
import { shallowRef } from 'vue'
import { useI18n } from '../i18n'

defineProps<{ theme: 'light' | 'dark', label: string }>()
const { t } = useI18n()
const visible = shallowRef(true)
const brightness = shallowRef(72)

function reset() {
  visible.value = true
  brightness.value = 72
}
</script>

<template>
  <section class="theme-sample" :data-agm-theme="theme" :aria-label="t('theme.sample', { label })">
    <div class="theme-caption">
      <span>{{ label }}</span>
      <div class="theme-swatches" aria-hidden="true">
        <i v-for="token in ['accent', 'cyan', 'success', 'text']" :key="token" :style="{ background: `var(--agm-${token})` }" />
      </div>
    </div>
    <AgmPanel :title="t('theme.panelTitle')" :description="t('theme.panelDescription')">
      <div class="theme-controls">
        <div class="theme-overview">
          <AgmHudProgress v-if="visible" :label="t('theme.brightness')" :value="brightness" variant="ring" />
          <p v-else class="theme-hidden">{{ t('theme.hidden') }}</p>
          <AgmHudStatus :tone="visible ? 'success' : 'neutral'">{{ visible ? t('theme.on') : t('theme.off') }}</AgmHudStatus>
        </div>
        <AgmSwitch v-model="visible" :label="t('theme.show')" />
        <AgmSlider v-model="brightness" :label="t('device.brightness')" :min="20" :max="100" :disabled="!visible" />
      </div>
      <template #footer>
        <AgmButton variant="outline" :disabled="visible && brightness === 72" @click="reset">{{ t('preview.restore') }}</AgmButton>
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
