<script setup lang="ts">
import type { Connection } from '../features/device/types'
import { AgmButton, AgmHudStatus } from 'augma'
import { computed } from 'vue'

const { connection } = defineProps<{ connection: Connection, live: boolean, scene: string }>()
const emit = defineEmits<{ connect: [], sleep: [], disconnect: [] }>()
const labels: Record<Connection, string> = { connected: '模拟设备已连接', connecting: '正在建立连接', disconnected: '模拟设备已断开', sleeping: '设备正在待机' }
const label = computed(() => labels[connection])
</script>

<template>
  <div class="device-status">
    <AgmHudStatus :tone="connection === 'connected' ? 'success' : 'neutral'">{{ label }}</AgmHudStatus>
    <dl><div><dt>当前视界</dt><dd>{{ live ? '摄像头画面' : '模拟视界' }}</dd></div><div><dt>模拟场景</dt><dd>{{ scene }}</dd></div></dl>
    <p>地点、距离和扫描结果均为演示数据。</p>
    <div v-if="connection === 'connected'" class="session-actions"><AgmButton variant="outline" @click="emit('sleep')">待机</AgmButton><AgmButton variant="outline" @click="emit('disconnect')">断开</AgmButton></div>
    <AgmButton v-else class="full-button" :loading="connection === 'connecting'" @click="emit('connect')">{{ connection === 'sleeping' ? '唤醒设备' : '连接模拟设备' }}</AgmButton>
  </div>
</template>

<style scoped>
.device-status { padding-top: 12px; font-size: 13px; }
.device-status dl { display: grid; gap: 16px; margin: 24px 0; }
.device-status dl > div { display: flex; justify-content: space-between; gap: 12px; }
.device-status dd { margin: 0; }
.device-status p { color: var(--agm-muted); font-size: 11px; margin: 0 0 24px; }
.session-actions { display: flex; gap: 12px; }
.session-actions .agm-button { flex: 1; }
</style>
