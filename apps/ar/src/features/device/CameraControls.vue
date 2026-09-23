<script setup lang="ts">
import type { useCamera } from '../../composables/useCamera'
import type { useXr } from '../../composables/useXr'
import { AgmButton } from 'augma'
import DeviceIcon from './DeviceIcon.vue'

defineProps<{ camera: ReturnType<typeof useCamera>, xr: ReturnType<typeof useXr>, online: boolean }>()
const emit = defineEmits<{ capture: [], prepareXr: [] }>()
</script>

<template>
  <section class="camera-controls" aria-label="摄像头与空间 AR">
    <div class="camera-caption"><DeviceIcon name="camera" /><div><strong>接入你的现实</strong><span>仅在开启后请求摄像头权限</span></div></div>
    <div class="camera-actions">
      <AgmButton v-if="camera.busy.value" variant="outline" @click="camera.stop">取消开启摄像头</AgmButton>
      <AgmButton v-else-if="!camera.stream.value" variant="outline" :disabled="!online || xr.ready.value || xr.busy.value" @click="camera.start">开启摄像头</AgmButton>
      <AgmButton v-else variant="outline" @click="camera.stop">关闭摄像头</AgmButton>
      <AgmButton variant="ghost" :disabled="!camera.stream.value || camera.busy.value" @click="camera.flip">切换镜头</AgmButton>
      <AgmButton variant="ghost" :disabled="!camera.stream.value" @click="emit('capture')">保存画面</AgmButton>
      <template v-if="xr.supported.value">
        <AgmButton v-if="!xr.ready.value" variant="outline" :loading="xr.busy.value" :disabled="!online || camera.busy.value" @click="emit('prepareXr')">准备空间 AR</AgmButton>
        <AgmButton v-else :disabled="xr.active.value || xr.busy.value" @click="xr.enter">进入空间 AR</AgmButton>
        <AgmButton v-if="xr.ready.value" variant="ghost" @click="xr.stop">返回摄像头模式</AgmButton>
      </template>
    </div>
    <p v-if="!xr.supported.value" class="xr-note">此浏览器未提供空间 AR，可使用摄像头模式。</p>
    <p v-if="camera.error.value || xr.error.value" class="ar-error" role="alert">{{ camera.error.value || xr.error.value }}</p>
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
