<script setup lang="ts">
import {
  AgmButton,
  AgmDialog,
  AgmHudGauge,
  AgmHudProgress,
  AgmHudStatus,
  AgmIconButton,
  AgmPanel,
  AgmSlider,
  AgmSwitch,
} from 'augma'
import { onUnmounted, shallowRef, useTemplateRef } from 'vue'
import { useI18n } from '../i18n'
import HudOrbit from './HudOrbit.vue'
import UiIcon from './UiIcon.vue'

const { t } = useI18n()
const progress = shallowRef(72)
const energy = shallowRef(86)
const bright = shallowRef(false)
const sound = shallowRef(true)
const spatial = shallowRef(false)
const open = shallowRef(false)

// Pointer tilt writes CSS variables once per frame instead of updating Vue state.
const stage = useTemplateRef<HTMLElement>('stage')
let frame = 0
function tilt(event: PointerEvent) {
  if (event.pointerType !== 'mouse' || matchMedia('(prefers-reduced-motion: reduce)').matches)
    return
  const { clientX, clientY } = event
  cancelAnimationFrame(frame)
  frame = requestAnimationFrame(() => {
    const el = stage.value
    if (!el)
      return
    const rect = el.getBoundingClientRect()
    el.style.setProperty('--tilt-x', (((clientX - rect.left) / rect.width) * 2 - 1).toFixed(3))
    el.style.setProperty('--tilt-y', (((clientY - rect.top) / rect.height) * 2 - 1).toFixed(3))
  })
}
function settle() {
  cancelAnimationFrame(frame)
  stage.value?.style.removeProperty('--tilt-x')
  stage.value?.style.removeProperty('--tilt-y')
}
onUnmounted(() => cancelAnimationFrame(frame))
</script>

<template>
  <div
    ref="stage"
    class="device-stage"
    :class="{ 'is-spatial': spatial }"
    @pointermove="tilt"
    @pointerleave="settle"
  >
    <HudOrbit />
    <AgmPanel
      class="device-panel agm-materialize"
      :title="t('device.title')"
      :style="{ '--device-opacity': bright ? '1' : '.88', '--agm-delay': '260ms' }"
    >
      <template #header>
        <div class="device-title">
          <UiIcon name="link" />
          <h2>{{ t('device.title') }}</h2>
        </div>
      </template>
      <div class="device-overview">
        <div>
          <div class="device-preview-label">{{ t('device.preview') }}</div>
          <AgmHudStatus>{{ t('device.ready') }}</AgmHudStatus>
          <p>{{ t('device.hint') }}</p>
        </div>
        <AgmHudProgress :label="t('device.progress')" :value="progress" variant="ring" />
      </div>
      <AgmHudGauge :label="t('device.energy')" :value="energy" />
      <div class="device-controls">
        <div>
          <AgmIconButton
            :label="t('device.toggleBrightness')"
            :pressed="bright"
            @click="bright = !bright"
          >
            <UiIcon name="sun" />
          </AgmIconButton>
          <span>{{ t('device.brightness') }}</span>
        </div>
        <div>
          <AgmIconButton
            :label="t('device.toggleSound')"
            :pressed="sound"
            @click="sound = !sound"
          >
            <UiIcon name="volume" />
          </AgmIconButton>
          <span>{{ sound ? t('device.soundOn') : t('device.soundOff') }}</span>
        </div>
        <div>
          <AgmIconButton
            :label="t('device.toggleSpatial')"
            :pressed="spatial"
            @click="spatial = !spatial"
          >
            <UiIcon name="scan" />
          </AgmIconButton>
          <span>{{ t('device.spatial') }}</span>
        </div>
      </div>
      <AgmDialog
        v-model:open="open"
        :title="t('device.adjust')"
        :description="t('device.adjustDescription')"
      >
        <template #trigger>
          <AgmButton variant="outline" class="device-settings">
            <UiIcon name="settings" />
            {{ t('device.adjust') }}
          </AgmButton>
        </template>
        <div class="settings-fields">
          <AgmSlider v-model="progress" :label="t('device.progress')" />
          <AgmSlider v-model="energy" :label="t('device.energy')" />
          <AgmSwitch v-model="bright" :label="t('device.brightPanel')" />
          <AgmSwitch v-model="spatial" :label="t('device.spatial')" />
        </div>
        <template #footer>
          <AgmButton @click="open = false">{{ t('device.done') }}</AgmButton>
        </template>
      </AgmDialog>
    </AgmPanel>
  </div>
</template>
