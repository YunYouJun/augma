<script setup lang="ts">
import { AgmButton, AgmHudGauge, AgmHudProgress, AgmHudStatus, AgmIconButton, AgmInput, AgmPanel, AgmSlider, AgmSwitch } from 'augma'

import { useI18n } from '../i18n'

defineProps<{ name: string }>()
const { t } = useI18n()
</script>

<template>
  <div class="catalog-preview" aria-hidden="true" inert>
    <AgmButton v-if="name === 'button'">{{ t('preview.connect') }}</AgmButton>
    <div v-else-if="name === 'icon-button'" class="preview-row">
      <AgmIconButton :label="t('preview.add')" />
      <AgmIconButton :label="t('preview.selected')" pressed />
    </div>
    <AgmInput v-else-if="name === 'input'" :label="t('preview.deviceName')" model-value="Augma" tabindex="-1" />
    <div v-else-if="name === 'select'" class="agm-field">
      <span class="agm-field-label">{{ t('preview.displayMode') }}</span>
      <span class="agm-select">{{ t('preview.explore') }} <span>⌄</span></span>
    </div>
    <AgmSwitch v-else-if="name === 'switch'" :label="t('preview.showHud')" :model-value="true" />
    <AgmSlider v-else-if="name === 'slider'" :label="t('preview.opacity')" :model-value="72" />
    <div v-else-if="name === 'dialog'" class="preview-dialog">
      <strong>{{ t('device.adjust') }}</strong>
      <span>{{ t('preview.dialogText') }}</span>
      <span class="preview-dialog-action">{{ t('preview.save') }}</span>
    </div>
    <div v-else-if="name === 'tooltip'" class="preview-tooltip">
      <span class="agm-tooltip">{{ t('preview.restoreHint') }}</span>
      <AgmIconButton :label="t('preview.restore')" />
    </div>
    <div v-else-if="name === 'toast'" class="agm-toast preview-toast">
      <strong class="agm-toast-title">{{ t('preview.saved') }}</strong>
      <span class="agm-toast-description">{{ t('preview.savedDescription') }}</span>
    </div>
    <AgmPanel v-else-if="name === 'panel'" class="preview-panel">
      <strong>{{ t('preview.overview') }}</strong>
      <AgmHudStatus>{{ t('preview.deviceConnected') }}</AgmHudStatus>
    </AgmPanel>
    <div v-else-if="name === 'hud-status'" class="preview-statuses">
      <AgmHudStatus>{{ t('preview.connected') }}</AgmHudStatus>
      <AgmHudStatus tone="warning">{{ t('preview.waiting') }}</AgmHudStatus>
      <AgmHudStatus tone="danger">{{ t('preview.lost') }}</AgmHudStatus>
    </div>
    <AgmHudProgress v-else-if="name === 'hud-progress'" :label="t('preview.sync')" :value="72" variant="ring" />
    <div v-else-if="name === 'hud-gauge'" class="preview-gauges">
      <AgmHudGauge :label="t('preview.battery')" :value="86" />
      <AgmHudGauge :label="t('preview.storage')" :value="12" :max="64" />
    </div>
  </div>
</template>

<style scoped>
.catalog-preview { min-height: 164px; display: flex; align-items: center; justify-content: center; padding: 24px; background: var(--agm-surface); pointer-events: none; }
.catalog-preview > .agm-field, .catalog-preview > .agm-switch-field { width: 100%; max-width: 240px; }
.preview-row { display: flex; gap: 20px; }
.preview-dialog { display: grid; gap: 8px; width: 240px; padding: 16px; border: 1px solid var(--agm-border); border-top: 2px solid var(--agm-accent); background: var(--agm-bg); }
.preview-dialog strong, .preview-panel strong { font-size: 14px; font-weight: 500; }
.preview-dialog > span { font-size: 12px; color: var(--agm-muted); }
.preview-dialog .preview-dialog-action { text-align: right; color: var(--agm-accent); margin-top: 8px; }
.preview-tooltip { display: grid; justify-items: center; gap: 12px; }
.preview-toast { padding: 16px 20px; display: grid; width: 240px; box-shadow: none; }
.preview-toast .agm-toast-description { font-size: 12px; }
.preview-panel { width: 240px; display: grid; gap: 16px; padding: 20px; box-shadow: none; }
.preview-statuses { display: grid; gap: 10px; }
.catalog-preview > .agm-progress--ring { width: 110px; }
.preview-gauges { display: grid; gap: 14px; width: 100%; max-width: 240px; }
</style>
