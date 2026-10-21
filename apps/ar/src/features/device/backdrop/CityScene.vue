<script setup lang="ts">
import type { Circle } from './scenery'
import { useId } from 'vue'
import ArField from './ArField.vue'
import DataShards from './DataShards.vue'
import Glints from './Glints.vue'
import LensFlare from './LensFlare.vue'
import { boxes, circles, cumulus, drifts, driftStyle, lit, round, sequence, towers } from './scenery'

const glow = useId()

/** Clouds catch the low sun from below on the left. */
const light: [number, number] = [-0.45, 0.89]
function cloud(seed: number, rows: number) {
  const items = cumulus(seed, 0, 200, 300, rows)
  const top = Math.floor(Math.min(...items.map(([, y, r]) => y - r)))
  return { viewBox: `-60 ${top} 420 ${200 - top}`, base: circles(items), lit: circles(lit(items, light, 0.3)) }
}
const clouds = [
  { ...cloud(37, 2), style: { left: '46%', top: '13%', width: '30vw', animationDuration: '140s' } },
  { ...cloud(59, 2), style: { left: '2%', top: '24%', width: '20vw', animationDuration: '110s' } },
]

const farTowers = towers(11, 640, [70, 250], [36, 96])
const legX = (y: number, side: number) => round(side < 0 ? 1236 + (640 - y) / 340 * 26 : 1300 - (640 - y) / 340 * 26)
const braces = Array.from({ length: 12 }, (_, i) => 620 - i * 26).map((y, i) => `${i ? 'L' : 'M'}${legX(y, i % 2 ? 1 : -1)} ${y}`).join('')

const midTowers = towers(23, 790, [170, 430], [86, 168])
const lit3 = ['', '', '']
let dim = ''
let roofs = ''
const neon = ['', '']
{
  const random = sequence(41)
  midTowers.forEach(({ x: left, y: top, w, h }, index) => {
    const facade = random()
    if (random() < 0.45) {
      const height = Math.round(10 + random() * 18)
      roofs += `M${Math.round(left + w * (0.15 + random() * 0.4))} ${top}v-${height}h${Math.round(w * 0.3)}v${height}z`
    }
    if (index % 3 === 1)
      neon[index % 2] += `M${left + w - 17} ${top + 36}h9v${Math.min(120, h - 90)}h-9z`
    else if (index % 3 === 2 && h > 260)
      neon[(index + 1) % 2] += `M${left + 12} ${top + 70}h${Math.min(64, w - 40)}v8h${-Math.min(64, w - 40)}z`
    if (facade < 0.55) {
      // Punched windows, some of them lit.
      for (let x = left + 11; x + 9 <= left + w - 20; x += 20) {
        for (let y = top + 18; y + 11 <= 770; y += 26) {
          const pane = `M${x} ${y}h9v11h-9z`
          if (random() < 0.24)
            lit3[Math.floor(random() * 3)] += pane
          else
            dim += pane
        }
      }
    }
    else if (facade < 0.8) {
      // Ribbon windows across each floor.
      for (let y = top + 16; y + 7 <= 770; y += 22)
        dim += `M${left + 8} ${y}h${w - 28}v7h${28 - w}z`
    }
    else {
      // Glass fins running the full height.
      for (let x = left + 10; x + 5 <= left + w - 20; x += 16)
        dim += `M${x} ${top + 14}h5v${756 - top}h-5z`
    }
  })
}
// The low sun lights the left and top edges.
const rims = (list: typeof midTowers) => list.map(({ x, y, h }) => `M${x} ${y + h}V${y}h${Math.round(Math.min(40, h / 4))}`).join('')

const stars = (() => {
  const random = sequence(97)
  return circles(Array.from({ length: 60 }, () => [round(random() * 1600), round(random() ** 1.6 * 420), round(0.6 + random() ** 3 * 1.2)] as Circle))
})()
const traffic = drifts(17, 16, [72, 94], [16, 64], random => [Math.round((random() < 0.5 ? -1 : 1) * (50 + random() * 90)), 0], 0.22)
const glints = [[34, 52, 18, -1], [58, 46, 14, -3.4], [80, 60, 22, -5.2], [10, 58, 14, -2.2]]
</script>

