<script setup lang="ts">
// Decorative HUD rings behind the device preview. Pure SVG + CSS: no state, no timers.
// Dash periods divide each circumference evenly: r=268 → 180 marks, r=270 → 12 majors, r=250 → two 50° arcs.
const blips = [212, 318, 64]
</script>

<template>
  <div class="hud-orbit" aria-hidden="true">
    <div class="hud-orbit-sweep" />
    <svg viewBox="-280 -280 560 560">
      <g class="hud-orbit-layer hud-orbit-scale" style="--i: 0">
        <circle r="268" stroke-width="6" stroke-dasharray="1 8.355" />
        <circle r="270" stroke-width="10" stroke-dasharray="1.6 139.77" class="major" />
      </g>
      <g class="hud-orbit-layer hud-orbit-ring" style="--i: 1">
        <circle r="250" />
        <path class="marks" d="M-257 0h14M243 0h14M0 -257v10M0 247v10" />
      </g>
      <g class="hud-orbit-layer hud-orbit-arcs" style="--i: 2">
        <circle r="250" stroke-dasharray="218.17 567.23" />
      </g>
      <g class="hud-orbit-layer hud-orbit-dash" style="--i: 3">
        <circle r="228" stroke-dasharray="2 9" />
      </g>
      <g class="hud-orbit-layer hud-orbit-blips" style="--i: 4">
        <rect
          v-for="(angle, index) in blips"
          :key="angle"
          x="-3.5"
          y="-253.5"
          width="7"
          height="7"
          :transform="`rotate(${angle}) rotate(45 0 -250)`"
          :style="{ '--blip': index }"
        />
      </g>
    </svg>
  </div>
</template>
