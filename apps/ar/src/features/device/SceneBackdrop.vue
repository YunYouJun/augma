<script setup lang="ts">
import type { SceneId } from './types'
import { toRef } from 'vue'
import CityScene from './backdrop/CityScene.vue'
import GardenScene from './backdrop/GardenScene.vue'
import { useMotionBudget } from './backdrop/useMotionBudget'

const props = defineProps<{
  scene: SceneId
  /** Hold the motion where it is, for example while a panel or dialog covers the view. */
  paused?: boolean
}>()
const still = useMotionBudget(toRef(() => props.paused))
</script>

<template>
  <div class="scene-backdrop" :class="{ 'is-still': still, 'is-paused': paused }" aria-hidden="true">
    <Transition name="backdrop-fade">
      <GardenScene v-if="scene === 'garden'" key="garden" />
      <CityScene v-else key="city" />
    </Transition>
  </div>
</template>

<style>
/* Shared by the scenes: depth planes, parallax and focus. Not scoped, so the scene components can use it. */
/* Keep the scenes cheap to composite: no mix-blend-mode, and no filter on an element that animates or sits above
   one. Without a GPU, WebKit re-applies a layer's filter or blend mode on every frame, which held the simulator to
   one or two frames per second. A glow goes on the shapes inside and is drawn once into the layer: an svg filter on
   small shapes (WebKit ignores CSS filter functions on svg shapes), a soft stroke on large ones. */
.scene-backdrop { position: absolute; inset: 0; z-index: 0; overflow: hidden; pointer-events: none; }
/* Darken the top and bottom bands so the white clock, rules and dock keep their contrast. */
.scene-backdrop::after { content: ''; position: absolute; inset: 0; background: linear-gradient(rgb(0 0 0 / 30%), transparent 20%, transparent 74%, rgb(0 0 0 / 34%)), radial-gradient(ellipse at 50% 45%, transparent 60%, rgb(0 0 0 / 18%)); }
.scene-backdrop .backdrop-scene { position: absolute; inset: 0; overflow: hidden; }

/* Each depth plane shifts against the pointer by its own amount; the mid plane matches the anchors. */
.scene-backdrop .layer { position: absolute; inset: -56px; translate: calc(var(--depth-x, 0) * var(--shift) * -1px) calc(var(--depth-y, 0) * var(--shift) * -.7px); transition: translate 240ms ease-out; }
.scene-backdrop .layer-far { --shift: 2; --orbit: 6; }
.scene-backdrop .layer-clouds { --shift: 4; }
.scene-backdrop .layer-mid { --shift: 7; }
.scene-backdrop .layer-glow { --shift: 20; --orbit: -12; }
.scene-backdrop .layer-near { --shift: 36; --orbit: -26; }
/* A slow drift around the in-focus mid plane: far layers move one way, near layers the other. It moves `translate`, so
   it adds to a part's own transform or scale, and each part drifts in its own small layer: a full-plane box that
   paints would hold a buffer the size of the view. */
.scene-backdrop .orbit { position: absolute; inset: 0; animation: backdrop-orbit 34s ease-in-out infinite alternate; }
.scene-backdrop .art { position: absolute; inset: 0; width: 100%; height: 100%; overflow: visible; transition: filter 480ms ease-out; }
/* See `band()`: the box keeps the band's share of the scene's height. */
.scene-backdrop .scene-band { top: auto; height: calc((1 - var(--band-top) / 900) * 100%); }
/* The mid plane is a layer of its own, above the drifting far plane. Its scenery holds a layer that covers only its band
   (see the will-change below), so the plane itself paints nothing and needs no full-screen buffer. */
.scene-backdrop .mid-art { position: absolute; left: 0; right: 0; bottom: 0; }
.scene-backdrop .art-far { filter: blur(1.2px); }
.scene-backdrop .art-near { filter: blur(7px); }
.has-depth.has-window .scene-backdrop .art-far { filter: blur(4px); }
.has-depth.has-window .scene-backdrop .art-mid { filter: blur(2.4px); }

/* Switching scenes: the new world materializes in a brief flash of AR light. */
.backdrop-fade-enter-active { transition: opacity 900ms ease, filter 1100ms ease-out, scale 1100ms ease-out; }
.backdrop-fade-leave-active { transition: opacity 900ms ease; }
.backdrop-fade-enter-from { opacity: 0; filter: brightness(1.8) saturate(.3); scale: 1.04; }
.backdrop-fade-leave-to { opacity: 0; }

/* Behind an open panel or dialog the motion waits where it is: their frosted glass would re-blur it on every frame. */
.scene-backdrop.is-paused * { animation-play-state: paused !important; }
/* Too slow to animate smoothly: the scenery holds still and changes focus or scene at once, as under reduced motion. */
.scene-backdrop.is-still, .scene-backdrop.is-still * { animation: none !important; transition: none !important; will-change: auto !important; }
.scene-backdrop.is-still .backdrop-fade-enter-from { filter: none; scale: none; }
/* Reduced motion stops every animation (see style.css); will-change would then only pin a layer per moving part. */
@media (prefers-reduced-motion: reduce) { .scene-backdrop * { will-change: auto !important; } }
/* The mid scenery keeps its small layer even when still: the 3D floor keeps the plane a layer anyway. */
.scene-backdrop .mid-art { will-change: transform !important; }

@keyframes backdrop-orbit { from { translate: calc(var(--orbit, 0) * -1px); } to { translate: calc(var(--orbit, 0) * 1px); } }
@keyframes backdrop-bob { from { transform: translateY(-8px); } to { transform: translateY(8px); } }
@keyframes backdrop-drift { from { transform: translateX(-60px); } to { transform: translateX(60px); } }
@keyframes backdrop-rise { 0% { opacity: 0; transform: none; } 25% { opacity: .9; } 75% { opacity: .75; } 100% { opacity: 0; transform: translate(var(--dx), var(--dy)); } }
/* Portrait screens would crop the wide scenery to its middle; keep it low and wider instead. */
@media (max-aspect-ratio: 4 / 5) {
  .scene-backdrop .scene-art { top: auto; height: 62%; }
  .scene-backdrop .scene-band { height: calc((1 - var(--band-top) / 900) * 62%); }
}
</style>