<template>
  <div class="backdrop-scene is-city">
    <svg class="stars" viewBox="0 0 1600 900" preserveAspectRatio="xMidYMid slice"><path :d="stars" /></svg>
    <div class="layer layer-far">
      <div class="orbit">
        <svg class="art art-far scene-art" viewBox="0 0 1600 900" preserveAspectRatio="xMidYMax slice">
          <path class="fill-far" :d="boxes(farTowers)" />
          <path class="stroke-far-rim" :d="rims(farTowers)" />
          <path class="stroke-tower" :d="`M1236 640L1262 300M1300 640L1274 300M1268 300V200${braces}`" />
          <path class="fill-tower" d="M1248 452h52v14h-52zM1256 362h36v10h-36z" />
        </svg>
        <svg class="art scene-art beacon" viewBox="0 0 1600 900" preserveAspectRatio="xMidYMax slice"><defs><filter :id="`${glow}-beacon`" x="-200%" y="-200%" width="500%" height="500%"><feDropShadow dx="0" dy="0" stdDeviation="5" flood-color="currentColor" /></filter></defs><circle cx="1268" cy="198" r="5" :filter="`url(#${glow}-beacon)`" /></svg>
      </div>
    </div>
    <div class="layer layer-clouds">
      <svg v-for="(item, index) in clouds" :key="index" class="cloud" :viewBox="item.viewBox" :style="item.style"><path class="fill-cloud-shade" :d="item.base" /><path class="fill-cloud" :d="item.lit" /></svg>
    </div>
    <div class="layer layer-mid">
      <svg class="art art-mid scene-art" viewBox="0 0 1600 900" preserveAspectRatio="xMidYMax slice">
        <path class="fill-tower-mid" :d="boxes(midTowers) + roofs" />
        <path class="fill-window" :d="dim" />
        <path class="stroke-rim" :d="rims(midTowers)" />
      </svg>
      <svg v-for="(path, index) in lit3" :key="index" class="art art-mid scene-art windows" :class="`is-${index + 1}`" viewBox="0 0 1600 900" preserveAspectRatio="xMidYMax slice"><path class="fill-lit" :d="path" /></svg>
      <svg v-for="(path, index) in neon" :key="`n${index}`" class="art art-mid scene-art neon" :class="`is-${index + 1}`" viewBox="0 0 1600 900" preserveAspectRatio="xMidYMax slice"><defs><filter :id="`${glow}-n${index}`"><feDropShadow class="neon-glow" dx="0" dy="0" stdDeviation="5" flood-color="currentColor" /></filter></defs><path :d="path" :filter="`url(#${glow}-n${index})`" /></svg>
      <div class="scan" />
      <svg class="art art-mid scene-art" viewBox="0 0 1600 900" preserveAspectRatio="xMidYMax slice">
        <path class="fill-ground" d="M0 790H1600V900H0Z" />
        <path class="fill-front" d="M1090 790V664Q1240 572 1390 664V790Z" />
        <path class="fill-front-lit" d="M1090 790V664Q1138 634 1188 619V790Z" />
        <path class="stroke-window" d="M1100 704H1380M1100 744H1380" />
        <path class="stroke-accent" d="M1090 664Q1240 572 1390 664" />
        <path class="stroke-front" :d="Array.from({ length: 7 }, (_, i) => `M${130 + i * 240} 620V790`).join('')" />
        <path class="stroke-track" d="M0 614H1600" />
        <path class="stroke-rim" d="M0 608H1600M196 606L222 578H538" />
        <path class="fill-front" d="M196 606L222 578H538L564 606Z" />
      </svg>
      <div class="train">
        <svg class="art art-mid scene-art" viewBox="0 0 1600 900" preserveAspectRatio="xMinYMax slice"><path class="fill-front" d="M-250 611V598Q-250 589-240 589H-34Q-14 591-8 602L-4 611Z" /><path class="stroke-lit" d="M-238 595H-30" /></svg>
      </div>
      <ArField />
    </div>
    <div class="layer layer-glow">
      <div class="orbit">
        <i v-for="(drift, index) in traffic" :key="index" class="traffic" :class="{ 'is-red': drift.alt }" :style="driftStyle(drift)" />
        <DataShards :seed="31" :count="12" :top="34" :bottom="84" />
        <Glints :points="glints" />
      </div>
    </div>
    <div class="layer layer-near">
      <div class="orbit">
        <div class="railing" />
        <div v-for="side in ['is-left', 'is-right']" :key="side" class="lamp" :class="side">
          <svg class="art art-near" viewBox="0 0 200 900" preserveAspectRatio="xMinYMax meet"><path class="stroke-pole" d="M60 900V170Q60 130 100 130H150" /><ellipse class="fill-near" cx="160" cy="138" rx="34" ry="12" /></svg>
          <i class="lamp-glow" />
        </div>
      </div>
    </div>
    <LensFlare :x="24" :y="46" />
  </div>
