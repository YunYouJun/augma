<script setup lang="ts">
defineEmits<{ command: [command: 'map' | 'scan' | 'audio' | 'hide'] }>()
const commands = [
  { id: 'map', label: '打开地图' },
  { id: 'scan', label: '扫描空间' },
  { id: 'audio', label: '播放声音' },
  { id: 'hide', label: '隐藏 HUD' },
] as const
</script>

<template>
  <div class="command-panel"><p>点击一条指令，模拟语音操作。</p><button v-for="command in commands" :key="command.id" type="button" @click="$emit('command', command.id)">{{ command.label }}</button><small>此演示不会请求麦克风权限。</small></div>
</template>

<style scoped>
.command-panel { display: grid; gap: 12px; }
.command-panel p { font-size: 13px; margin: 0 0 8px; }
.command-panel button { text-align: left; border: 0; background: rgb(255 255 255 / 12%); color: white; min-height: 44px; padding: 12px; border-radius: 3px; cursor: pointer; }
.command-panel button:hover { background: rgb(255 255 255 / 25%); }
.command-panel small { font-size: 11px; color: var(--agm-muted); margin-top: 10px; }
</style>
