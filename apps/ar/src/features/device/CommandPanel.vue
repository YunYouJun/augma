<script setup lang="ts">
import type { VoiceCommand } from './voiceCommands'
import { ref } from 'vue'
import { t } from '../../i18n/locale'

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
const commands = ['map', 'scan', 'weather', 'audio', 'dark', 'hide'] as const
</script>

<template>
  <div class="command-panel">
    <p v-if="speechAvailable">{{ t('commands.speechIntro') }}</p>
    <p v-else>{{ t('commands.intro') }}</p>
    <button v-if="speechAvailable" class="listen-button" type="button" :disabled="speechStatus === 'requesting' || speechStatus === 'processing' || speechStatus === 'interpreting'" @click="speechStatus === 'listening' ? $emit('stop') : $emit('start')">
      {{ t(`commands.status.${speechStatus}`) }}
    </button>
    <button v-if="speechAvailable && speechStatus !== 'idle'" type="button" @click="$emit('cancel')">{{ t(speechStatus === 'interpreting' ? 'commands.cancelInterpret' : 'commands.cancelRecording') }}</button>
    <p v-if="speechAvailable && (transcript || speechError)" class="speech-result" role="status">{{ speechError || t('commands.transcript', { text: transcript }) }}</p>
    <form class="command-entry" @submit.prevent="submit">
      <input v-model="manualText" type="text" :aria-label="t('commands.input')" :placeholder="t('commands.placeholder')" maxlength="500" :disabled="speechStatus !== 'idle'">
      <button type="submit" :disabled="speechStatus !== 'idle' || !manualText.trim()">{{ t('commands.run') }}</button>
    </form>
    <div class="command-examples" :aria-label="t('commands.examples')">
      <button v-for="command in commands" :key="command" type="button" @click="$emit('command', command)">{{ t(`commands.example.${command}`) }}</button>
    </div>
    <small v-if="speechAvailable">{{ t('commands.more', { cloud: { key: cloudEnabled ? 'commands.cloudOn' : 'commands.cloudOff' } }) }}</small>
    <small v-else>{{ t('commands.webNote') }}</small>
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