</template>

<style scoped>
.is-city {
  --sky: #24285e, #46438e 24%, #9a5c9e 44%, #e07a88 58%, #ffa874 70%, #ffd59a 80%;
  --sun-core: #fffaf0; --sun-glow: rgb(255 226 170 / 90%); --sun-halo: rgb(255 160 110 / 38%);
  --far: #8a6a9e; --far-rim: #ffbe94; --tower: #76598f; --beacon: #ff5a5a;
  --cloud: #ffb48c; --cloud-shade: #6d4f92;
  --tower-mid: #3f3a78; --rim: #ffae7c; --window: rgb(170 180 255 / 20%); --lit: #ffd59c; --neon-a: #8af0ff; --neon-b: #ff8adc;
  --front: #33306a; --front-lit: #4a3f7e; --accent: #8ff0ff; --ground: #2b2858; --near: #19163a;
  --ar: 130 240 255; --ar-grid: 24%; --ar-horizon: 86%;
  --light: 255 214 160; --red: 255 110 120;
  --flare: 255 214 160; --ray: 255 228 190; --rays: .5; --streak: .5; --ghosts: .55; --ghost-a: 255 190 140; --ghost-b: 140 230 255; --ghost-c: 210 160 255;
}
.is-dark .is-city {
  --sky: #04051a, #0a0c30 34%, #1c1648 58%, #3a1d55 74%, #5a2560 86%;
  --sun-core: transparent; --sun-glow: transparent; --sun-halo: rgb(255 80 170 / 10%);
  --far: #15173c; --far-rim: #3b3d8c; --tower: #ff8a4c;
  --cloud: #4a2f6e; --cloud-shade: #1a1a44;
  --tower-mid: #0f1130; --rim: #4651b8; --window: rgb(110 130 200 / 14%); --lit: #ffcf86; --neon-a: #39f2ff; --neon-b: #ff4fd8;
  --front: #121433; --front-lit: #1a1d48; --accent: #59f0ff; --ground: #0b0c24; --near: #05060f;
  --ar: 80 240 255; --ar-grid: 36%;
  --light: 255 210 150; --red: 255 80 96;
  --rays: 0; --streak: 0; --ghosts: 0;
}
.backdrop-scene.is-city { background: radial-gradient(circle at 24% 46%, var(--sun-core) 0 2.6%, var(--sun-glow) 3.6%, var(--sun-halo) 12%, transparent 34%), linear-gradient(var(--sky)); }
.stars { display: none; position: absolute; inset: 0; width: 100%; height: 100%; fill: rgb(240 240 255 / 70%); }
.is-dark .stars { display: block; }

.fill-far { fill: var(--far); }
.stroke-far-rim { fill: none; stroke: var(--far-rim); stroke-width: 2; }
.stroke-tower { fill: none; stroke: var(--tower); stroke-width: 3; }
.fill-tower { fill: var(--tower); }
.is-dark .stroke-tower, .is-dark .fill-tower { filter: drop-shadow(0 0 4px var(--tower)); }
/* Glow and blink the light itself, not its full-scene svg, so the svg does not become a full-screen layer. */
.beacon { fill: var(--beacon); color: var(--beacon); }
.beacon circle { animation: beacon 2.4s steps(1) infinite; }
.fill-cloud { fill: var(--cloud); }
.fill-cloud-shade { fill: var(--cloud-shade); }
.fill-tower-mid { fill: var(--tower-mid); }
.fill-window { fill: var(--window); }
.fill-lit { fill: var(--lit); }
.stroke-rim { fill: none; stroke: var(--rim); stroke-width: 3; }
.fill-ground { fill: var(--ground); }
.fill-front { fill: var(--front); }
.fill-front-lit { fill: var(--front-lit); }
.stroke-window { fill: none; stroke: var(--window); stroke-width: 3; }
.stroke-accent { fill: none; stroke: var(--accent); stroke-width: 3; filter: drop-shadow(0 0 5px var(--accent)); }
.stroke-front { fill: none; stroke: var(--front); stroke-width: 16; }
.stroke-track { fill: none; stroke: var(--front); stroke-width: 12; }
.stroke-lit { fill: none; stroke: var(--lit); stroke-width: 5; stroke-linecap: round; }
.stroke-pole { fill: none; stroke: var(--near); stroke-width: 14; }
.fill-near { fill: var(--near); }

