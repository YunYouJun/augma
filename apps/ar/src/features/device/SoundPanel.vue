<script setup lang="ts">
import { AgmButton, AgmIconButton, AgmSlider } from 'augma'
import { computed } from 'vue'
import { soundscapes } from '../../composables/useSoundscape'
import { t } from '../../i18n/locale'
import DeviceIcon from './DeviceIcon.vue'

const { elapsed, duration, trackIndex } = defineProps<{ playing: boolean, busy: boolean, elapsed: number, duration: number, trackIndex: number, error: string, online: boolean }>()
const emit = defineEmits<{ play: [], pause: [], track: [index: number], seek: [value: number] }>()
const volume = defineModel<number>('volume', { required: true })
const track = computed(() => soundscapes[trackIndex])
const formatTime = (value: number) => `${Math.floor(value / 60)}:${String(Math.floor(value % 60)).padStart(2, '0')}`
const progress = computed(() => Math.round(elapsed))
</script>

<template>
  <div class="feature-body">
    <div class="sound-art" :class="{ 'is-playing': playing }" aria-hidden="true">
      <span v-for="i in 4" :key="i" :style="{ '--i': i }" /><DeviceIcon name="audio" />
    </div>
    <div class="track-title"><h3>{{ t(`sound.track.${track.id}.name`) }}</h3><p>{{ t(`sound.track.${track.id}.subtitle`) }}</p></div>
    <AgmSlider :model-value="progress" :label="t('sound.progress')" :max="duration" :disabled="!online" @update:model-value="emit('seek', $event)" />
    <div class="track-time"><span>{{ formatTime(elapsed) }}</span><span>{{ formatTime(duration) }}</span></div>
    <div class="playback-controls">
      <AgmIconButton :label="t('sound.previous')" :disabled="!online" @click="emit('track', (trackIndex + soundscapes.length - 1) % soundscapes.length)"><DeviceIcon name="previous" /></AgmIconButton>
      <AgmButton :disabled="!online" :loading="busy" @click="playing ? emit('pause') : emit('play')"><DeviceIcon :name="playing ? 'pause' : 'play'" />{{ t(playing ? 'sound.pause' : 'sound.play') }}</AgmButton>
      <AgmIconButton :label="t('sound.next')" :disabled="!online" @click="emit('track', (trackIndex + 1) % soundscapes.length)"><DeviceIcon name="next" /></AgmIconButton>
    </div>
    <AgmSlider v-model="volume" :label="t('sound.volume')" />
    <p v-if="error" class="ar-error" role="alert">{{ error }}</p>
    <p class="feature-description">{{ t('sound.description') }}</p>
    <div class="sound-library" :aria-label="t('sound.library')">
      <button v-for="(item, index) in soundscapes" :key="item.id" type="button" :disabled="!online" :aria-pressed="index === trackIndex" @click="emit('track', index)"><DeviceIcon :name="index === trackIndex && playing ? 'audio' : 'play'" />{{ t(`sound.track.${item.id}.name`) }}<small>02:00</small></button>
    </div>
  </div>
</template>

<style scoped>
.sound-art { display: grid; place-items: center; position: relative; height: 162px; color: var(--agm-cyan); }
.sound-art span { position: absolute; width: calc(40px + var(--i) * 27px); aspect-ratio: 1; border: 1px solid currentColor; border-radius: 50%; opacity: calc(.6 - var(--i) * .1); }
.sound-art span:nth-child(2) { border-style: dashed; }
.sound-art svg { width: 30px; height: 30px; }
.is-playing span { animation: breathe 3s ease-in-out infinite alternate; animation-delay: calc(var(--i) * -.5s); }
.track-title { text-align: center; margin: 0 0 22px; }
.track-title h3 { font-size: 22px; font-weight: 500; margin: 0 0 6px; }
.track-title p { font-size: 12px; color: var(--agm-muted); margin: 0; }
.track-time { display: flex; justify-content: space-between; font-size: 11px; color: var(--agm-muted); }
.playback-controls { display: flex; justify-content: space-between; gap: 10px; margin: 18px 0 24px; align-items: center; }
.playback-controls .agm-button { flex: 1; padding-inline: 12px; }
.playback-controls .agm-icon-button { width: 40px; height: 40px; padding: 10px; }
.sound-library { display: grid; border-top: 1px solid var(--agm-border); }
.sound-library button { display: flex; gap: 12px; align-items: center; min-height: 44px; border: 0; background: transparent; color: var(--agm-muted); font: inherit; font-size: 12px; cursor: pointer; }
.sound-library button[aria-pressed='true'] { color: var(--agm-accent); }
.sound-library button:disabled { opacity: .5; cursor: not-allowed; }
.sound-library svg { width: 15px; height: 15px; }
.sound-library small { margin-left: auto; }
@keyframes breathe { to { transform: scale(1.1); } }
@media (prefers-reduced-motion: reduce) { .is-playing span { animation: none; } }
</style>
