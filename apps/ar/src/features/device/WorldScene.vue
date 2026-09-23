<script setup lang="ts">
import type { Landmark, SceneId } from './types'
import { computed } from 'vue'
import DeviceIcon from './DeviceIcon.vue'

const { landmarks, selected, route, routeProgress } = defineProps<{
  scene: SceneId
  landmarks: Landmark[]
  selected: string
  scanning: boolean
  pinned: boolean
  route: boolean
  routeProgress: number
  mapMode: boolean
}>()
const emit = defineEmits<{ select: [id: string] }>()
const routeColors = ['#f44761', '#42b5b1', '#a697c9']
const mapRoutes = computed(() => landmarks.map((landmark, index) => {
  const points = [[500, 850], [500, 740 - index * 100], [landmark.x * 10, landmark.y * 10 + 120], [landmark.x * 10, landmark.y * 10]]
  return { ...landmark, points, color: routeColors[index], path: points.map(([x, y], i) => `${i ? 'L' : 'M'} ${x} ${y}`).join(' ') }
}))
const position = computed(() => {
  const points = mapRoutes.value.find(item => item.id === selected)!.points
  const lengths = points.slice(1).map(([x, y], i) => Math.hypot(x - points[i][0], y - points[i][1]))
  let distance = lengths.reduce((sum, length) => sum + length, 0) * (route ? routeProgress : 0) / 100
  for (let i = 0; i < lengths.length; i++) {
    if (distance <= lengths[i]) {
      const fraction = lengths[i] ? distance / lengths[i] : 0
      return [points[i][0] + (points[i + 1][0] - points[i][0]) * fraction, points[i][1] + (points[i + 1][1] - points[i][1]) * fraction]
    }
    distance -= lengths[i]
  }
  return points[points.length - 1]
})
</script>

<template>
  <div class="world-scene" :class="{ 'is-scanning': scanning, 'is-map': mapMode }" :aria-label="scene === 'garden' ? '庭园模拟空间' : '城市模拟空间'">
    <div class="spatial-field">
      <svg v-if="mapMode" class="spatial-map" viewBox="0 0 1000 1000" preserveAspectRatio="none" fill="none" aria-hidden="true">
        <g class="map-network">
          <path d="M0 200h230l120 160v180l300 100h350M80 0v450l240 160h680M320 0v240l160 120h280l130 210v430M0 800h310l160-200h310l220-170" stroke="#f44761" />
          <path d="M0 430h280l180-230h540M150 1000V780l300-160V370L280 160V0M0 660h290l410-260h300" stroke="#42b5b1" />
          <path d="M0 90h510l220 310v290l-200 160v150M0 960l460-290V460l190-290h350M0 570h350l250 150h400" stroke="#a697c9" />
          <path d="M0 340h130l110 180v220h400l210-210h150M0 50h390l150 240v440l240 240" stroke="#d1ac6a" />
        </g>
        <g v-for="item in mapRoutes" :key="item.id" :opacity="item.id === selected ? 1 : .28">
          <path :d="item.path" stroke="rgb(255 255 255 / 50%)" stroke-width="12" vector-effect="non-scaling-stroke" />
          <path :d="item.path" :stroke="item.color" stroke-width="8" vector-effect="non-scaling-stroke" />
          <circle v-for="([x, y], index) in item.points" :key="index" :cx="x" :cy="y" r="8" fill="#f7f7f7" :stroke="item.color" stroke-width="2" vector-effect="non-scaling-stroke" />
        </g>
        <circle :cx="position[0]" :cy="position[1]" r="13" fill="white" stroke="#4dade0" stroke-width="3" vector-effect="non-scaling-stroke" />
      </svg>
      <div v-else class="scene-reticle" aria-hidden="true"><span /><i /><span /></div>
      <div v-if="scanning" class="scan-sweep" aria-hidden="true" />
      <div class="world-markers">
        <button
          v-for="(landmark, index) in landmarks" :key="landmark.id" type="button"
          class="world-marker" :class="{ 'is-selected': landmark.id === selected }"
          :style="{ 'left': `${landmark.x}%`, 'top': `${landmark.y}%`, '--marker-color': mapMode ? routeColors[index] : '#8dd3d6' }"
          :aria-label="`选择${landmark.name}`" :aria-pressed="landmark.id === selected"
          @click="emit('select', landmark.id)"
        >
          <DeviceIcon :name="pinned ? 'pin' : 'location'" />
          <span class="marker-label">{{ landmark.name }}<small>{{ landmark.distance }} m · 模拟</small></span>
        </button>
      </div>
    </div>
    <div v-if="mapMode" class="map-legend" aria-label="模拟路线">
      <button v-for="(item, index) in mapRoutes" :key="item.id" type="button" :style="{ '--route-color': item.color }" :aria-label="`显示到${item.name}的路线`" :aria-pressed="item.id === selected" @click="emit('select', item.id)">{{ index + 1 }}</button>
    </div>
  </div>
</template>

<style scoped>
.world-scene { position: absolute; inset: 0; overflow: hidden; pointer-events: none; }
.spatial-field { position: absolute; inset: 0 420px 0 0; }
.spatial-map { position: absolute; inset: 0; width: 100%; height: 100%; }
.map-network { stroke-width: 6; opacity: .2; stroke-linejoin: round; }
.map-legend { position: absolute; display: grid; gap: 16px; left: 32px; top: 28%; pointer-events: auto; }
.map-legend button { border: 0; background: var(--route-color); color: white; border-radius: 50%; width: 44px; height: 44px; cursor: pointer; font-size: 23px; opacity: .65; }
.map-legend button[aria-pressed='true'] { opacity: 1; box-shadow: 0 0 0 2px rgb(255 255 255 / 65%); }
.world-markers { position: absolute; inset: 0; }
.world-marker { position: absolute; display: flex; align-items: center; gap: 5px; padding: 5px 7px; min-height: 44px; border: 1px solid rgb(255 255 255 / 40%); border-radius: 3px; color: white; background: rgb(105 105 105 / 55%); transform: translate(-50%, -50%); cursor: pointer; pointer-events: auto; text-align: left; }
.world-marker > svg { width: 18px; height: 18px; flex-shrink: 0; }
.marker-label { font-size: 15px; white-space: nowrap; }
.marker-label small { display: block; margin-top: 3px; font-size: 10px; color: rgb(255 255 255 / 80%); }
.is-selected { border-color: white; background: color-mix(in srgb, var(--marker-color) 60%, transparent); }
.scan-sweep { position: absolute; inset: 0; background: linear-gradient(transparent 47%, rgb(179 226 229 / 15%) 50%, transparent 53%); animation: sweep 2s ease-in-out infinite; }
.scene-reticle { position: absolute; inset: 50% 32%; display: flex; align-items: center; justify-content: center; gap: 18px; }
.scene-reticle span { height: 1px; width: 22px; background: rgb(255 255 255 / 35%); }
.scene-reticle i { width: 4px; height: 4px; border-radius: 50%; background: white; }
@keyframes sweep { from { transform: translateY(-40%); } to { transform: translateY(40%); } }
@media (max-width: 900px) { .spatial-field { right: 360px; } .map-legend { left: 16px; top: 65%; gap: 10px; } .world-marker { padding: 4px; } .marker-label { font-size: 12px; } }
@media (max-width: 600px) { .spatial-field { right: 0; height: 185px; } .world-marker { gap: 2px; } .marker-label { font-size: 11px; } .map-legend { top: 185px; left: 14px; } .map-legend button { width: 38px; height: 38px; font-size: 20px; } }
@media (prefers-reduced-motion: reduce) { .scan-sweep { animation: none; } }
</style>
