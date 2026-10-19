<script setup lang="ts">
import type { useCamera } from '../../composables/useCamera'
import type { useXr } from '../../composables/useXr'
import { AgmButton } from 'augma'
import { computed } from 'vue'
import { t } from '../../i18n/locale'
import DeviceIcon from './DeviceIcon.vue'

const { camera, xr } = defineProps<{ camera: ReturnType<typeof useCamera>, xr: ReturnType<typeof useXr>, online: boolean }>()
const emit = defineEmits<{ capture: [], prepareXr: [] }>()
const error = computed(() => camera.error.value || xr.error.value)
</script>

<template>
  <section class="camera-controls" :aria-label="t('camera.label')">
    <div class="camera-caption"><DeviceIcon name="camera" /><div><strong>{{ t('camera.title') }}</strong><span>{{ t('camera.subtitle') }}</span></div></div>
    <div class="camera-actions">
      <AgmButton v-if="camera.busy.value" variant="outline" @click="camera.stop">{{ t('camera.cancel') }}</AgmButton>
      <AgmButton v-else-if="!camera.stream.value" variant="outline" :disabled="!online || xr.ready.value || xr.busy.value" @click="camera.start">{{ t('camera.start') }}</AgmButton>
      <AgmButton v-else variant="outline" @click="camera.stop">{{ t('camera.stop') }}</AgmButton>
      <AgmButton variant="ghost" :disabled="!camera.stream.value || camera.busy.value" @click="camera.flip">{{ t('camera.flip') }}</AgmButton>
      <AgmButton variant="ghost" :disabled="!camera.stream.value" @click="emit('capture')">{{ t('camera.capture') }}</AgmButton>
      <template v-if="xr.supported.value">
        <AgmButton v-if="!xr.ready.value" variant="outline" :loading="xr.busy.value" :disabled="!online || camera.busy.value" @click="emit('prepareXr')">{{ t('camera.prepareXr') }}</AgmButton>
        <AgmButton v-else :disabled="xr.active.value || xr.busy.value" @click="xr.enter">{{ t('camera.enterXr') }}</AgmButton>
        <AgmButton v-if="xr.ready.value" variant="ghost" @click="xr.stop">{{ t('camera.exitXr') }}</AgmButton>
      </template>
    </div>
    <p v-if="!xr.supported.value" class="xr-note">{{ t('camera.xrUnsupported') }}</p>
    <p v-if="error" class="ar-error" role="alert">{{ t(error) }}</p>
  </section>
</template>

<style scoped>
.camera-controls { display: grid; gap: 20px; padding: 12px 0 0; }
.camera-caption { display: flex; align-items: center; gap: 13px; margin-right: auto; }
.camera-caption > svg { width: 24px; height: 24px; color: var(--agm-muted); }
.camera-caption strong { display: block; font-size: 13px; font-weight: 500; }
.camera-caption span { font-size: 10px; color: var(--agm-muted); display: block; margin-top: 5px; }
.camera-actions { display: flex; align-items: center; flex-wrap: wrap; gap: 8px; }
.camera-actions .agm-button { font-size: 12px; padding: 9px 16px; }
.xr-note, .ar-error { flex-basis: 100%; font-size: 11px; margin: 0; }
.xr-note { color: var(--agm-muted); }
@media (max-width: 760px) { .camera-caption { width: 100%; } .camera-actions { width: 100%; } .camera-actions .agm-button { flex: 1; } }
</style>
