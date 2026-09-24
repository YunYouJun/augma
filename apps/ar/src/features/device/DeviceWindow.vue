<script setup lang="ts">
import { onMounted, toRef, useTemplateRef } from 'vue'
import DeviceIcon from './DeviceIcon.vue'
import { useWindowPlacement } from './useWindowPlacement'

const props = defineProps<{ title: string, app: string, resetVersion: number }>()
const emit = defineEmits<{ close: [] }>()
const windowRef = useTemplateRef<HTMLElement>('window')
const { position, style, reset, pointerDown, pointerMove, pointerUp, keyDown } = useWindowPlacement(props.app, windowRef, toRef(props, 'resetVersion'))
onMounted(() => windowRef.value?.focus({ preventScroll: true }))
</script>

<template>
  <section ref="window" class="device-window" :class="[`device-window--${app}`, { 'is-positioned': !!position }]" :style="style" :aria-label="title" tabindex="-1" @keydown.esc.stop="emit('close')">
    <header class="window-heading" tabindex="0" :aria-label="`移动${title}面板，方向键微调，按住 Shift 加速`" @pointerdown="pointerDown" @pointermove="pointerMove" @pointerup="pointerUp" @pointercancel="pointerUp" @keydown="keyDown">
      <h2>{{ title }}</h2><span class="window-drag-hint" aria-hidden="true">拖动</span>
      <button v-if="position" class="window-reset" type="button" :aria-label="`复位${title}面板位置`" @click="reset">复位</button>
      <button class="window-close" type="button" :aria-label="`关闭${title}`" @click="emit('close')"><DeviceIcon name="close" /></button>
    </header>
    <div class="window-content"><slot /></div>
  </section>
</template>

<style scoped>
.device-window { position: absolute; z-index: 5; top: 16px; left: 50%; transform: translateX(var(--window-center, -50%)); width: min(400px, calc(100% - 32px)); max-height: calc(100% - 32px); display: flex; flex-direction: column; color: var(--agm-text); background: var(--device-panel); border-radius: 3px; box-shadow: 0 0 5px rgb(0 0 0 / 10%); backdrop-filter: blur(8px); outline: 0; }
.window-heading { display: flex; align-items: center; gap: 8px; min-height: 46px; padding: 4px 8px 4px 20px; flex-shrink: 0; cursor: grab; touch-action: none; user-select: none; }
.window-heading:active { cursor: grabbing; }
.window-heading:focus-visible { outline: 2px solid var(--agm-accent); outline-offset: -3px; }
.window-heading h2 { margin: 0; font-size: 15px; font-weight: 500; flex: 1; }
.window-drag-hint, .window-reset { color: var(--agm-muted); font-size: 11px; white-space: nowrap; }
.window-drag-hint { pointer-events: none; }
.window-reset { padding: 6px; border: 0; border-radius: 3px; background: transparent; cursor: pointer; }
.window-reset:hover, .window-reset:focus-visible { color: white; background: rgb(255 255 255 / 12%); }
.window-close { width: 36px; height: 36px; display: grid; place-items: center; color: inherit; border: 0; background: transparent; border-radius: 50%; cursor: pointer; }
.window-close svg { width: 18px; height: 18px; }
.window-close:hover { background: rgb(255 255 255 / 12%); }
.window-content { padding: 0 20px 20px; overflow: auto; overscroll-behavior: contain; scrollbar-width: thin; scrollbar-color: #ccc transparent; }
.device-window--navigation { left: auto; right: 72px; --window-center: 0%; transform: none; width: 286px; background: transparent; box-shadow: none; backdrop-filter: none; }
.device-window--navigation .window-content { padding: 0; }
.device-window--navigation .window-heading { background: rgb(70 70 70 / 35%); }
.device-window--space { left: auto; right: 72px; --window-center: 0%; transform: none; width: 320px; }
.device-window--weather { top: 16px; background: rgb(255 255 255 / 2%); backdrop-filter: none; }
.device-window--weather .window-heading { position: absolute; right: 0; top: 0; min-height: 0; padding: 0; }
.device-window--weather .window-heading h2 { position: absolute; width: 1px; height: 1px; overflow: hidden; clip-path: inset(50%); }
.device-window--weather .window-heading .window-drag-hint { padding-left: 8px; }
.device-window--weather .window-close { opacity: 0; }
.device-window--weather:hover .window-close, .device-window--weather:focus-within .window-close { opacity: 1; }
.device-window--weather .window-content { padding: 16px; }
.device-window.is-positioned { right: auto; transform: none; }
@media (max-width: 600px) {
  .device-window--space { right: 16px; width: min(320px, calc(100% - 32px)); top: 150px; max-height: calc(100% - 164px); }
  .device-window--navigation { right: 12px; top: 150px; width: min(264px, calc(100% - 70px)); max-height: calc(100% - 164px); }
}
</style>