.is-dark .windows { animation: twinkle 11s ease-in-out infinite; will-change: opacity; }
.is-dark .windows.is-2 { animation-duration: 15s; animation-delay: -5s; }
.is-dark .windows.is-3 { animation-duration: 19s; animation-delay: -9s; }
.neon { opacity: .55; }
.neon.is-1 { fill: var(--neon-a); }
.neon.is-2 { fill: var(--neon-b); }
.is-dark .neon { opacity: 1; }
/* Neon glows only at night; the svg filter on the path is drawn once into the flickering layer. */
.neon-glow { flood-opacity: 0; }
.is-dark .neon-glow { flood-opacity: 1; }
.is-dark .neon.is-1 { color: var(--neon-a); }
.is-dark .neon.is-2 { color: var(--neon-b); animation: neon-flicker 7s steps(1) infinite; }
.scan { position: absolute; top: 34%; bottom: 14%; left: 0; width: 9vw; opacity: 0; background: linear-gradient(90deg, transparent, rgb(var(--ar) / 10%) 80%, rgb(var(--ar) / 95%) 98%, transparent); animation: scan 12s ease-in-out infinite 1s; will-change: transform, opacity; }
.train { position: absolute; inset: 0; animation: train 32s linear infinite; will-change: transform; }
.cloud { position: absolute; height: auto; overflow: hidden; animation: backdrop-drift linear infinite alternate; }
.traffic { position: absolute; border-radius: 50%; translate: -50% -50%; opacity: .7; background: radial-gradient(circle, rgb(var(--light) / 55%) 0 30%, rgb(var(--light) / 18%) 52%, transparent 70%); animation: backdrop-rise ease-in-out infinite; will-change: transform, opacity; }
.traffic.is-red { --light: var(--red); }
.railing { position: absolute; left: 0; right: 0; bottom: 0; height: 16%; opacity: .9; filter: blur(5px); background: linear-gradient(var(--near), var(--near)) top / 100% 7px no-repeat, repeating-linear-gradient(90deg, var(--near) 0 7px, transparent 7px 72px); }
.lamp { position: absolute; bottom: 0; height: 88%; aspect-ratio: 2 / 9; }
.lamp.is-left { left: 3%; }
.lamp.is-right { right: 3%; scale: -1 1; }
.lamp-glow { position: absolute; left: 80%; top: 15.3%; width: 180px; aspect-ratio: 1; translate: -50% -50%; border-radius: 50%; background: radial-gradient(circle, rgb(var(--light) / 70%) 0 12%, rgb(var(--light) / 20%) 42%, transparent 70%); }

@keyframes twinkle { 0%, 100% { opacity: 1; } 45% { opacity: .55; } 60% { opacity: .9; } }
@keyframes neon-flicker { 0%, 100% { opacity: 1; } 62% { opacity: .35; } 64% { opacity: 1; } 66% { opacity: .5; } 68% { opacity: 1; } }
@keyframes beacon { 0%, 100% { opacity: 1; } 50% { opacity: .15; } }
@keyframes scan { 0% { opacity: 0; transform: translateX(-20vw); } 6% { opacity: 1; } 32% { opacity: 1; } 38% { opacity: 0; transform: translateX(110vw); } 100% { opacity: 0; transform: translateX(110vw); } }
@keyframes train { from { transform: translateX(0); } 62%, to { transform: translateX(calc(100% + 480px)); } }
@media (max-width: 600px) { .lamp { height: 70%; } .lamp-glow { width: 120px; } }
</style>
