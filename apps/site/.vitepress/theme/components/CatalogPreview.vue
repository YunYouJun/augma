<script setup lang="ts">
import { AgmButton, AgmHudProgress, AgmHudStatus, AgmIconButton, AgmInput, AgmPanel, AgmSlider, AgmSwitch } from 'augma'

defineProps<{ name: string }>()
</script>

<template>
  <div class="catalog-preview" aria-hidden="true" inert>
    <AgmButton v-if="name === 'button'">开始连接</AgmButton>
    <div v-else-if="name === 'icon-button'" class="preview-row">
      <AgmIconButton label="添加" />
      <AgmIconButton label="已选中" pressed />
    </div>
    <AgmInput v-else-if="name === 'input'" label="设备名称" model-value="Augma" tabindex="-1" />
    <div v-else-if="name === 'select'" class="agm-field">
      <span class="agm-field-label">显示模式</span>
      <span class="agm-select">探索模式 <span>⌄</span></span>
    </div>
    <AgmSwitch v-else-if="name === 'switch'" label="显示 HUD" :model-value="true" />
    <AgmSlider v-else-if="name === 'slider'" label="界面不透明度" :model-value="72" />
    <div v-else-if="name === 'dialog'" class="preview-dialog">
      <strong>调整界面</strong>
      <span>将信息留在舒适的视野中。</span>
      <span class="preview-dialog-action">保存设置</span>
    </div>
    <div v-else-if="name === 'tooltip'" class="preview-tooltip">
      <span class="agm-tooltip">恢复默认的显示参数</span>
      <AgmIconButton label="恢复默认" />
    </div>
    <div v-else-if="name === 'toast'" class="agm-toast preview-toast">
      <strong class="agm-toast-title">设置已保存</strong>
      <span class="agm-toast-description">新的显示偏好已生效。</span>
    </div>
    <AgmPanel v-else-if="name === 'panel'" class="preview-panel">
      <strong>设备概览</strong>
      <AgmHudStatus>设备已连接</AgmHudStatus>
    </AgmPanel>
    <div v-else-if="name === 'hud-status'" class="preview-statuses">
      <AgmHudStatus>已连接</AgmHudStatus>
      <AgmHudStatus tone="warning">等待连接</AgmHudStatus>
      <AgmHudStatus tone="danger">连接中断</AgmHudStatus>
    </div>
    <AgmHudProgress v-else-if="name === 'hud-progress'" label="同步进度" :value="72" variant="ring" />
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
</style>
