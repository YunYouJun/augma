<script setup lang="ts">
import { onMounted, useTemplateRef } from 'vue'
import DeviceIcon from './DeviceIcon.vue'

defineProps<{ title: string, app: string }>()
const emit = defineEmits<{ close: [] }>()
const windowRef = useTemplateRef<HTMLElement>('window')
onMounted(() => windowRef.value?.focus({ preventScroll: true }))
</script>

<template>
  <section ref="window" class="device-window" :class="`device-window--${app}`" :aria-label="title" tabindex="-1" @keydown.esc.stop="emit('close')">
    <header class="window-heading"><h2>{{ title }}</h2><button class="window-close" type="button" :aria-label="`关闭${title}`" @click="emit('close')"><DeviceIcon name="close" /></button></header>
    <div class="window-content"><slot /></div>
  </section>
</template>

<style scoped>
.device-window { position: absolute; z-index: 5; top: 16px; left: 50%; transform: translateX(var(--window-center, -50%)); width: min(400px, calc(100% - 32px)); max-height: calc(100% - 32px); display: flex; flex-direction: column; color: var(--agm-text); background: var(--device-panel); border-radius: 3px; box-shadow: 0 0 5px rgb(0 0 0 / 10%); backdrop-filter: blur(8px); outline: 0; }
.window-heading { display: flex; align-items: center; gap: 12px; min-height: 46px; padding: 4px 8px 4px 20px; flex-shrink: 0; }
.window-heading h2 { margin: 0; font-size: 15px; font-weight: 500; flex: 1; }
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
.device-window--weather .window-close { opacity: 0; }
.device-window--weather:hover .window-close, .device-window--weather:focus-within .window-close { opacity: 1; }
.device-window--weather .window-content { padding: 16px; }
@media (max-width: 600px) {
  .device-window--space { right: 16px; width: min(320px, calc(100% - 32px)); top: 150px; max-height: calc(100% - 164px); }
  .device-window--navigation { right: 12px; top: 150px; width: min(264px, calc(100% - 70px)); max-height: calc(100% - 164px); }
}
</style>
