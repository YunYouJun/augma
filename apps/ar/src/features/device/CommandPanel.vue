<script setup lang="ts">
import type { VoiceCommand } from './voiceCommands'
import { ref } from 'vue'

defineProps<{
  speechAvailable: boolean
  cloudEnabled: boolean
  speechStatus: 'idle' | 'requesting' | 'listening' | 'processing' | 'interpreting'
  transcript: string
  speechError: string
}>()
const emit = defineEmits<{ command: [command: VoiceCommand], start: [], stop: [], cancel: [], submit: [text: string] }>()
const manualText = ref('')
function submit() {
  const text = manualText.value.trim()
  if (text)
    emit('submit', text)
}
const commands = [
  { id: 'map', label: '打开地图' },
  { id: 'scan', label: '扫描空间' },
  { id: 'weather', label: '打开天气' },
  { id: 'audio', label: '播放声音' },
  { id: 'dark', label: '开启深色视界' },
  { id: 'hide', label: '隐藏 HUD' },
] as const
</script>

<template>
  <div class="command-panel">
    <p v-if="speechAvailable">点击开始，说出一条指令，再点击结束。识别完成后会执行匹配的操作。</p>
    <p v-else>点击一条指令，模拟语音操作。</p>
    <button v-if="speechAvailable" class="listen-button" type="button" :disabled="speechStatus === 'requesting' || speechStatus === 'processing' || speechStatus === 'interpreting'" @click="speechStatus === 'listening' ? $emit('stop') : $emit('start')">
      {{ speechStatus === 'requesting' ? '正在请求权限…' : speechStatus === 'listening' ? '结束并执行' : speechStatus === 'processing' ? '正在识别…' : speechStatus === 'interpreting' ? '正在理解指令…' : '开始语音识别' }}
    </button>
    <button v-if="speechAvailable && speechStatus !== 'idle'" type="button" @click="$emit('cancel')">{{ speechStatus === 'interpreting' ? '取消理解' : '取消录音' }}</button>
    <p v-if="speechAvailable && (transcript || speechError)" class="speech-result" role="status">{{ speechError || `识别结果：${transcript}` }}</p>
    <form class="command-entry" @submit.prevent="submit">
      <input v-model="manualText" type="text" aria-label="输入指令" placeholder="也可以输入指令试用" maxlength="500" :disabled="speechStatus !== 'idle'">
      <button type="submit" :disabled="speechStatus !== 'idle' || !manualText.trim()">执行</button>
    </form>
    <div class="command-examples" aria-label="示例指令">
      <button v-for="command in commands" :key="command.id" type="button" @click="$emit('command', command.id)">{{ command.label }}</button>
    </div>
    <small v-if="speechAvailable">还支持查看通知、打开设置、浅色视界、开始或结束导航、前进一步、暂停声音。按 ⌘⇧V 可控制录音，单次最长 12 秒。{{ cloudEnabled ? '未匹配的文字会发送给 DeepSeek 理解。' : '可在 Augma 设置中启用 DeepSeek 理解。' }}</small>
    <small v-else>网页演示不会请求麦克风权限。</small>
  </div>
</template>

<style scoped>
.command-panel { display: grid; gap: 10px; }
.command-panel p { font-size: 13px; margin: 0; }
.command-panel button { text-align: left; border: 0; background: rgb(255 255 255 / 12%); color: white; min-height: 40px; padding: 9px 11px; border-radius: 3px; cursor: pointer; }
.command-examples { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; }
.command-entry { display: flex; gap: 8px; }
.command-entry input { flex: 1; min-width: 0; border: 1px solid rgb(255 255 255 / 25%); background: rgb(0 0 0 / 18%); color: white; border-radius: 3px; padding: 9px 11px; font: inherit; }
.command-entry input::placeholder { color: rgb(255 255 255 / 65%); }
.command-entry input:focus-visible { outline: 2px solid var(--agm-accent); outline-offset: 1px; }
.command-entry button { white-space: nowrap; }
.command-panel .listen-button { background: var(--agm-accent); color: #111; font-weight: 600; }
.command-panel .listen-button:disabled { opacity: .65; cursor: wait; }
.command-panel button:disabled { opacity: .55; cursor: not-allowed; }
.command-panel .speech-result { margin: 0; overflow-wrap: anywhere; }
.command-panel button:hover { background: rgb(255 255 255 / 25%); }
.command-panel small { font-size: 11px; color: var(--agm-muted); }
</style>
