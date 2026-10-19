<script setup lang="ts">
// Decorative HUD rings behind the device preview. Pure SVG + CSS: no state, no timers.
// Dash periods divide each circumference evenly: r=268 → 180 marks, r=270 → 12 majors, r=250 → two 50° arcs.
// The viewBox starts at 0 so each layer's `transform-origin: 50% 50%` (view-box) is the ring
// center: engines resolve view-box percentages from the user-space origin, not from min-x/min-y.
const blips = [212, 318, 64]
</script>

<template>
  <div class="hud-orbit" aria-hidden="true">
    <div class="hud-orbit-sweep" />
    <svg viewBox="0 0 560 560">
      <g class="hud-orbit-layer hud-orbit-scale" style="--i: 0">
        <circle cx="280" cy="280" r="268" stroke-width="6" stroke-dasharray="1 8.355" />
        <circle cx="280" cy="280" r="270" stroke-width="10" stroke-dasharray="1.6 139.77" class="major" />
      </g>
      <g class="hud-orbit-layer hud-orbit-ring" style="--i: 1">
        <circle cx="280" cy="280" r="250" />
        <path class="marks" d="M23 280h14M523 280h14M280 23v10M280 527v10" />
      </g>
      <g class="hud-orbit-layer hud-orbit-arcs" style="--i: 2">
        <circle cx="280" cy="280" r="250" stroke-dasharray="218.17 567.23" />
      </g>
      <g class="hud-orbit-layer hud-orbit-dash" style="--i: 3">
        <circle cx="280" cy="280" r="228" stroke-dasharray="2 9" />
      </g>
      <g class="hud-orbit-layer hud-orbit-blips" style="--i: 4">
        <rect
          v-for="(angle, index) in blips"
          :key="angle"
          x="276.5"
          y="26.5"
          width="7"
          height="7"
          :transform="`rotate(${angle} 280 280) rotate(45 280 30)`"
          :style="{ '--blip': index }"
        />
      </g>
    </svg>
  </div>
</template>
