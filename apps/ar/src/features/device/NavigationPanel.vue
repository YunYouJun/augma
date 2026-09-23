<script setup lang="ts">
import type { Landmark } from './types'
import { AgmButton, AgmHudProgress } from 'augma'
import { computed } from 'vue'
import DeviceIcon from './DeviceIcon.vue'

const { selected, landmarks } = defineProps<{ landmarks: Landmark[], selected: Landmark, step: number | null, progress: number, remaining: number, instruction: string, online: boolean }>()
const emit = defineEmits<{ select: [id: string], start: [], advance: [], cancel: [] }>()
const stops = computed(() => ['当前位置', '前方步道', '转角路口', '目标锚点', selected.name])
const routeColor = computed(() => ['#f44761', '#42b5b1', '#a697c9'][landmarks.findIndex(place => place.id === selected.id)])
</script>

<template>
  <div class="feature-body" :style="{ '--route-color': routeColor }">
    <ol class="route-stops" aria-label="路线步骤">
      <li v-for="(stop, index) in stops" :key="index" :aria-current="step === index ? 'step' : undefined" :class="{ 'is-passed': step !== null && index < step }"><span>{{ stop }}</span><i aria-hidden="true" /><small>{{ index === step ? '当前位置' : step !== null && index < step ? '已通过' : '待抵达' }}</small></li>
    </ol>
    <div class="destination-list" aria-label="目的地">
      <button v-for="place in landmarks" :key="place.id" type="button" :aria-pressed="selected.id === place.id" :disabled="!online" @click="emit('select', place.id)">
        <DeviceIcon name="location" /><span>{{ place.name }}</span><small>{{ place.distance }} m</small>
      </button>
    </div>
    <div class="route-instruction" aria-live="polite"><DeviceIcon :name="step === 4 ? 'check' : 'navigation'" /><p>{{ instruction }}<small>{{ step === null ? '距离与路线均为模拟' : `剩余 ${remaining} m · 模拟行进` }}</small></p></div>
    <AgmHudProgress v-if="step !== null" label="路线进度" :value="progress" />
    <div class="route-actions">
      <AgmButton v-if="step === null || step === 4" class="full-button" :disabled="!online" @click="emit('start')">{{ step === 4 ? '再次导航' : '开始模拟导航' }}</AgmButton>
      <AgmButton v-else class="full-button" :disabled="!online" @click="emit('advance')">前进一步<DeviceIcon name="arrow" /></AgmButton>
      <AgmButton v-if="step !== null" variant="ghost" class="full-button" @click="emit('cancel')">结束导航</AgmButton>
    </div>
  </div>
</template>

<style scoped>
.feature-body { background: rgb(75 75 75 / 45%); }
.route-stops { list-style: none; padding: 0; margin: 0; background: color-mix(in srgb, var(--route-color) 78%, transparent); }
.route-stops li { position: relative; display: flex; align-items: center; gap: 12px; min-height: 54px; padding: 11px 18px; font-size: 16px; color: rgb(255 255 255 / 90%); }
.route-stops li:nth-child(even) { background: rgb(255 255 255 / 24%); }
.route-stops li > span { flex: 1; text-align: right; }
.route-stops small { width: 36px; font-size: 9px; }
.route-stops i { position: relative; width: 24px; height: 24px; flex-shrink: 0; border: 3px solid rgb(255 255 255 / 80%); border-radius: 50%; }
.route-stops li:not(:last-child) i::after { position: absolute; content: ''; width: 3px; height: 34px; left: 7.5px; top: 21px; background: rgb(255 255 255 / 80%); }
.route-stops [aria-current='step'] { color: white; }
.route-stops [aria-current='step'] i { background: #4dade0; }
.route-stops .is-passed i { background: rgb(255 255 255 / 45%); }
.destination-list { display: grid; padding: 8px 16px 0; }
.destination-list button { display: flex; align-items: center; gap: 8px; padding: 10px 4px; min-height: 44px; border: 0; border-bottom: 1px solid var(--agm-border); color: white; background: transparent; font-size: 12px; cursor: pointer; }
.destination-list button[aria-pressed='true'] { color: #b3e2e5; }
.destination-list button:disabled { opacity: .5; cursor: not-allowed; }
.destination-list svg { width: 17px; height: 17px; }
.destination-list small { margin-left: auto; color: var(--agm-muted); }
.route-instruction { display: flex; align-items: center; gap: 12px; padding: 18px 16px; }
.route-instruction svg { color: white; width: 24px; height: 24px; flex-shrink: 0; }
.route-instruction p { font-size: 13px; line-height: 1.6; margin: 0; }
.route-instruction small { display: block; font-size: 10px; margin-top: 4px; color: var(--agm-muted); }
.agm-progress { margin: 0 16px; }
.route-actions { display: grid; gap: 6px; padding: 0 16px 16px; margin-top: 12px; }
</style>
