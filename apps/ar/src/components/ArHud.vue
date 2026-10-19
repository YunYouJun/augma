<script setup lang="ts">
import type { Connection } from '../features/device/types'
import { AgmButton, AgmHudStatus } from 'augma'
import { computed } from 'vue'
import { t } from '../i18n/locale'

const { connection } = defineProps<{ connection: Connection, live: boolean, scene: string }>()
const emit = defineEmits<{ connect: [], sleep: [], disconnect: [] }>()
const label = computed(() => t(`connection.${connection}`))
</script>

<template>
  <div class="device-status">
    <AgmHudStatus :tone="connection === 'connected' ? 'success' : 'neutral'">{{ label }}</AgmHudStatus>
    <dl><div><dt>{{ t('device.currentView') }}</dt><dd>{{ t(live ? 'device.cameraView' : 'device.simulatedView') }}</dd></div><div><dt>{{ t('device.scene') }}</dt><dd>{{ scene }}</dd></div></dl>
    <p>{{ t('device.demoNote') }}</p>
    <div v-if="connection === 'connected'" class="session-actions"><AgmButton variant="outline" @click="emit('sleep')">{{ t('device.sleep') }}</AgmButton><AgmButton variant="outline" @click="emit('disconnect')">{{ t('device.disconnect') }}</AgmButton></div>
    <AgmButton v-else class="full-button" :loading="connection === 'connecting'" @click="emit('connect')">{{ t(connection === 'sleeping' ? 'device.wake' : 'device.connect') }}</AgmButton>
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
